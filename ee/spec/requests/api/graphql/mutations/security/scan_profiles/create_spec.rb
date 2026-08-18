# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SecurityScanProfileCreate', feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:root_group) { create(:group) }

  let(:namespace_id) { root_group.to_global_id.to_s }
  let(:scan_type) { 'SAST' }
  let(:name) { 'My scan profile' }
  let(:description) { 'A test scan profile' }
  let(:triggers) { [{ trigger_type: 'DEFAULT_BRANCH_PIPELINE' }] }
  let(:strip_defaults) { nil }

  let(:input) do
    {
      namespace_id: namespace_id,
      scan_type: scan_type,
      name: name,
      description: description,
      triggers: triggers,
      strip_defaults: strip_defaults
    }.compact
  end

  let(:mutation) do
    graphql_mutation(:security_scan_profile_create, input) do
      <<~FIELDS
        errors
        scanProfile {
          id
          name
          scanType
          triggers
        }
      FIELDS
    end
  end

  def mutation_response
    graphql_mutation_response(:security_scan_profile_create)
  end

  describe 'GraphQL mutation' do
    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when the user does not have permission' do
      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not create a scan profile' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { Security::ScanProfile.count }
      end
    end

    context 'when the user has permission' do
      before_all do
        root_group.add_maintainer(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :create_security_scan_profiles do
        let(:user) { current_user }
        let(:boundary_object) { root_group }
        let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
      end

      context 'when the configurable_security_scan_profiles feature flag is disabled' do
        before do
          stub_feature_flags(configurable_security_scan_profiles: false)
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the security_scan_profiles licensed feature is unavailable' do
        before do
          stub_licensed_features(security_scan_profiles: false)
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the namespace does not exist' do
        let(:namespace_id) { "gid://gitlab/Group/#{non_existing_record_id}" }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the namespace is not a top-level namespace' do
        let_it_be(:subgroup) { create(:group, parent: root_group) }

        let(:namespace_id) { subgroup.to_global_id.to_s }

        it 'returns a top-level argument error and does not create a profile', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ScanProfile.count }

          expect(graphql_errors.first['message']).to eq('namespace_id must reference a top-level namespace.')
        end
      end

      context 'with profile and a pipeline trigger' do
        it 'creates the scan profile', :aggregate_failures do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['scanProfile']).to include(
            'name' => name,
            'scanType' => 'SAST',
            'triggers' => ['DEFAULT_BRANCH_PIPELINE']
          )
        end
      end

      context 'without triggers' do
        let(:triggers) { [] }

        it 'returns a top-level validation error and does not create a profile', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ScanProfile.count }

          expect_graphql_errors_to_include('triggers is too short (minimum is 1)')
        end
      end

      context 'without a description' do
        let(:description) { nil }

        it 'returns a top-level schema error and does not create a profile', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ScanProfile.count }

          expect_graphql_errors_to_include(/provided invalid value for description \(Expected value to not be null\)/)
        end
      end

      context 'with a dependency scanning post-processing profile and a trigger' do
        let(:scan_type) { 'DEPENDENCY_SCANNING_POST_PROCESSING' }
        let(:strip_defaults) { false }
        let(:triggers) do
          [{
            trigger_type: 'SBOM_INGESTED',
            configuration: {
              dependency_scanning_post_processing: {
                auto_remediation: {
                  enabled: true,
                  cooldown: 3,
                  severity_level: 'HIGH',
                  upgrade_policy: 'MINOR'
                }
              }
            }
          }]
        end

        it 'creates the profile and attaches the configuration to the trigger', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfile.count }.by(1)
            .and change { Security::ScanProfileTrigger.count }.by(1)
            .and change { Security::ScanProfiles::Configuration.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['scanProfile']).to include('scanType' => 'DEPENDENCY_SCANNING_POST_PROCESSING')

          expect(Security::ScanProfileTrigger.find_by(trigger_type: :sbom_ingested)).to have_attributes(
            trigger_type: 'sbom_ingested',
            configuration: have_attributes(
              configuration: {
                'auto_remediation' =>
                  { 'enabled' => true, 'cooldown' => 3, 'severity_level' => 'high', 'upgrade_policy' => 'minor' }
              }
            )
          )
        end
      end

      context 'when strip_defaults is enabled (the default)' do
        let(:scan_type) { 'DEPENDENCY_SCANNING_POST_PROCESSING' }
        let(:triggers) do
          [{
            trigger_type: 'SBOM_INGESTED',
            configuration: {
              dependency_scanning_post_processing: {
                auto_remediation: { cooldown: 3, upgrade_policy: 'MINOR' }
              }
            }
          }]
        end

        it 'stores only the non-default values', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfiles::Configuration.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(Security::ScanProfileTrigger.find_by(trigger_type: :sbom_ingested).configuration.configuration)
            .to eq('auto_remediation' => { 'cooldown' => 3 })
        end
      end

      context 'with a secret detection profile and a trigger' do
        let(:scan_type) { 'SECRET_DETECTION' }
        let(:triggers) do
          [{
            trigger_type: 'MERGE_REQUEST_PIPELINE',
            configuration: {
              secret_detection: {
                image_suffix: :FIPS,
                secure_analyzers_prefix: 'registry.example.com/analyzers',
                historic_scan: true,
                log_options: '--all',
                excluded_paths: ['spec/', 'qa/'],
                ruleset_git_reference: 'gitlab.com/example-group/remote-ruleset'
              }
            }
          }]
        end

        it 'creates the profile and attaches the configuration to the trigger', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfile.count }.by(1)
            .and change { Security::ScanProfileTrigger.count }.by(1)
            .and change { Security::ScanProfiles::Configuration.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['scanProfile']).to include('scanType' => 'SECRET_DETECTION')

          trigger = Security::ScanProfileTrigger.find_by(trigger_type: :merge_request_pipeline)
          expect(trigger.configuration.configuration)
            .to eq(
              'image_suffix' => '-fips',
              'secure_analyzers_prefix' => 'registry.example.com/analyzers',
              'historic_scan' => true,
              'log_options' => '--all',
              'excluded_paths' => ['spec/', 'qa/'],
              'ruleset_git_reference' => 'gitlab.com/example-group/remote-ruleset'
            )
        end
      end

      context 'with a secret detection configuration on a git push event trigger' do
        let(:scan_type) { 'SECRET_DETECTION' }
        let(:triggers) do
          [{
            trigger_type: 'GIT_PUSH_EVENT',
            configuration: { secret_detection: { historic_scan: true } }
          }]
        end

        it 'returns mutation errors and persists nothing', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to not_change { Security::ScanProfile.count }
            .and not_change { Security::ScanProfiles::Configuration.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['scanProfile']).to be_nil
          expect(mutation_response['errors'])
            .to include('Configuration is not allowed for the git_push_event trigger')
        end
      end

      context 'when the configuration is invalid' do
        let(:scan_type) { 'DEPENDENCY_SCANNING_POST_PROCESSING' }
        let(:triggers) do
          [{
            trigger_type: 'SBOM_INGESTED',
            configuration: {
              dependency_scanning_post_processing: {
                auto_remediation: { cooldown: 999 }
              }
            }
          }]
        end

        it 'returns mutation errors and persists nothing', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to not_change { Security::ScanProfile.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['scanProfile']).to be_nil
          expect(mutation_response['errors'])
            .to contain_exactly('Configuration number at `/auto_remediation/cooldown` is greater than: 100')
        end
      end

      context 'when the configuration member does not match the scan type' do
        let(:scan_type) { 'SAST' }
        let(:triggers) do
          [{
            trigger_type: 'DEFAULT_BRANCH_PIPELINE',
            configuration: {
              dependency_scanning_post_processing: {
                auto_remediation: { enabled: true }
              }
            }
          }]
        end

        it 'returns a top-level argument error', :aggregate_failures do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(graphql_errors.first['message'])
            .to eq("Configuration 'dependency_scanning_post_processing' does not match scan type 'sast'")
          expect(Security::ScanProfile.count).to eq(0)
        end
      end
    end
  end
end
