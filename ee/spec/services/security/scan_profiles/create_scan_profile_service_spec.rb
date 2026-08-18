# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::CreateScanProfileService, feature_category: :security_testing_configuration do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user) }

  subject(:response) { described_class.new(namespace, params, current_user).execute }

  describe '#execute' do
    context 'with a scanner profile and a pipeline trigger (no configuration)' do
      let(:params) do
        {
          scan_type: 'sast',
          name: 'My SAST profile',
          description: 'Runs SAST on default branch',
          triggers: [{ trigger_type: 'default_branch_pipeline' }]
        }
      end

      it 'creates the profile and trigger', :aggregate_failures do
        expect { response }
          .to change { Security::ScanProfile.count }.by(1)
          .and change { Security::ScanProfileTrigger.count }.by(1)
          .and not_change { Security::ScanProfiles::Configuration.count }

        expect(response).to be_success
        expect(response.payload[:scan_profile]).to have_attributes(
          scan_type: 'sast',
          name: 'My SAST profile',
          namespace: namespace,
          scan_profile_triggers: contain_exactly(
            have_attributes(trigger_type: 'default_branch_pipeline', namespace: namespace, configuration: be_nil)
          )
        )
      end
    end

    context 'with a dependency scanning post-processing profile and a configured trigger' do
      let(:config_values) do
        { auto_remediation: { enabled: true, cooldown: 3, severity_level: 'high', upgrade_policy: 'minor' } }
      end

      let(:params) do
        {
          scan_type: 'dependency_scanning_post_processing',
          name: 'DS post-processing',
          description: nil,
          triggers: [{ trigger_type: 'sbom_ingested', configuration: config_values }]
        }
      end

      it 'creates the profile, trigger and attaches the configuration to the trigger', :aggregate_failures do
        expect { response }
          .to change { Security::ScanProfile.count }.by(1)
          .and change { Security::ScanProfileTrigger.count }.by(1)
          .and change { Security::ScanProfiles::Configuration.count }.by(1)

        expect(response).to be_success
        expect(response.payload[:scan_profile].scan_profile_triggers).to contain_exactly(
          have_attributes(
            trigger_type: 'sbom_ingested',
            namespace: namespace,
            configuration: have_attributes(
              namespace: namespace,
              configuration: {
                'auto_remediation' => { 'enabled' => true, 'cooldown' => 3, 'severity_level' => 'high',
                                        'upgrade_policy' => 'minor' }
              }
            )
          )
        )
      end
    end

    context 'when the configuration is invalid' do
      let(:params) do
        {
          scan_type: 'dependency_scanning_post_processing',
          name: 'DS post-processing',
          triggers: [{ trigger_type: 'sbom_ingested', configuration: { auto_remediation: { unknown_key: true } } }]
        }
      end

      it 'returns an error response and persists nothing', :aggregate_failures do
        expect { response }
          .to not_change { Security::ScanProfile.count }
          .and not_change { Security::ScanProfileTrigger.count }
          .and not_change { Security::ScanProfiles::Configuration.count }

        expect(response).to be_error
        expect(response.reason).to eq(:invalid)
        expect(response.message)
          .to eq('Configuration object property at `/auto_remediation/unknown_key` ' \
            'is a disallowed additional property')
      end
    end

    context 'when the same trigger type is provided more than once' do
      let(:params) do
        {
          scan_type: 'sast',
          name: 'Duplicate triggers',
          triggers: [
            { trigger_type: 'default_branch_pipeline', configuration: nil },
            { trigger_type: 'default_branch_pipeline', configuration: nil }
          ]
        }
      end

      it 'returns an error response and persists nothing', :aggregate_failures do
        expect { response }
          .to not_change { Security::ScanProfile.count }
          .and not_change { Security::ScanProfileTrigger.count }
          .and not_change { Security::ScanProfiles::Configuration.count }

        expect(response).to be_error
        expect(response.reason).to eq(:invalid)
      end
    end

    context 'with a blank configuration on a post-processing trigger' do
      let(:params) do
        {
          scan_type: 'dependency_scanning_post_processing',
          name: 'DS post-processing',
          triggers: [{ trigger_type: 'sbom_ingested', configuration: {} }]
        }
      end

      it 'creates the trigger without a configuration row', :aggregate_failures do
        expect { response }
          .to change { Security::ScanProfile.count }.by(1)
          .and change { Security::ScanProfileTrigger.count }.by(1)
          .and not_change { Security::ScanProfiles::Configuration.count }

        expect(response).to be_success
        expect(response.payload[:scan_profile].scan_profile_triggers).to contain_exactly(
          have_attributes(trigger_type: 'sbom_ingested', configuration: be_nil)
        )
      end
    end

    context 'without any triggers' do
      let(:params) do
        {
          scan_type: 'sast',
          name: 'No triggers',
          triggers: []
        }
      end

      it 'returns an error response and persists nothing', :aggregate_failures do
        expect { response }
          .to not_change { Security::ScanProfile.count }
          .and not_change { Security::ScanProfileTrigger.count }

        expect(response).to be_error
        expect(response.reason).to eq(:invalid)
        expect(response.message).to include('at least one trigger')
      end
    end

    context 'with multiple compatible triggers' do
      let(:params) do
        {
          scan_type: 'sast',
          name: 'Multiple triggers',
          triggers: [
            { trigger_type: 'default_branch_pipeline', configuration: nil },
            { trigger_type: 'merge_request_pipeline', configuration: nil }
          ]
        }
      end

      it 'creates and associates both triggers', :aggregate_failures do
        expect { response }
          .to change { Security::ScanProfile.count }.by(1)
          .and change { Security::ScanProfileTrigger.count }.by(2)

        expect(response).to be_success
        expect(response.payload[:scan_profile].scan_profile_triggers).to contain_exactly(
          have_attributes(trigger_type: 'default_branch_pipeline', namespace: namespace, configuration: be_nil),
          have_attributes(trigger_type: 'merge_request_pipeline', namespace: namespace, configuration: be_nil)
        )
      end
    end

    context 'with audit events' do
      let(:params) do
        {
          scan_type: 'sast',
          name: 'Audited profile',
          description: 'desc',
          triggers: [{ trigger_type: 'default_branch_pipeline' }]
        }
      end

      before do
        stub_licensed_features(extended_audit_events: true)
      end

      it 'records a create audit event on success', :aggregate_failures do
        expect { response }.to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last).to have_attributes(
          entity_id: namespace.id,
          target_type: 'Security::ScanProfile',
          details: hash_including(
            custom_message: "Created security scan profile 'Audited profile'",
            profile_id: response.payload[:scan_profile].id,
            scan_type: 'sast',
            trigger_types: ['default_branch_pipeline']
          )
        )
      end

      context 'when the operation fails' do
        let(:params) do
          {
            scan_type: 'sast',
            name: 'Invalid profile',
            triggers: [{ trigger_type: 'sbom_ingested' }]
          }
        end

        it 'does not record an audit event', :aggregate_failures do
          expect { response }.not_to change { AuditEventReader.count }
          expect(response).to be_error
        end
      end

      context 'when current_user is nil' do
        subject(:response) { described_class.new(namespace, params, nil).execute }

        it 'succeeds without recording an audit event', :aggregate_failures do
          expect { response }.not_to change { AuditEventReader.count }
          expect(response).to be_success
        end
      end
    end
  end
end
