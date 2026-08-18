# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::Entitlement::DenialTelemetry, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:entitlement) do
    SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :trial_expired)
  end

  describe '.track' do
    subject(:track) do
      described_class.track(entitlement: entitlement, surface: :graphql_mutation, namespace: group, user: user)
    end

    it 'fires the internal event with the structured denial properties' do
      expect { track }
        .to trigger_internal_events('secrets_manager_access_denied')
        .with(
          namespace: group,
          user: user,
          category: described_class.name,
          additional_properties: {
            label: 'trial_expired',
            property: 'graphql_mutation',
            state: 'blocked',
            mode: 'enforce'
          }
        )
        .and increment_usage_metrics('counts.count_total_secrets_manager_access_denied')
    end

    it 'logs a structured denial line without PII' do
      expect(Gitlab::AppJsonLogger).to receive(:info).with(
        message: 'Secrets Manager access denied by entitlement',
        Labkit::Fields::GL_NAMESPACE_ID => group.id,
        denial_reason: 'trial_expired',
        entitlement_state: 'blocked',
        surface: 'graphql_mutation',
        mode: 'enforce'
      )

      track
    end

    context 'when the entitlement permits writes' do
      let(:entitlement) { SecretsManagement::Entitlement.new(state: :paid) }

      it 'does not emit anything' do
        expect(Gitlab::AppJsonLogger).not_to receive(:info)
        expect { track }.not_to trigger_internal_events('secrets_manager_access_denied')
      end
    end

    context 'when entitlement is nil' do
      let(:entitlement) { nil }

      it 'does not emit anything' do
        expect { track }.not_to trigger_internal_events('secrets_manager_access_denied')
      end
    end

    context 'when the secrets_manager_denial_telemetry flag is disabled' do
      before do
        stub_feature_flags(secrets_manager_denial_telemetry: false)
      end

      it 'does not emit anything' do
        expect(Gitlab::AppJsonLogger).not_to receive(:info)
        expect { track }.not_to trigger_internal_events('secrets_manager_access_denied')
      end
    end

    context 'with an unknown surface' do
      it 'raises ArgumentError' do
        expect do
          described_class.track(entitlement: entitlement, surface: :nonsense, namespace: group, user: user)
        end.to raise_error(ArgumentError, /Unknown surface/)
      end
    end

    context 'without a user (CI runner payload surface)' do
      it 'fires the event with a nil user' do
        expect do
          described_class.track(entitlement: entitlement, surface: :ci_runner_payload, namespace: group)
        end.to trigger_internal_events('secrets_manager_access_denied').with(
          namespace: group,
          user: nil,
          category: described_class.name,
          additional_properties: {
            label: 'trial_expired',
            property: 'ci_runner_payload',
            state: 'blocked',
            mode: 'enforce'
          }
        )
      end
    end

    context 'without a namespace (instance-level entitlement on self-managed)' do
      it 'fires the event with a nil namespace and logs a nil namespace id' do
        expect(Gitlab::AppJsonLogger).to receive(:info).with(
          hash_including(Labkit::Fields::GL_NAMESPACE_ID => nil)
        )

        expect do
          described_class.track(entitlement: entitlement, surface: :service_gate, user: user)
        end.to trigger_internal_events('secrets_manager_access_denied').with(
          namespace: nil,
          user: user,
          category: described_class.name,
          additional_properties: {
            label: 'trial_expired',
            property: 'service_gate',
            state: 'blocked',
            mode: 'enforce'
          }
        )
      end
    end

    describe 'per-request dedupe', :request_store do
      before do
        described_class.track(entitlement: entitlement, surface: :graphql_mutation, namespace: group, user: user)
      end

      it 'suppresses a second emission for the same namespace and reason within a request' do
        expect do
          described_class.track(entitlement: entitlement, surface: :service_gate, namespace: group, user: user)
        end.not_to trigger_internal_events('secrets_manager_access_denied')
      end

      it 'emits again for a different reason' do
        other_entitlement = SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :credits_exhausted)

        expect do
          described_class.track(entitlement: other_entitlement, surface: :graphql_mutation, namespace: group,
            user: user)
        end.to trigger_internal_events('secrets_manager_access_denied').with(
          namespace: group,
          user: user,
          category: described_class.name,
          additional_properties: {
            label: 'credits_exhausted',
            property: 'graphql_mutation',
            state: 'blocked',
            mode: 'enforce'
          }
        )
      end

      it 'emits again for a different namespace' do
        other_group = create(:group)

        expect do
          described_class.track(entitlement: entitlement, surface: :graphql_mutation, namespace: other_group,
            user: user)
        end.to trigger_internal_events('secrets_manager_access_denied').with(
          namespace: other_group,
          user: user,
          category: described_class.name,
          additional_properties: {
            label: 'trial_expired',
            property: 'graphql_mutation',
            state: 'blocked',
            mode: 'enforce'
          }
        )
      end
    end
  end
end
