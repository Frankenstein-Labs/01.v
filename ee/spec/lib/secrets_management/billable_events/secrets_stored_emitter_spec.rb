# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::BillableEvents::SecretsStoredEmitter, feature_category: :secrets_management do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_namespace) }
  let_it_be(:project) { create(:project, group: root_namespace) }

  let(:entitlement) { SecretsManagement::Entitlement.new(state: :paid) }

  before do
    stub_feature_flags(secrets_manager_emit_secret_stored_events: true)
    allow(::Gitlab::BillingEvents::Client).to receive(:track_billing_event)
    allow(SecretsManagement::Entitlement).to receive(:for!).and_return(entitlement)

    SecretsManagement::NamespaceSecretCount.upsert_all(
      [
        { namespace_id: root_namespace.id, root_namespace_id: root_namespace.id, count: 5 },
        { namespace_id: subgroup.id, root_namespace_id: root_namespace.id, count: 3 },
        { namespace_id: project.project_namespace_id, root_namespace_id: root_namespace.id, count: 2 }
      ],
      unique_by: :namespace_id
    )
  end

  describe '.emit_for_root_namespace_id!' do
    it 'looks up the namespace and tracks a billing event' do
      described_class.emit_for_root_namespace_id!(root_namespace.id)

      expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
        hash_including(quantity: 10, namespace: root_namespace)
      )
    end

    it 'is a no-op when the namespace cannot be found' do
      described_class.emit_for_root_namespace_id!(non_existing_record_id)

      expect(::Gitlab::BillingEvents::Client).not_to have_received(:track_billing_event)
    end
  end

  describe '#emit!' do
    subject(:emit) { described_class.new(root_namespace).emit! }

    it 'tracks a secrets_stored billing event with the summed count as quantity' do
      emit

      expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
        event_type: 'secrets_stored',
        category: described_class.name,
        unit_of_measure: 'secret',
        quantity: 10,
        namespace: root_namespace,
        idempotency_key: "secrets_stored:#{root_namespace.id}:#{Date.current.iso8601}",
        metadata: { namespace_count: 3, entitlement_state: 'paid' }
      )
    end

    it 'resolves the entitlement once, for the root namespace' do
      emit

      expect(SecretsManagement::Entitlement).to have_received(:for!).with(root_namespace).once
    end

    context 'when the namespace entitlement is blocked' do
      let(:entitlement) do
        SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :grace)
      end

      it 'still emits, tagging the event with the blocked state and reason' do
        emit

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
          hash_including(
            metadata: { namespace_count: 3, entitlement_state: 'blocked', blocked_reason: 'grace' }
          )
        )
      end
    end

    context 'when entitlement resolution fails (CDot error or timeout)' do
      before do
        allow(SecretsManagement::Entitlement).to receive(:for!).and_raise(
          ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, 'timed out'
        )
      end

      it 'still emits the event, omitting the entitlement keys instead of stamping :ineligible' do
        emit

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
          hash_including(metadata: { namespace_count: 3 })
        )
      end

      it 'logs the resolution failure without raising' do
        expect(::Gitlab::ErrorTracking).to receive(:log_exception).with(
          an_instance_of(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error),
          hash_including(root_namespace_id: root_namespace.id)
        )

        expect { emit }.not_to raise_error
      end
    end

    it 'uses a date-scoped idempotency key so a same-day re-emission dedupes downstream' do
      travel_to(Date.new(2026, 7, 6)) do
        emit
      end

      expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
        hash_including(idempotency_key: "secrets_stored:#{root_namespace.id}:2026-07-06")
      )
    end

    context 'when the total count is zero' do
      before do
        SecretsManagement::NamespaceSecretCount
          .for_root_namespace(root_namespace.id)
          .update_all(count: 0)
      end

      it 'does not track a billing event' do
        emit

        expect(::Gitlab::BillingEvents::Client).not_to have_received(:track_billing_event)
      end
    end

    context 'when no rows exist for the root namespace' do
      before do
        SecretsManagement::NamespaceSecretCount.for_root_namespace(root_namespace.id).delete_all
      end

      it 'does not track a billing event' do
        emit

        expect(::Gitlab::BillingEvents::Client).not_to have_received(:track_billing_event)
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(secrets_manager_emit_secret_stored_events: false)
      end

      it 'does not track a billing event' do
        emit

        expect(::Gitlab::BillingEvents::Client).not_to have_received(:track_billing_event)
      end
    end

    context 'on SaaS' do
      before do
        allow(::CloudConnector).to receive(:gitlab_realm)
          .and_return(::CloudConnector::GITLAB_REALM_SAAS)
      end

      it 'tracks a billing event (emission is realm-independent)' do
        emit

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event)
      end
    end

    context 'when tracking raises' do
      before do
        allow(::Gitlab::BillingEvents::Client).to receive(:track_billing_event)
          .and_raise(StandardError, 'boom')
      end

      it 'swallows the exception and tracks it' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          hash_including(root_namespace_id: root_namespace.id)
        )

        expect { emit }.not_to raise_error
      end
    end
  end
end
