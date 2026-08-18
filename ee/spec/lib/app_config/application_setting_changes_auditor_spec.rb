# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppConfig::ApplicationSettingChangesAuditor, feature_category: :settings do
  include StubENV

  describe '.audit_changes' do
    let!(:user) { create(:user) }
    let!(:application_setting) { ApplicationSetting.create_from_defaults }
    let!(:application_setting_auditor_instance) { described_class.new(user, application_setting) }

    before do
      stub_licensed_features(extended_audit_events: true, admin_audit_log: true)
    end

    shared_examples 'application_setting_audit_events_from_to' do
      it 'calls auditor' do
        expect(Gitlab::Audit::Auditor).to receive(:audit).with(
          {
            name: "application_setting_updated",
            author: user,
            scope: be_an_instance_of(Gitlab::Audit::InstanceScope),
            target: application_setting,
            message: "Changed #{change_field} from #{change_from} to #{change_to}",
            additional_details: {
              change: change_field.to_s,
              from: change_from,
              target_details: change_field.humanize,
              to: change_to
            },
            target_details: change_field.humanize
          }
        ).and_call_original

        expect { application_setting_auditor_instance.execute }.to change { AuditEventReader.count }.by(1)

        event = AuditEventReader.last
        expect(event.details[:from]).to eq change_from
        expect(event.details[:to]).to eq change_to
        expect(event.details[:change]).to eq change_field
      end
    end

    context 'when any model change is made' do
      let(:change_from) { 0 }
      let(:change_to) { 10 }
      let(:change_field) { "default_project_visibility" }

      before do
        application_setting.update!(default_project_visibility: 10)
      end

      it_behaves_like 'application_setting_audit_events_from_to'
    end

    context 'when ignored column is updated' do
      it 'does not create an event for _html columns' do
        application_setting.update!(after_sign_up_text_html: "test_text")

        expect(AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)
        expect { application_setting_auditor_instance.execute }.not_to change { AuditEventReader.count }
      end
    end

    context 'when a Duo-related setting is changed' do
      context 'with a direct column' do
        before do
          application_setting.update!(duo_features_enabled: !application_setting.duo_features_enabled)
        end

        it 'labels the audit event as duo_related' do
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'application_setting_updated',
              additional_details: hash_including(change: 'duo_features_enabled', duo_related: true)
            )
          ).and_call_original

          application_setting_auditor_instance.execute
        end
      end

      context 'with a jsonb-backed setting' do
        before do
          application_setting.update!(duo_custom_agents_enabled: !application_setting.duo_custom_agents_enabled)
        end

        it 'labels both the sub-key and parent column events as duo_related' do
          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'application_setting_updated',
              additional_details: hash_including(change: 'duo_custom_agents_enabled', duo_related: true)
            )
          ).and_call_original

          expect(Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'application_setting_updated',
              additional_details: hash_including(change: 'duo_settings', duo_related: true)
            )
          ).and_call_original

          application_setting_auditor_instance.execute
        end
      end
    end

    context 'when a non-Duo setting is changed' do
      before do
        application_setting.update!(default_project_visibility: 10)
      end

      it 'does not label the audit event as duo_related', :aggregate_failures do
        expect(Gitlab::Audit::Auditor).to receive(:audit) do |audit_context|
          expect(audit_context[:name]).to eq('application_setting_updated')
          expect(audit_context[:additional_details]).not_to have_key(:duo_related)
        end

        application_setting_auditor_instance.execute
      end
    end
  end
end
