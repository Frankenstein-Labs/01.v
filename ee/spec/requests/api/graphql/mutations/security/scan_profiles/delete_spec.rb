# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SecurityScanProfileDelete', feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:root_group) { create(:group) }

  let_it_be_with_reload(:profile) do
    create(:security_scan_profile, namespace: root_group, scan_type: :secret_detection, name: 'Secrets')
  end

  let(:profile_id) { profile.to_global_id.to_s }
  let(:input) { { id: profile_id } }

  let(:mutation) do
    graphql_mutation(:security_scan_profile_delete, input) do
      <<~FIELDS
        errors
        deletedScanProfileId
      FIELDS
    end
  end

  def mutation_response
    graphql_mutation_response(:security_scan_profile_delete)
  end

  describe 'GraphQL mutation' do
    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when the user does not have permission' do
      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not delete the scan profile' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .not_to change { Security::ScanProfile.not_deleted.count }
      end
    end

    context 'when the user has permission' do
      before_all do
        root_group.add_maintainer(current_user)
      end

      it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_security_scan_profiles do
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

      context 'when the scan profile is already soft-deleted' do
        before do
          profile.destroy!
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when the profile is gitlab-recommended' do
        before do
          profile.update!(gitlab_recommended: true)
        end

        it 'returns a mutation error and neither deletes nor enqueues cleanup', :aggregate_failures do
          expect(Security::ScanProfiles::DeleteScanProfilesWorker).not_to receive(:perform_async)

          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to not_change { Security::ScanProfile.not_deleted.count }
            .and not_trigger_internal_events('delete_scan_profile')

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['deletedScanProfileId']).to be_nil
          expect(mutation_response['errors'])
            .to contain_exactly('Cannot delete a GitLab-recommended scan profile.')
          expect(profile.reload).not_to be_deleted
        end
      end

      context 'when the profile can be deleted' do
        it 'soft-deletes the profile and returns its global ID', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfile.not_deleted.count }.by(-1)
            .and not_change { Security::ScanProfile.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
          expect(mutation_response['deletedScanProfileId']).to eq(profile.to_global_id.to_s)
          expect(profile.reload).to be_deleted
        end

        it 'enqueues the asynchronous hard-delete worker' do
          expect(Security::ScanProfiles::DeleteScanProfilesWorker)
            .to receive(:perform_async).with([profile.id], root_group.id)

          post_graphql_mutation(mutation, current_user: current_user)
        end

        it 'tracks the delete_scan_profile internal event' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to trigger_internal_events('delete_scan_profile').with(
              category: 'Mutations::Security::ScanProfiles::Delete',
              user: current_user,
              namespace: root_group
            )
        end
      end

      context 'with audit events' do
        before_all do
          create(:security_scan_profile_trigger, scan_profile: profile, trigger_type: :default_branch_pipeline)
        end

        before do
          stub_licensed_features(security_scan_profiles: true, extended_audit_events: true)
        end

        it 'records a delete audit event on success', :aggregate_failures do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { AuditEventReader.count }.by(1)

          expect(AuditEventReader.last).to have_attributes(
            entity_id: root_group.id,
            target_type: 'Security::ScanProfile',
            details: hash_including(
              event_name: 'security_scan_profile_delete',
              custom_message: "Deleted security scan profile 'Secrets'",
              profile_id: profile.id,
              scan_type: 'secret_detection',
              trigger_types: ['default_branch_pipeline']
            )
          )
        end

        it 'does not record an audit event for a gitlab-recommended profile', :aggregate_failures do
          profile.update!(gitlab_recommended: true)

          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { AuditEventReader.count }
        end
      end
    end

    context 'with different roles' do
      using RSpec::Parameterized::TableSyntax

      where(:role, :deletes) do
        :owner            | true
        :maintainer       | true
        :security_manager | true
        :developer        | false
        :guest            | false
      end

      with_them do
        before do
          root_group.add_member(current_user, role)
        end

        it 'authorizes deletion by role' do
          if deletes
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change { Security::ScanProfile.not_deleted.count }.by(-1)
            expect(mutation_response['errors']).to be_empty
          else
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .not_to change { Security::ScanProfile.not_deleted.count }
            expect(graphql_errors).to be_present
          end
        end
      end
    end
  end
end
