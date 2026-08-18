# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SecurityScanProfileUpdate', feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:root_group) { create(:group) }

  let_it_be_with_reload(:profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :dependency_scanning_post_processing, name: 'PP')
  end

  let_it_be_with_reload(:trigger) do
    create(:security_scan_profile_trigger, scan_profile: profile, namespace: root_group, trigger_type: :sbom_ingested)
  end

  let(:profile_id) { profile.to_global_id.to_s }
  let(:name) { 'Updated name' }
  let(:strip_defaults) { nil }
  let(:triggers) { nil }

  let(:input) do
    { id: profile_id, name: name, triggers: triggers, strip_defaults: strip_defaults }.compact
  end

  let(:mutation) do
    graphql_mutation(:security_scan_profile_update, input) do
      <<~FIELDS
        errors
        scanProfile {
          id
          name
          scanType
          triggers
          configuration
        }
      FIELDS
    end
  end

  def mutation_response
    graphql_mutation_response(:security_scan_profile_update)
  end

  describe 'GraphQL mutation' do
    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when the user does not have permission' do
      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not update the scan profile' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { profile.reload.name }
      end
    end

    context 'when the user has permission' do
      before_all do
        root_group.add_maintainer(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :update_security_scan_profiles do
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

      context 'when the scan profile does not exist' do
        let(:profile_id) { "gid://gitlab/Security::ScanProfile/#{non_existing_record_id}" }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the scan profile is soft-deleted' do
        before do
          profile.destroy!
        end

        it_behaves_like 'a mutation that returns a top-level access error'

        it 'does not update the scan profile' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { profile.reload.name }
        end
      end

      context 'when the profile is gitlab-recommended' do
        before do
          profile.update!(gitlab_recommended: true)
        end

        it 'returns a mutation error and does not modify the profile', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { profile.reload.name }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['scanProfile']).to include('name' => profile.reload.name)
          expect(mutation_response['errors'])
            .to contain_exactly('Default GitLab-recommended profiles are not editable.')
        end
      end

      context 'when a trigger type is incompatible with the scan type' do
        let(:triggers) { [{ trigger_type: 'DEFAULT_BRANCH_PIPELINE' }] }

        it 'returns mutation errors and persists nothing', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ScanProfileTrigger.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['scanProfile']).to include('name' => profile.reload.name)
          expect(mutation_response['errors']).to include(match(/not allowed/))
        end
      end

      context 'when updating metadata' do
        it 'updates the scan profile', :aggregate_failures do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['scanProfile']).to include('name' => name)
          expect(profile.reload.name).to eq(name)
        end
      end

      context 'when description is null' do
        let(:input) { { id: profile_id, description: nil } }

        it 'returns a top-level argument error and does not update the profile', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { profile.reload.description }

          expect(graphql_errors).to be_present
          expect(graphql_errors.first['message']).to include('description')
        end
      end

      context 'when triggers is explicitly null' do
        let(:input) { { id: profile_id, name: 'Null triggers', triggers: nil } }

        it 'treats null as unset and leaves the triggers untouched', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { profile.scan_profile_triggers.reload.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(profile.reload.name).to eq('Null triggers')
        end
      end

      context 'with a configured trigger' do
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

        context 'with strip_defaults enabled (default)' do
          it 'stores only the non-default values', :aggregate_failures do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change { Security::ScanProfiles::Configuration.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_response['errors']).to be_empty
            expect(trigger.reload.configuration.configuration).to eq('auto_remediation' => { 'cooldown' => 3 })
          end
        end

        context 'with strip_defaults disabled' do
          let(:strip_defaults) { false }

          it 'stores the configuration verbatim', :aggregate_failures do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(trigger.reload.configuration.configuration)
              .to eq('auto_remediation' => { 'cooldown' => 3, 'upgrade_policy' => 'minor' })
          end
        end
      end

      context 'with a secret detection configured trigger' do
        let_it_be_with_reload(:secret_profile) do
          create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection, name: 'Secrets')
        end

        let(:profile_id) { secret_profile.to_global_id.to_s }
        let(:triggers) do
          [{
            trigger_type: 'MERGE_REQUEST_PIPELINE',
            configuration: {
              secret_detection: {
                historic_scan: true,
                excluded_paths: ['spec/', 'qa/']
              }
            }
          }]
        end

        it 'persists the secret detection configuration', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfiles::Configuration.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          # secret_detection has no defaults, so nothing is stripped.
          config = secret_profile.scan_profile_triggers.find_by(trigger_type: :merge_request_pipeline).configuration
          expect(config.configuration).to eq('historic_scan' => true, 'excluded_paths' => ['spec/', 'qa/'])
        end
      end

      context 'with a secret detection configuration on a git push event trigger' do
        let_it_be_with_reload(:push_profile) do
          create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection, name: 'Push secrets')
        end

        let(:profile_id) { push_profile.to_global_id.to_s }
        let(:triggers) do
          [{
            trigger_type: 'GIT_PUSH_EVENT',
            configuration: { secret_detection: { historic_scan: true } }
          }]
        end

        it 'returns mutation errors and persists nothing', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to not_change { Security::ScanProfiles::Configuration.count }
            .and not_change { push_profile.scan_profile_triggers.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors'])
            .to include('Configuration is not allowed for the git_push_event trigger')
        end
      end

      context 'with a full replace of triggers' do
        let_it_be_with_reload(:secret_profile) do
          create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection, name: 'Secrets')
        end

        let(:profile_id) { secret_profile.to_global_id.to_s }
        let(:triggers) { [{ trigger_type: 'GIT_PUSH_EVENT' }] }

        before do
          secret_profile.scan_profile_triggers.create!(namespace: root_group, trigger_type: :default_branch_pipeline)
          secret_profile.scan_profile_triggers.create!(namespace: root_group, trigger_type: :merge_request_pipeline)
        end

        it 'removes omitted triggers and creates the provided ones', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { secret_profile.scan_profile_triggers.count }.from(2).to(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['scanProfile']['triggers']).to contain_exactly('GIT_PUSH_EVENT')
        end
      end

      context 'when triggers is an empty array' do
        let(:triggers) { [] }

        it 'is rejected and does not remove existing triggers', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { profile.scan_profile_triggers.reload.count }

          expect(graphql_errors.first['message']).to match(/triggers.*too short/i)
        end
      end

      context 'when the configuration is invalid' do
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
            .not_to change { Security::ScanProfiles::Configuration.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['scanProfile']).to include('name' => profile.reload.name)
          expect(mutation_response['errors'])
            .to contain_exactly('Configuration number at `/auto_remediation/cooldown` is greater than: 100')
        end
      end

      context 'when the configuration type does not match the scan type' do
        let_it_be(:sast_profile) do
          create(:security_scan_profile, namespace: root_group, scan_type: :sast, name: 'SAST')
        end

        let(:profile_id) { sast_profile.to_global_id.to_s }
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

        it 'returns a top-level argument error' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect(graphql_errors.first['message'])
            .to eq("Configuration 'dependency_scanning_post_processing' does not match scan type 'sast'")
        end
      end
    end
  end
end
