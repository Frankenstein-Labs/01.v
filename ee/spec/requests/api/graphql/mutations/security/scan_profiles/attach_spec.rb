# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SecurityScanProfileAttach', feature_category: :security_testing_configuration do
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
      :security_scan_profile_attach,
      {
        security_scan_profile_id: security_scan_profile_id,
        project_ids: project_ids,
        group_ids: group_ids
      }.compact
    )
  end

  def mutation_result
    graphql_mutation_response(:security_scan_profile_attach)
  end

  describe 'GraphQL mutation' do
    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when user does not have permission' do
      context 'when user does not have permission to any project or group' do
        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'when user does not have permission some project or group' do
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
          .to trigger_internal_events('attach_scan_profile').with(
            category: 'Mutations::Security::ScanProfiles::Attach',
            user: current_user,
            namespace: root_group
          )
      end

      context 'when the request is made with an ai_workflows-scoped token' do
        let_it_be(:oauth_token) { create(:oauth_access_token, user: current_user, scopes: [:ai_workflows]) }

        it 'attaches the profile to projects', :aggregate_failures do
          expect { post_graphql_mutation(mutation, token: { oauth_access_token: oauth_token }) }
            .to change { Security::ScanProfileProject.count }.by(2)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end
      end

      context 'with persisted profile id' do
        it 'attaches the profile to projects' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(2)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
          expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(profile)).to exist
          expect(Security::ScanProfileProject.by_project_id(project2).for_scan_profile(profile)).to exist
        end
      end

      context 'with template based profile id (scan type)' do
        let(:security_scan_profile_id) { 'gid://gitlab/Security::ScanProfile/secret_detection' }
        let(:project_ids) { [project1.to_global_id.to_s] }

        context 'when gitlab_recommended profile does not exist' do
          it 'creates a new gitlab_recommended profile and attaches it' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change { Security::ScanProfile.by_type("secret_detection").by_gitlab_recommended.count }.by(1)
              .and change { Security::ScanProfileProject.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            scan_profile = Security::ScanProfile.by_type("secret_detection").by_gitlab_recommended.first
            expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(scan_profile)).to exist
          end
        end

        context 'when gitlab_recommended default profile already exists' do
          let_it_be(:existing_recommended_profile) do
            create(:security_scan_profile,
              namespace: root_group,
              scan_type: :secret_detection,
              name: Security::DefaultScanProfiles.find_by_scan_type(:secret_detection).name,
              gitlab_recommended: true)
          end

          it 'does not create a new profile' do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .not_to change { Security::ScanProfile.count }
          end

          it 'attaches the existing profile' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect(Security::ScanProfileProject.by_project_id(project1)
              .for_scan_profile(existing_recommended_profile)).to exist
          end
        end
      end

      context 'with dependency scanning post-processing profile' do
        context 'with template based profile id (scan type)' do
          let(:security_scan_profile_id) { 'gid://gitlab/Security::ScanProfile/dependency_scanning_post_processing' }
          let(:project_ids) { [project1.to_global_id.to_s] }

          it 'creates the post-processing profile and attaches it to the project', :aggregate_failures do
            expect { post_graphql_mutation(mutation, current_user: current_user) }
              .to change {
                Security::ScanProfile.by_type("dependency_scanning_post_processing").by_gitlab_recommended.count
              }.by(1)
              .and change { Security::ScanProfileProject.count }.by(1)

            expect(response).to have_gitlab_http_status(:success)
            expect(mutation_result['errors']).to be_empty

            scan_profile = Security::ScanProfile
              .by_type("dependency_scanning_post_processing").by_gitlab_recommended.order(:id).first
            expect(scan_profile.scan_profile_triggers.map(&:trigger_type)).to contain_exactly('sbom_ingested')
            expect(Security::ScanProfileProject.by_project_id(project1).for_scan_profile(scan_profile)).to exist
          end

          context 'when security_remediation_profiles feature flag is disabled' do
            before do
              stub_feature_flags(security_remediation_profiles: false)
            end

            it_behaves_like 'a mutation that returns a top-level access error'

            it 'does not persist a post-processing profile' do
              expect { post_graphql_mutation(mutation, current_user: current_user) }
                .to not_change { Security::ScanProfile.count }
                .and not_change { Security::ScanProfile.post_processing.count }
                .and not_change { Security::ScanProfileProject.count }
            end
          end
        end
      end

      context 'with valid scan type that does not have a default profile' do
        let(:security_scan_profile_id) { 'gid://gitlab/Security::ScanProfile/container_scanning' }
        let(:project_ids) { [project1.to_global_id.to_s] }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'with invalid scan type' do
        let(:security_scan_profile_id) { 'gid://gitlab/Security::ScanProfile/invalid_type' }
        let(:project_ids) { [project1.to_global_id.to_s] }

        it_behaves_like 'a mutation that returns a top-level access error'
      end

      context 'with groups in items' do
        let(:project_ids) { nil }
        let(:group_ids) { [group1.to_global_id.to_s] }

        it 'enqueues worker for groups' do
          expect(Security::ScanProfiles::AttachWorker)
            .to receive(:bulk_perform_async).with(
              contain_exactly([group1.id, profile.id, current_user.id, a_kind_of(String), true])
            )

          post_graphql_mutation(mutation, current_user: current_user)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end

        it 'does not create project associations' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .not_to change { Security::ScanProfileProject.count }
        end
      end

      context 'with mixed groups and projects' do
        let(:project_ids) { [project1.to_global_id.to_s] }
        let(:group_ids) { [group1.to_global_id.to_s] }

        it 'attaches to projects and enqueues workers for groups' do
          expect(Security::ScanProfiles::AttachWorker)
            .to receive(:bulk_perform_async).with(
              contain_exactly([group1.id, profile.id, current_user.id, a_kind_of(String), true])
            )

          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(1)

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
          let(:maximum_number_of_ids) { Mutations::Security::ScanProfiles::Attach::MAX_IDS }
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
          allow(Project).to receive(:projects_user_can).and_return([project1])
        end

        it_behaves_like 'a mutation that returns a top-level access error'

        it 'does not attach to any projects' do
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
        let(:security_scan_profile_id) { 'gid://gitlab/Security::ScanProfile/secret_detection' }

        it 'uses the root namespace for profile resolution and attaches successfully' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(1)

          profile = Security::ScanProfile.last
          expect(profile.namespace).to eq(root_group)
        end
      end

      context 'when profile is already attached to some projects' do
        before do
          create(:security_scan_profile_project, scan_profile: profile, project: project1)
        end

        it 'is idempotent and does not duplicate' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to be_empty
        end
      end

      context 'when project has reached profile limit' do
        let_it_be(:other_profile) do
          create(:security_scan_profile, namespace: root_group, scan_type: :sast, name: 'sast profile')
        end

        before do
          stub_const('Security::ScanProfileProject::MAX_PROFILES_PER_PROJECT', 1)
          create(:security_scan_profile_project, project: project1, scan_profile: other_profile)
        end

        it 'returns error for project at limit and attaches to projects not at limit' do
          expect { post_graphql_mutation(mutation, current_user: current_user) }
            .to change { Security::ScanProfileProject.count }.by(1)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_result['errors']).to include(
            match(/Project '#{project1.name}'.*#{project1.full_path}.*maximum limit/)
          )
          expect(Security::ScanProfileProject.by_project_id(project2).for_scan_profile(profile)).to exist
        end
      end
    end
  end
end
