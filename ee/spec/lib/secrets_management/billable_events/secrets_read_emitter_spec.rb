# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::BillableEvents::SecretsReadEmitter, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:audit_log) { SecretsManagement::AuditLog.new(payload_json) }
  let(:parsed_payload) { Gitlab::Json.safe_parse(payload_json) }
  let(:openbao_request_id) { parsed_payload.dig('request', 'id') }
  let(:openbao_entity_id) { parsed_payload.dig('auth', 'entity_id') }
  let(:expected_timestamp) { Time.zone.parse('2026-01-26T17:51:15.111915Z') }

  let(:entitlement) { SecretsManagement::Entitlement.new(state: :trial) }

  before do
    stub_feature_flags(secrets_manager_emit_secret_read_events: true)
    allow(::Gitlab::BillingEvents::Client).to receive(:track_billing_event)
    allow(SecretsManagement::Entitlement).to receive(:for!).and_return(entitlement)
  end

  describe '.emit!' do
    context 'with a successful KV data read on a project mount' do
      let(:payload_json) { kv_data_read_success_payload }

      it 'tracks a secrets_read billing event scoped to the project namespace' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
          event_type: 'secrets_read',
          category: described_class.name,
          unit_of_measure: 'request',
          quantity: 1,
          namespace: project.namespace,
          project: project,
          user: user,
          idempotency_key: "secrets_read:#{openbao_request_id}",
          timestamp: expected_timestamp,
          metadata: hash_including(
            mount_type: 'kv',
            audit_request_id: openbao_request_id,
            openbao_entity_id: openbao_entity_id,
            entitlement_state: 'trial'
          )
        )
      end

      it 'resolves the entitlement once, for the top-level group, with the tight CDot timeout' do
        described_class.emit!(audit_log)

        expect(SecretsManagement::Entitlement).to have_received(:for!)
          .with(
            SecretsManagement::Entitlement.root_namespace_for(project.namespace),
            http_timeout: described_class::ENTITLEMENT_TIMEOUT_SECONDS
          ).once
      end

      it 'omits blocked_reason when the entitlement is not blocked' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
          hash_including(metadata: hash_excluding(:blocked_reason))
        )
      end
    end

    context 'when the namespace entitlement is blocked' do
      let(:payload_json) { kv_data_read_success_payload }
      let(:entitlement) { SecretsManagement::Entitlement.new(state: :blocked, blocked_reason: :grace) }

      it 'still emits, tagging the event with the blocked state and reason' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
          hash_including(
            metadata: hash_including(entitlement_state: 'blocked', blocked_reason: 'grace')
          )
        )
      end
    end

    context 'when entitlement resolution fails (CDot error or timeout)' do
      let(:payload_json) { kv_data_read_success_payload }

      before do
        allow(SecretsManagement::Entitlement).to receive(:for!).and_raise(
          ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, 'timed out'
        )
      end

      it 'still emits the event, omitting the entitlement keys instead of stamping :ineligible' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
          hash_including(metadata: hash_excluding(:entitlement_state, :blocked_reason))
        )
      end

      it 'logs the resolution failure without raising' do
        expect(::Gitlab::ErrorTracking).to receive(:log_exception).with(
          an_instance_of(::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error),
          hash_including(:audit_log_event_type)
        )

        expect { described_class.emit!(audit_log) }.not_to raise_error
      end
    end

    context 'with a successful KV data read on a group mount' do
      let(:payload_json) { kv_data_read_group_secret_success_payload }

      it 'tracks a secrets_read billing event scoped to the group, without a project' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event).with(
          event_type: 'secrets_read',
          category: described_class.name,
          unit_of_measure: 'request',
          quantity: 1,
          namespace: group,
          project: nil,
          user: user,
          idempotency_key: "secrets_read:#{openbao_request_id}",
          timestamp: expected_timestamp,
          metadata: hash_including(
            mount_type: 'kv',
            audit_request_id: openbao_request_id,
            openbao_entity_id: openbao_entity_id,
            entitlement_state: 'trial'
          )
        )
      end

      it 'resolves the entitlement once, for the group' do
        described_class.emit!(audit_log)

        expect(SecretsManagement::Entitlement).to have_received(:for!)
          .with(group, http_timeout: described_class::ENTITLEMENT_TIMEOUT_SECONDS).once
      end
    end

    context 'with a permission-denied read' do
      let(:payload_json) { kv_read_permission_denied_payload }

      it 'does not track a billing event' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).not_to have_received(:track_billing_event)
      end
    end

    context 'when the feature flag is disabled' do
      let(:payload_json) { kv_data_read_success_payload }

      before do
        stub_feature_flags(secrets_manager_emit_secret_read_events: false)
      end

      it 'does not track a billing event' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).not_to have_received(:track_billing_event)
      end
    end

    context 'on SaaS' do
      let(:payload_json) { kv_data_read_success_payload }

      before do
        allow(::CloudConnector).to receive(:gitlab_realm).and_return(::CloudConnector::GITLAB_REALM_SAAS)
      end

      it 'tracks a billing event (emission is realm-independent)' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).to have_received(:track_billing_event)
      end
    end

    context 'with a request-type audit log (pre-operation entry)' do
      let(:payload_json) do
        json = Gitlab::Json.safe_parse(kv_data_read_success_payload)
        json['type'] = 'request'
        json.to_json
      end

      it 'does not track a billing event, mirroring AuditLog#ignore_log? defense in depth' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).not_to have_received(:track_billing_event)
      end
    end

    context 'with a non-read event (create)' do
      let(:payload_json) do
        json = Gitlab::Json.safe_parse(kv_data_read_success_payload)
        json['request']['operation'] = 'create'
        json.to_json
      end

      it 'does not track a billing event' do
        described_class.emit!(audit_log)

        expect(::Gitlab::BillingEvents::Client).not_to have_received(:track_billing_event)
      end
    end

    context 'when tracking raises' do
      let(:payload_json) { kv_data_read_success_payload }

      before do
        allow(::Gitlab::BillingEvents::Client).to receive(:track_billing_event).and_raise(StandardError, 'boom')
      end

      it 'swallows the exception and tracks it' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          hash_including(:audit_log_event_type)
        )

        expect { described_class.emit!(audit_log) }.not_to raise_error
      end
    end
  end

  def kv_data_read_success_payload
    json = File.read(Rails.root.join('ee/spec/fixtures/secrets_manager/audit_log_kv_data_read_success.json'))
    parsed = Gitlab::Json.safe_parse(json)
    parsed['auth']['metadata']['project_id'] = project.id.to_s
    parsed['auth']['metadata']['namespace_id'] = project.namespace.id.to_s
    parsed['auth']['metadata']['user_id'] = user.id.to_s
    parsed['request']['namespace']['path'] = "user_#{user.id}/project_#{project.id}/"
    parsed.to_json
  end

  def kv_read_permission_denied_payload
    File.read(Rails.root.join('ee/spec/fixtures/secrets_manager/audit_log_kv_read_permission_denied.json'))
  end

  def kv_data_read_group_secret_success_payload
    fixture_path = 'ee/spec/fixtures/secrets_manager/audit_log_kv_data_read_group_secret_success.json'
    json = File.read(Rails.root.join(fixture_path))
    parsed = Gitlab::Json.safe_parse(json)
    parsed['auth']['metadata']['namespace_id'] = group.id.to_s
    parsed['auth']['metadata']['group_id'] = group.id.to_s
    parsed['auth']['metadata']['user_id'] = user.id.to_s
    parsed['request']['namespace']['path'] = "group_#{group.id}/group_#{group.id}/"
    parsed['request']['mount_point'] = "group_#{group.id}/group_#{group.id}/secrets/kv/"
    parsed['response']['mount_point'] = "group_#{group.id}/group_#{group.id}/secrets/kv/"
    parsed.to_json
  end
end
