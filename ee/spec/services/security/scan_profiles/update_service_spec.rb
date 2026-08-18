# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::UpdateService, feature_category: :security_testing_configuration do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  subject(:response) { described_class.new(profile, params, current_user).execute }

  def audit_change_messages
    AuditEventReader.all.map { |event| event.details[:custom_message] }
  end

  describe '#execute' do
    context 'when only metadata is provided (triggers omitted)' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :secret_detection, name: 'Old name')
      end

      let(:params) { { name: 'New name', description: 'New description' } }

      before do
        profile.scan_profile_triggers.create!(namespace: namespace, trigger_type: :default_branch_pipeline)
      end

      it 'updates the attributes and leaves existing triggers untouched', :aggregate_failures do
        expect { response }.not_to change { profile.scan_profile_triggers.reload.map(&:trigger_type) }

        expect(response).to be_success
        expect(profile.reload).to have_attributes(name: 'New name', description: 'New description')
      end
    end

    context 'when a uniqueness conflict occurs' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :sast, name: 'Old name')
      end

      let(:params) { { name: 'New name' } }

      before do
        allow(profile).to receive(:update!).and_raise(ActiveRecord::RecordNotUnique)
      end

      it 'returns a conflict error', :aggregate_failures do
        expect(response).to be_error
        expect(response.reason).to eq(:conflict)
        expect(response.message)
          .to eq(s_('SecurityScanProfile|Profile was updated concurrently. Please try again.'))
      end
    end

    context 'when triggers is explicitly nil' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :secret_detection, name: 'Secrets')
      end

      let(:params) { { triggers: nil } }

      before do
        profile.scan_profile_triggers.create!(namespace: namespace, trigger_type: :default_branch_pipeline)
      end

      it 'treats nil as unchanged and leaves existing triggers untouched', :aggregate_failures do
        expect { response }.not_to change { profile.scan_profile_triggers.reload.count }

        expect(response).to be_success
      end
    end

    context 'with a full replace of triggers' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :secret_detection, name: 'Secrets')
      end

      let(:params) { { triggers: [{ trigger_type: 'git_push_event' }] } }

      before do
        profile.scan_profile_triggers.create!(namespace: namespace, trigger_type: :default_branch_pipeline)
        profile.scan_profile_triggers.create!(namespace: namespace, trigger_type: :merge_request_pipeline)
      end

      it 'destroys omitted triggers and creates the provided ones', :aggregate_failures do
        expect { response }.to change { Security::ScanProfileTrigger.count }.by(-1)

        expect(response).to be_success
        expect(profile.scan_profile_triggers.reload.map(&:trigger_type)).to contain_exactly('git_push_event')
      end
    end

    context 'with a configured trigger' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :dependency_scanning_post_processing,
          name: 'PP')
      end

      let!(:trigger) { profile.scan_profile_triggers.create!(namespace: namespace, trigger_type: :sbom_ingested) }
      let(:config_values) { { auto_remediation: { cooldown: 3, upgrade_policy: 'minor' } } }
      let(:strip_defaults) { true }

      let(:params) do
        {
          strip_defaults: strip_defaults,
          triggers: [{ trigger_type: 'sbom_ingested', configuration: config_values }]
        }
      end

      context 'with strip_defaults enabled (default)' do
        it 'stores only the values that differ from the defaults', :aggregate_failures do
          expect { response }.to change { Security::ScanProfiles::Configuration.count }.by(1)

          expect(response).to be_success
          expect(trigger.reload.configuration.configuration).to eq('auto_remediation' => { 'cooldown' => 3 })
        end

        context 'when every value equals a default' do
          let(:config_values) { { auto_remediation: { cooldown: 7 } } }

          it 'stores no configuration row', :aggregate_failures do
            expect { response }.not_to change { Security::ScanProfiles::Configuration.count }

            expect(response).to be_success
            expect(trigger.reload.configuration).to be_nil
          end
        end
      end

      context 'with strip_defaults disabled' do
        let(:strip_defaults) { false }

        it 'stores the configuration verbatim', :aggregate_failures do
          expect(response).to be_success
          expect(trigger.reload.configuration.configuration)
            .to eq('auto_remediation' => { 'cooldown' => 3, 'upgrade_policy' => 'minor' })
        end
      end

      context 'when the trigger already has a configuration' do
        before do
          trigger.update!(configuration: create(:security_scan_profile_configuration, scan_profile: profile,
            namespace: namespace, configuration: { auto_remediation: { cooldown: 5 } }))
        end

        it 'replaces the configuration and cleans up the previous row', :aggregate_failures do
          expect { response }.not_to change { Security::ScanProfiles::Configuration.count }

          expect(response).to be_success
          expect(trigger.reload.configuration.configuration).to eq('auto_remediation' => { 'cooldown' => 3 })
          expect(profile.configurations.count).to eq(1)
        end
      end

      context 'when the configuration is blank' do
        let(:config_values) { {} }

        before do
          trigger.update!(configuration: create(:security_scan_profile_configuration, scan_profile: profile,
            namespace: namespace, configuration: { auto_remediation: { cooldown: 5 } }))
        end

        it 'removes the configuration row and nulls the trigger reference', :aggregate_failures do
          expect { response }.to change { Security::ScanProfiles::Configuration.count }.by(-1)

          expect(response).to be_success
          expect(trigger.reload.configuration).to be_nil
        end
      end

      context 'when the configuration is invalid' do
        let(:config_values) { { auto_remediation: { unknown_key: true } } }

        it 'returns an error response and persists nothing', :aggregate_failures do
          expect { response }.not_to change { Security::ScanProfiles::Configuration.count }

          expect(response).to be_error
          expect(response.reason).to eq(:invalid)
          expect(response.message)
            .to eq('Configuration object property at `/auto_remediation/unknown_key` ' \
              'is a disallowed additional property')
        end
      end
    end

    context 'when a trigger type is incompatible with the scan type' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :sast, name: 'SAST')
      end

      let(:params) { { triggers: [{ trigger_type: 'sbom_ingested' }] } }

      it 'returns an error response and rolls back', :aggregate_failures do
        expect { response }.not_to change { Security::ScanProfileTrigger.count }

        expect(response).to be_error
        expect(response.reason).to eq(:invalid)
      end
    end

    context 'with audit events' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :secret_detection, name: 'Old name',
          description: 'Old description')
      end

      before do
        stub_licensed_features(extended_audit_events: true)
        profile.scan_profile_triggers.create!(namespace: namespace, trigger_type: :default_branch_pipeline)
      end

      context 'when scalar attributes change' do
        let(:params) { { name: 'New name', description: 'New description' } }

        it 'records one audit event per changed attribute', :aggregate_failures do
          expect { response }.to change { AuditEventReader.count }.by(2)

          expect(response).to be_success
          expect(audit_change_messages).to contain_exactly(
            'Changed name from Old name to New name',
            'Changed description from Old description to New description'
          )
        end
      end

      context 'when a trigger is replaced' do
        let(:params) { { triggers: [{ trigger_type: 'git_push_event' }] } }

        it 'records one event for the added and one for the removed trigger', :aggregate_failures do
          expect { response }.to change { AuditEventReader.count }.by(2)

          expect(response).to be_success
          expect(audit_change_messages).to contain_exactly(
            'Set trigger git_push_event to enabled',
            'Removed trigger default_branch_pipeline (was enabled)'
          )
        end
      end

      context 'when nothing effectively changes' do
        let(:params) { { name: 'Old name' } }

        it 'succeeds without recording an audit event', :aggregate_failures do
          expect { response }.not_to change { AuditEventReader.count }
          expect(response).to be_success
        end
      end

      context 'when the update fails' do
        let(:params) { { name: 'a' * 300 } }

        it 'returns an error without recording an audit event', :aggregate_failures do
          expect { response }.not_to change { AuditEventReader.count }
          expect(response).to be_error
        end
      end
    end

    context 'when audit events are not licensed' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :secret_detection, name: 'Old name')
      end

      let(:params) { { name: 'New name' } }

      before do
        stub_licensed_features(admin_audit_log: false, audit_events: false, extended_audit_events: false)
      end

      it 'succeeds without recording an audit event', :aggregate_failures do
        expect { response }.not_to change { AuditEventReader.count }
        expect(response).to be_success
      end
    end

    context 'with audit events for a trigger configuration change' do
      let_it_be_with_reload(:profile) do
        create(:security_scan_profile, namespace: namespace, scan_type: :dependency_scanning_post_processing,
          name: 'PP')
      end

      let(:params) do
        {
          strip_defaults: false,
          triggers: [{ trigger_type: 'sbom_ingested', configuration: { auto_remediation: { cooldown: 3 } } }]
        }
      end

      before do
        stub_licensed_features(extended_audit_events: true)
        trigger = profile.scan_profile_triggers.create!(namespace: namespace, trigger_type: :sbom_ingested)
        trigger.update!(configuration: create(:security_scan_profile_configuration, scan_profile: profile,
          namespace: namespace, configuration: { auto_remediation: { cooldown: 5 } }))
      end

      it 'audits the persisted per-key configuration change', :aggregate_failures do
        expect { response }.to change { AuditEventReader.count }.by(1)

        expect(audit_change_messages)
          .to contain_exactly('Changed trigger sbom_ingested auto_remediation.cooldown from 5 to 3')
      end
    end
  end
end
