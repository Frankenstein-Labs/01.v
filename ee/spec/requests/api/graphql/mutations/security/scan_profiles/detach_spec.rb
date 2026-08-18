# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SecurityScanProfileDetach', feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:another_root_group) { create(:group) }
  let_it_be(:project1) { create(:project, namespace: root_group) }
  let_it_be(:project2) { create(:project, namespace: root_group) }
  let_it_be(:subgroup_project) { create(:project, namespace: subgroup) }
  let_it_be(:group1) { create(:group, parent: root_group) }
  let_it_be(:profile) do
    create(:security_scan_profile,
      namespace: root_group,
      scan_type: :secret_detection,
      name: 'Test Profile')
  end

  let(:security_scan_profile_id) { profile.to_global_id.to_s }
  let(:project_ids) { [project1.to_global_id.to_s, project2.to_global_id.to_s] }
  let(:group_ids) { nil }

  let(:mutation) do
    graphql_mutation(
      :security_scan_profile_detach,
      {
        security_scan_profile_id: security_scan_profile_id,
        project_ids: project_ids,
        group_ids: group_ids
      }.compact
    )
  end

  def mutation_result
    graphql_mutation_response(:security_scan_profile_detach)
  end

  describe 'GraphQL mutation' do
    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when user does not have permission' do
      context 'when user does not have permission to any project or group' do
        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when user does not have permission to some project or group' do
        before_all do
          subgroup.add_maintainer(current_user)
        end

        let(:group_ids) { [root_group.to_global_id.to_s] }

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end

    context 'when user has permission' do
      before_all do
        root_group.add_maintainer(current_user)
      end

      context 'when security_scan_profiles feature is not available' do
        before do
          stub_licensed_features(security_scan_profiles: false)
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when security_scan_profiles_feature feature flag is disabled' do
        before do
          stub_feature_flags(security_scan_profiles_feature: false)
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      it 'triggers an internal event' do
        expect { post_graphql_mutation(mutation, current_user: current_user) }
          .to trigger_internal_events('detach_scan_profile').with(
            category: 'Mutations::Security::ScanProfiles::Detach',
            user: current_user,
            namespace: root_group
          )
      end

      context 'with persisted profile id' do
        before do
          create(:security_scan_profile_project, scan_profile: profile, project: project1)
          create(:security_scan_profile_project, scan_profile: profile, project: project2)
        end

        it 'detaches the profile from projects' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(-2)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
          expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(profile)).not_to exist
          expect(Security::ScanProfileProject.by_project_id(project2).for_scan_profile(profile)).not_to exist
        end
      end

      context 'with groups in items' do
        let(:project_ids) { nil }
        let(:group_ids) { [group1.to_global_id.to_s] }

        it 'enqueues worker for groups' do
          expect(Security::ScanProfiles::DetachWorker)
            .to receive(:bulk_perform_async).with(
              contain_exactly([group1.id, profile.id, current_user.id, a_kind_of(String), true])
            )

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end

        it 'does not delete project associations directly' do
          create(:security_scan_profile_project, scan_profile: profile, project: project1)

          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ScanProfileProject.count }
        end
      end

      context 'with mixed groups and projects' do
        let(:project_ids) { [project1.to_global_id.to_s] }
        let(:group_ids) { [group1.to_global_id.to_s] }

        before do
          create(:security_scan_profile_project, scan_profile: profile, project: project1)
        end

        it 'detaches from projects and enqueues workers for groups' do
          expect(Security::ScanProfiles::DetachWorker)
            .to receive(:bulk_perform_async).with(
              contain_exactly([group1.id, profile.id, current_user.id, a_kind_of(String), true])
            )

          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(-1)

          expect(response).to have_gitlab_http_status(:success)
        end
      end

      context 'when validating arguments' do
        context 'when no project_ids or group_ids provided' do
          let(:project_ids) { nil }
          let(:group_ids) { nil }

          it 'returns GraphQL error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors.first['message']).to eq('All items should belong to the same root namespace')
          end
        end

        context 'when too many IDs provided' do
          let(:maximum_number_of_ids) { Mutations::Security::ScanProfiles::Detach::MAX_IDS }
          let(:project_ids) do
            Array.new(maximum_number_of_ids + 1) { project1.to_global_id.to_s }
          end

          it 'returns validation error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors.first['message'])
              .to eq("Too many ids (maximum: #{maximum_number_of_ids})")
          end
        end

        context 'when items are from different root namespaces' do
          let_it_be(:other_project) { create(:project, namespace: another_root_group) }
          let(:project_ids) { [project1.to_global_id.to_s, other_project.to_global_id.to_s] }

          before_all do
            another_root_group.add_maintainer(current_user)
          end

          it 'returns validation error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(response).to have_gitlab_http_status(:success)
            expect(graphql_errors.first['message']).to eq('All items should belong to the same root namespace')
          end
        end
      end

      context 'when profile does not exist' do
        let(:security_scan_profile_id) { "gid://gitlab/Security::ScanProfile/#{non_existing_record_id}" }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when profile is from different root namespace' do
        let_it_be(:other_profile) do
          create(:security_scan_profile,
            namespace: another_root_group,
            scan_type: :secret_detection)
        end

        let(:security_scan_profile_id) { other_profile.to_global_id.to_s }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when user lacks permission for some projects' do
        let(:project_ids) { [project1.to_global_id.to_s, project2.to_global_id.to_s] }

        before do
          create(:security_scan_profile_project, scan_profile: profile, project: project1)
          allow(Project).to receive(:projects_user_can).and_return([project1])
        end

        it_behaves_like 'a mutation that returns a top-level access error'

        it 'does not detach from any projects' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ScanProfileProject.count }
        end
      end

      context 'when user lacks permission for some groups' do
        let(:group_ids) { [root_group.to_global_id.to_s, subgroup.to_global_id.to_s] }

        before do
          allow(Group).to receive(:groups_user_can).and_return([root_group])
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when using subgroup project' do
        let(:project_ids) { [subgroup_project.to_global_id.to_s] }

        before do
          create(:security_scan_profile_project, scan_profile: profile, project: subgroup_project)
        end

        it 'detaches successfully' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(-1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end
      end

      context 'when profile is not attached to some projects' do
        before do
          create(:security_scan_profile_project, scan_profile: profile, project: project1)
        end

        it 'is idempotent and detaches only attached projects' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(-1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end
      end

      context 'when profile is not attached to any of the projects' do
        it 'succeeds without errors' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ScanProfileProject.count }

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end
      end
    end
  end
end
