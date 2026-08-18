# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoSettings::ChangesAuditor, feature_category: :ai_abstraction_layer do
  describe '#execute' do
    let_it_be(:user) { create(:user) }

    # Use `let` (not `let_it_be`) so each example gets a fresh record.
    # Reload after creation to clear previous_changes left by the factory insert.
    let(:ai_setting) { create(:ai_settings).tap(&:reload) }
    let(:auditor) { described_class.new(user, ai_setting) }

    before do
      stub_licensed_features(extended_audit_events: true, admin_audit_log: true)
    end

    context 'when a setting is changed' do
      let(:ai_setting) { create(:ai_settings, duo_core_features_enabled: false).tap(&:reload) }

      before do
        ai_setting.update!(duo_core_features_enabled: true)
      end

      it 'creates an audit event' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          {
            name: "ai_setting_updated",
            author: user,
            scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
            target: ai_setting,
            message: "Changed duo_core_features_enabled from false to true",
            additional_details: {
              change: "duo_core_features_enabled",
              from: false,
              target_details: "Duo core features enabled",
              to: true
            },
            target_details: "Duo core features enabled"
          }
        ).and_call_original

        expect { auditor.execute }.to change { AuditEventReader.count }.by(1)

        event = AuditEventReader.last
        expect(event.details[:change]).to eq "duo_core_features_enabled"
        expect(event.details[:from]).to be false
        expect(event.details[:to]).to be true
      end
    end

    context 'when multiple settings are changed' do
      let(:ai_setting) { create(:ai_settings, duo_core_features_enabled: false).tap(&:reload) }

      before do
        ai_setting.update!(duo_core_features_enabled: true, amazon_q_role_arn: "arn:aws:iam::123456789012:role/q")
      end

      it 'creates one audit event per changed column' do
        expect { auditor.execute }.to change { AuditEventReader.count }.by(2)
      end
    end

    context 'when instance-level settings change on ApplicationSetting' do
      let(:application_settings) { create(:application_setting).tap(&:reload) }
      let(:auditor) { described_class.new(user, application_settings) }

      before do
        application_settings.update!(
          ai_gateway_url: "http://new-gateway:5052",
          ai_gateway_timeout_seconds: 120,
          duo_agent_platform_service_url: "grpc://dap.example.com:50052"
        )
      end

      it 'creates an audit event for each per-cell column' do
        expect { auditor.execute }.to change { AuditEventReader.count }.by(3)

        expect(AuditEventReader.last(3).map { |event| event.details[:change] }).to contain_exactly(
          "ai_gateway_url",
          "ai_gateway_timeout_seconds",
          "duo_agent_platform_service_url"
        )
      end
    end

    context 'when an unrelated ApplicationSetting column changes' do
      let(:application_settings) { create(:application_setting).tap(&:reload) }
      let(:auditor) { described_class.new(user, application_settings) }

      before do
        application_settings.update!(signup_enabled: false)
      end

      it 'does not create any audit events' do
        expect { auditor.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when no settings are changed' do
      it 'does not create any audit events' do
        expect { auditor.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when model is blank' do
      let(:auditor) { described_class.new(user, nil) }

      it 'does not create any audit events' do
        expect { auditor.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when updated_at changes but no other columns change' do
      before do
        allow(ai_setting).to receive(:previous_changes)
          .and_return(ActiveSupport::HashWithIndifferentAccess.new("updated_at" => [1.minute.ago, Time.current]))
      end

      it 'does not create any audit events' do
        expect { auditor.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when a column not in AUDIT_EVENT_COLUMNS changes' do
      before do
        allow(ai_setting).to receive(:saved_change_to_attribute?).and_return(false)
        allow(ai_setting).to receive(:saved_change_to_attribute?)
          .with(:amazon_q_oauth_application_id).and_return(true)
      end

      it 'does not create any audit events' do
        expect { auditor.execute }.not_to change { AuditEventReader.count }
      end
    end
  end
end
