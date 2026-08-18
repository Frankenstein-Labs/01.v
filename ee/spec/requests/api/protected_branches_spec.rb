# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProtectedBranches, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

  let(:protected_name) { 'feature' }
  let(:branch_name) { protected_name }
  let!(:protected_branch) do
    create(:protected_branch, project: project, name: protected_name)
  end

  describe "GET /projects/:id/protected_branches/:branch" do
    let(:route) { "/projects/#{project.id}/protected_branches/#{branch_name}" }

    shared_examples_for 'protected branch' do
      it 'returns the protected branch' do
        get api(route, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['unprotect_access_levels']).to eq([])
        expect(json_response).to include('inherited')
      end

      context 'with per user/group access levels' do
        let(:push_user) { create(:user) }
        let(:merge_group) { create(:group) }
        let(:unprotect_group) { create(:group) }

        before do
          project.add_developer(push_user)
          project.project_group_links.create!(group: merge_group)
          project.project_group_links.create!(group: unprotect_group)
          protected_branch.push_access_levels.create!(user: push_user)
          protected_branch.merge_access_levels.create!(group: merge_group)
          protected_branch.unprotect_access_levels.create!(group: unprotect_group)
        end

        it 'returns access level details' do
          get api(route, user)

          push_user_ids = json_response['push_access_levels'].map { |level| level['user_id'] }
          merge_group_ids = json_response['merge_access_levels'].map { |level| level['group_id'] }
          unprotect_group_ids = json_response['unprotect_access_levels'].map { |level| level['group_id'] }

          expect(response).to have_gitlab_http_status(:ok)
          expect(push_user_ids).to include(push_user.id)
          expect(merge_group_ids).to include(merge_group.id)
          expect(unprotect_group_ids).to include(unprotect_group.id)
        end
      end

      context 'with member_role access levels' do
        let_it_be(:group) { project.namespace.root_ancestor }
        let_it_be(:member_role) { create(:member_role, namespace: group) }

        before do
          stub_licensed_features(custom_roles: true)
          protected_branch.merge_access_levels.create!(member_role: member_role)
        end

        it 'returns member_role_id in access level details', :aggregate_failures do
          get api(route, user)

          merge_member_role_ids = json_response['merge_access_levels'].map { |level| level['member_role_id'] }

          expect(response).to have_gitlab_http_status(:ok)
          expect(merge_member_role_ids).to include(member_role.id)
        end
      end
    end

    context 'when authenticated as a maintainer' do
      before do
        project.add_maintainer(user)
      end

      it_behaves_like 'protected branch'

      context 'when protected branch contains a wildcard' do
        let(:protected_name) { 'feature*' }

        it_behaves_like 'protected branch'
      end

      context 'when protected branch contains a period' do
        let(:protected_name) { 'my.feature' }

        it_behaves_like 'protected branch'
      end

      context 'with member_role access levels' do
        let_it_be(:group) { create(:group) }
        let_it_be(:member_role) { create(:member_role, :developer, namespace: group) }

        let(:group_project) { create(:project, :repository, group: group) }
        let(:route) { "/projects/#{group_project.id}/protected_branches/#{branch_name}" }
        let!(:protected_branch) do
          create(:protected_branch, project: group_project, name: protected_name)
        end

        before do
          group_project.add_maintainer(user)
          stub_licensed_features(custom_roles: true)
          protected_branch.push_access_levels.create!(
            member_role: member_role, access_level: member_role.base_access_level
          )
        end

        context 'when custom_roles_for_protected_branches is enabled' do
          it 'returns member_role_id and member_role_name in push access levels', :aggregate_failures do
            get api(route, user)

            expect(response).to have_gitlab_http_status(:ok)
            push_level = json_response['push_access_levels'].find { |l| l['member_role_id'].present? }
            expect(push_level).to be_present
            expect(push_level['member_role_id']).to eq(member_role.id)
            expect(push_level['member_role_name']).to eq(member_role.name)
          end

          it 'returns null member_role fields for access levels without a member role', :aggregate_failures do
            get api(route, user)

            expect(response).to have_gitlab_http_status(:ok)
            default_level = json_response['push_access_levels'].find { |l| l['member_role_id'].nil? }
            expect(default_level).to be_present
            expect(default_level['member_role_id']).to be_nil
            expect(default_level['member_role_name']).to be_nil
          end

          it 'returns member_role_id and member_role_name in merge access levels', :aggregate_failures do
            protected_branch.merge_access_levels.create!(
              member_role: member_role, access_level: member_role.base_access_level
            )

            get api(route, user)

            expect(response).to have_gitlab_http_status(:ok)
            merge_level = json_response['merge_access_levels'].find { |l| l['member_role_id'].present? }
            expect(merge_level).to be_present
            expect(merge_level['member_role_id']).to eq(member_role.id)
            expect(merge_level['member_role_name']).to eq(member_role.name)
          end
        end

        context 'when custom_roles_for_protected_branches is disabled' do
          before do
            stub_feature_flags(custom_roles_for_protected_branches: false)
          end

          it 'does not expose member_role_id or member_role_name', :aggregate_failures do
            get api(route, user)

            expect(response).to have_gitlab_http_status(:ok)
            json_response['push_access_levels'].each do |level|
              expect(level).not_to have_key('member_role_id')
              expect(level).not_to have_key('member_role_name')
            end
          end
        end
      end

      context 'when unprotect_access_level is set to DEVELOPER' do
        let(:protected_branch) do
          create(:protected_branch, :developers_can_unprotect, project: project, name: protected_name)
        end

        it 'unprotect_access_level is returned as DEVELOPER' do
          get api(route, user)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['unprotect_access_levels'].first['access_level_description'])
            .to eq('Developers + Maintainers')
        end
      end
    end

    context 'when authenticated as a developer' do
      before do
        project.add_developer(user)
      end

      it_behaves_like 'protected branch'
    end

    context 'when authenticated as a guest' do
      before do
        project.add_guest(user)
      end

      it_behaves_like '403 response' do
        let(:request) { get api(route, user) }
      end
    end
  end

  describe "PATCH /projects/:id/protected_branches/:branch" do
    let(:route) { "/projects/#{project.id}/protected_branches/#{branch_name}" }

    context 'when authenticated as a maintainer' do
      before do
        project.add_maintainer(user)
        protected_branch.unprotect_access_levels << create(:protected_branch_unprotect_access_level)
      end

      let(:push_access_level) { protected_branch.push_access_levels.first }
      let(:merge_access_level) { protected_branch.merge_access_levels.first }
      let(:unprotect_access_level) { protected_branch.unprotect_access_levels.first }

      where(:key, :access_level_record, :access_level_param, :new_access_level) do
        [
          ['push_access_levels', ref(:push_access_level), 'allowed_to_push', 30],
          ['merge_access_levels', ref(:merge_access_level), 'allowed_to_merge', 30],
          ['unprotect_access_levels', ref(:unprotect_access_level), 'allowed_to_unprotect', 40]
        ]
      end

      with_them do
        it 'creates an access level' do
          params = {}
          params[access_level_param] =
            [
              {
                access_level: new_access_level,
                user_id: user.id
              }
            ]
          patch api(route, user), params: params
          expect(response).to have_gitlab_http_status(:ok)
          access_levels = json_response[key].map do |access_level|
            access_level['access_level']
          end

          expect(access_levels).to match_array [30, 40]
          expect(json_response[key].last['user_id']).to eq(user.id)
        end

        it 'updates an existing access level' do
          params = {}
          params[access_level_param] =
            [
              {
                id: access_level_record.id,
                access_level: new_access_level,
                user_id: user.id
              }
            ]
          patch api(route, user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response[key].length).to eq(1)
          expect(json_response[key].last['access_level']).to eq(new_access_level)
          expect(json_response[key].last['user_id']).to eq(user.id)
        end

        it 'deletes an existing access level' do
          params = {}
          params[access_level_param] =
            [
              {
                id: access_level_record.id,
                _destroy: true
              }
            ]
          patch api(route, user), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response[key].length).to eq(0)
        end

        context 'when no access levels are sent' do
          it 'does not update with default access levels' do
            patch api(route, user)
            expect(json_response[key].length).to eq(1)
            expect(json_response[key].last['access_level']).to eq(access_level_record.access_level)
          end
        end
      end

      context 'with deploy key' do
        let(:deploy_key) { create(:deploy_key, write_access_to: project, user: user) }

        it 'adds a deploy key for allowed to push option' do
          patch api(route, user), params: { allowed_to_push: [{ deploy_key_id: deploy_key.id }] }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['push_access_levels']).to match_array(
            [
              a_hash_including('id' => push_access_level.id, 'access_level' => push_access_level.access_level),
              a_hash_including('access_level_description' => deploy_key.title, 'deploy_key_id' => deploy_key.id)
            ]
          )
        end

        it 'does not support a deploy key for other options' do
          patch api(route, user), params: { allowed_to_merge: [{ deploy_key_id: deploy_key.id }] }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end

        it 'updates an existing access level' do
          patch api(route, user), params: {
            allowed_to_push: [{ id: push_access_level.id, deploy_key_id: deploy_key.id }]
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['push_access_levels']).to match_array(
            a_hash_including(
              'id' => push_access_level.id,
              'access_level_description' => deploy_key.title,
              'deploy_key_id' => deploy_key.id
            )
          )
        end

        context 'when deploy key is already set' do
          let!(:deploy_key_access_level) do
            create(:protected_branch_push_access_level, protected_branch: protected_branch, deploy_key: deploy_key)
          end

          it 'deletes a deploy key' do
            patch api(route, user), params: { allowed_to_push: [{ id: deploy_key_access_level.id, _destroy: true }] }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['push_access_levels']).to match_array(
              a_hash_including('id' => push_access_level.id, 'access_level' => push_access_level.access_level)
            )
          end
        end
      end

      context 'with member_role_id' do
        let_it_be(:group) { project.namespace.root_ancestor }
        let_it_be(:member_role) { create(:member_role, namespace: group) }

        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'adds a member role access level', :aggregate_failures do
          patch api(route, user), params: {
            allowed_to_merge: [{ member_role_id: member_role.id }]
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_access_levels'].last['member_role_id']).to eq(member_role.id)
        end

        it 'adds a member role access level to push', :aggregate_failures do
          patch api(route, user), params: {
            allowed_to_push: [{ member_role_id: member_role.id }]
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['push_access_levels'].last['member_role_id']).to eq(member_role.id)
        end

        it 'adds a member role access level to unprotect', :aggregate_failures do
          patch api(route, user), params: {
            allowed_to_unprotect: [{ member_role_id: member_role.id }]
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['unprotect_access_levels'].last['member_role_id']).to eq(member_role.id)
        end

        context 'when member_role belongs to a different namespace' do
          let_it_be(:other_group) { create(:group) }
          let_it_be(:other_member_role) { create(:member_role, namespace: other_group) }

          it 'returns an error' do
            patch api(route, user), params: {
              allowed_to_merge: [{ member_role_id: other_member_role.id }]
            }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(custom_roles_for_protected_branches: false)
          end

          it 'returns an error' do
            patch api(route, user), params: {
              allowed_to_merge: [{ member_role_id: member_role.id }]
            }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
          end
        end
      end

      context "when the feature is enabled" do
        before do
          stub_licensed_features(code_owner_approval_required: true)
        end

        it "updates the protected branch" do
          expect do
            patch api(route, user), params: { code_owner_approval_required: true }
          end.to change { protected_branch.reload.code_owner_approval_required }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['code_owner_approval_required']).to be(true)
        end

        context 'when code_owner_approval_required is not provided' do
          before do
            protected_branch.update!(code_owner_approval_required: true)
          end

          it 'does not reset previous "code_owner_approval_required" state' do
            expect do
              patch api(route, user), params: {}
            end.not_to change { protected_branch.reload.code_owner_approval_required }

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['code_owner_approval_required']).to be(true)
          end
        end
      end

      context "when the feature is disabled" do
        before do
          stub_licensed_features(code_owner_approval_required: false)
        end

        it "does not change the protected branch" do
          expect do
            patch api(route, user), params: { code_owner_approval_required: true }
          end.not_to change { protected_branch.reload.code_owner_approval_required }

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with blocking approval policy' do
        let(:params) { { allow_force_push: true } }
        let!(:read) { create(:scan_result_policy_read, :blocking_protected_branches, project: project) }

        subject(:update_branch) { patch api(route, user), params: params }

        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        it 'updates attributes other than name' do
          expect { update_branch }.to change { protected_branch.reload.allow_force_push }.to(true)
        end

        it 'responds with 2xx' do
          update_branch

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context "with approval policy that sets 'prevent_pushing_and_force_pushing'" do
        include_context 'with approval security policy preventing force pushing' do
          let(:branch_name) { protected_branch.name }
        end

        subject(:update_branch) { patch api(route, user), params: params }

        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        shared_examples 'responds with 403' do
          specify do
            update_branch

            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end

        context "when updating 'allow_force_push'" do
          let(:params) { { allow_force_push: !protected_branch.allow_force_push } }

          include_examples 'responds with 403'

          it 'prohibits updates' do
            expect { update_branch }.not_to change { protected_branch.allow_force_push }
          end
        end

        context 'when updating push access levels' do
          # The factory grants push access to MAINTAINER (40) by default, so we
          # request a genuinely different level (DEVELOPER) to exercise the policy
          # block; resubmitting the existing level would be a no-op and allowed.
          let(:params) { { allowed_to_push: [{ access_level: Gitlab::Access::DEVELOPER }] } }

          include_examples 'responds with 403'

          it 'prohibits updates' do
            expect { update_branch }.not_to change { protected_branch.push_access_levels }
          end
        end
      end
    end

    context 'when authenticated as a developer' do
      before do
        project.add_developer(user)
      end

      it "returns a 403 response" do
        patch api(route, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated as a guest' do
      before do
        project.add_guest(user)
      end

      it "returns a 403 response" do
        patch api(route, user)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'POST /projects/:id/protected_branches' do
    let(:branch_name) { 'new_branch' }
    let(:post_endpoint) { api("/projects/#{project.id}/protected_branches", user) }

    def expect_protection_to_be_successful
      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['name']).to eq(branch_name)
    end

    context 'when authenticated as a maintainer' do
      before do
        project.add_maintainer(user)
      end

      it 'protects a single branch' do
        post post_endpoint, params: { name: branch_name }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['unprotect_access_levels'][0]['access_level']).to eq(Gitlab::Access::MAINTAINER)
      end

      it 'protects a single branch and only admins can unprotect' do
        post post_endpoint, params: { name: branch_name, unprotect_access_level: Gitlab::Access::ADMIN }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::MAINTAINER)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::MAINTAINER)
        expect(json_response['unprotect_access_levels'][0]['access_level']).to eq(Gitlab::Access::ADMIN)
      end

      it 'no access is not a valid access level' do
        post post_endpoint, params: { name: branch_name, unprotect_access_level: Gitlab::Access::NO_ACCESS }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(response.body).to include('unprotect_access_level does not have a valid value')
      end

      context 'with deploy key' do
        let(:deploy_key) { create(:deploy_key, write_access_to: project, user: user) }

        it 'adds a deploy key for allowed to push option' do
          post post_endpoint, params: { name: branch_name, allowed_to_push: [{ deploy_key_id: deploy_key.id }] }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['push_access_levels']).to match_array(
            a_hash_including('access_level_description' => deploy_key.title, 'deploy_key_id' => deploy_key.id)
          )
        end

        it 'ignores a deploy key for other options' do
          post post_endpoint, params: { name: branch_name, allowed_to_merge: [{ deploy_key_id: deploy_key.id }] }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['merge_access_levels']).to match_array(
            a_hash_including('access_level' => Gitlab::Access::MAINTAINER)
          )
        end
      end

      context "code_owner_approval_required" do
        context "when feature is enabled" do
          before do
            stub_licensed_features(code_owner_approval_required: true)
          end

          it "sets :code_owner_approval_required to true when the param is true" do
            expect(project.protected_branches.find_by_name(branch_name)).to be_nil

            post post_endpoint, params: { name: branch_name, code_owner_approval_required: true }

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response["code_owner_approval_required"]).to be(true)

            new_branch = project.protected_branches.find_by_name(branch_name)
            expect(new_branch.code_owner_approval_required).to be_truthy
            expect(new_branch[:code_owner_approval_required]).to be_truthy
          end

          it "sets :code_owner_approval_required to false when the param is false" do
            expect(project.protected_branches.find_by_name(branch_name)).to be_nil

            post post_endpoint, params: { name: branch_name, code_owner_approval_required: false }

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response["code_owner_approval_required"]).to be(false)

            new_branch = project.protected_branches.find_by_name(branch_name)
            expect(new_branch.code_owner_approval_required).to be_falsy
            expect(new_branch[:code_owner_approval_required]).to be_falsy
          end

          context 'when code_owner_approval_required is not provided' do
            it "sets :code_owner_approval_required to false by default" do
              expect(project.protected_branches.find_by_name(branch_name)).to be_nil

              post post_endpoint, params: { name: branch_name }

              expect(response).to have_gitlab_http_status(:created)
              expect(json_response["code_owner_approval_required"]).to be(false)

              new_branch = project.protected_branches.find_by_name(branch_name)
              expect(new_branch.code_owner_approval_required).to be_falsy
              expect(new_branch[:code_owner_approval_required]).to be_falsy
            end
          end
        end

        context "when feature is not enabled" do
          it "sets :code_owner_approval_required to false when the param is false" do
            expect(project.protected_branches.find_by_name(branch_name)).to be_nil

            post post_endpoint, params: { name: branch_name, code_owner_approval_required: true }

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response["code_owner_approval_required"]).to be(false)

            new_branch = project.protected_branches.find_by_name(branch_name)
            expect(new_branch.code_owner_approval_required).to be_falsy
            expect(new_branch[:code_owner_approval_required]).to be_falsy
          end
        end
      end

      context 'with granular access' do
        let(:invited_group) do
          create(:project_group_link, project: project).group
        end

        let(:project_member) do
          create(:project_member, project: project).user
        end

        it 'can protect a branch while allowing an individual user to push' do
          push_user = project_member

          post post_endpoint, params: { name: branch_name, allowed_to_push: [{ user_id: push_user.id }] }

          expect_protection_to_be_successful
          expect(json_response['push_access_levels'][0]['user_id']).to eq(push_user.id)
        end

        it 'can protect a branch while allowing an individual user to merge' do
          merge_user = project_member

          post post_endpoint, params: { name: branch_name, allowed_to_merge: [{ user_id: merge_user.id }] }

          expect_protection_to_be_successful
          expect(json_response['merge_access_levels'][0]['user_id']).to eq(merge_user.id)
        end

        it 'can protect a branch while allowing an individual user to unprotect' do
          unprotect_user = project_member

          post post_endpoint, params: { name: branch_name, allowed_to_unprotect: [{ user_id: unprotect_user.id }] }

          expect_protection_to_be_successful
          expect(json_response['unprotect_access_levels'][0]['user_id']).to eq(unprotect_user.id)
        end

        it 'can protect a branch while allowing a group to push' do
          push_group = invited_group

          post post_endpoint, params: { name: branch_name, allowed_to_push: [{ group_id: push_group.id }] }

          expect_protection_to_be_successful
          expect(json_response['push_access_levels'][0]['group_id']).to eq(push_group.id)
        end

        it 'can protect a branch while allowing a group to merge' do
          merge_group = invited_group

          post post_endpoint, params: { name: branch_name, allowed_to_merge: [{ group_id: merge_group.id }] }

          expect_protection_to_be_successful
          expect(json_response['merge_access_levels'][0]['group_id']).to eq(merge_group.id)
        end

        it 'can protect a branch while allowing a group to unprotect' do
          unprotect_group = invited_group

          post post_endpoint, params: { name: branch_name, allowed_to_unprotect: [{ group_id: unprotect_group.id }] }

          expect_protection_to_be_successful
          expect(json_response['unprotect_access_levels'][0]['group_id']).to eq(unprotect_group.id)
        end

        context 'with member_role_id' do
          let_it_be(:group) { project.namespace.root_ancestor }
          let_it_be(:member_role) { create(:member_role, namespace: group) }

          before do
            stub_licensed_features(custom_roles: true)
          end

          it 'can protect a branch with a custom role allowed to merge', :aggregate_failures do
            post post_endpoint, params: {
              name: branch_name,
              allowed_to_merge: [{ member_role_id: member_role.id }]
            }

            expect_protection_to_be_successful
            expect(json_response['merge_access_levels'][0]['member_role_id']).to eq(member_role.id)
          end

          it 'can protect a branch with a custom role allowed to push', :aggregate_failures do
            post post_endpoint, params: {
              name: branch_name,
              allowed_to_push: [{ member_role_id: member_role.id }]
            }

            expect_protection_to_be_successful
            expect(json_response['push_access_levels'][0]['member_role_id']).to eq(member_role.id)
          end

          it 'can protect a branch with a custom role allowed to unprotect', :aggregate_failures do
            post post_endpoint, params: {
              name: branch_name,
              allowed_to_unprotect: [{ member_role_id: member_role.id }]
            }

            expect_protection_to_be_successful
            expect(json_response['unprotect_access_levels'][0]['member_role_id']).to eq(member_role.id)
          end

          it 'does not add default Maintainer role when only member_role_id entries are given', :aggregate_failures do
            post post_endpoint, params: {
              name: branch_name,
              allowed_to_merge: [{ member_role_id: member_role.id }]
            }

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['merge_access_levels'].count).to eq(1)
            expect(json_response['merge_access_levels'][0]['member_role_id']).to eq(member_role.id)
          end

          context 'when member_role belongs to a different namespace' do
            let_it_be(:other_group) { create(:group) }
            let_it_be(:other_member_role) { create(:member_role, namespace: other_group) }

            it 'returns an error' do
              post post_endpoint, params: {
                name: branch_name,
                allowed_to_merge: [{ member_role_id: other_member_role.id }]
              }

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
            end
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(custom_roles_for_protected_branches: false)
            end

            it 'returns an error' do
              post post_endpoint, params: {
                name: branch_name,
                allowed_to_merge: [{ member_role_id: member_role.id }]
              }

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
            end
          end
        end

        context 'when array types have a wrong format' do
          it 'returns a bad request error' do
            post post_endpoint,
              params: { name: branch_name, allowed_to_merge: [''], allowed_to_unprotect: [''], allowed_to_push: [''] }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['error']).to eq(
              'allowed_to_push is invalid, allowed_to_merge is invalid, allowed_to_unprotect is invalid'
            )
          end
        end

        it "fails if users don't all have access to the project" do
          push_user = create(:user)

          post post_endpoint, params: { name: branch_name, allowed_to_merge: [{ user_id: push_user.id }] }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message'][0]).to match(/is not a member of the project/)
        end

        it "fails if groups aren't all invited to the project" do
          merge_group = create(:group)

          post post_endpoint, params: { name: branch_name, allowed_to_merge: [{ group_id: merge_group.id }] }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message'][0]).to match(/does not have access to the project/)
        end

        it 'avoids creating default access levels unless necessary' do
          push_user = project_member

          post post_endpoint, params: { name: branch_name, allowed_to_push: [{ user_id: push_user.id }] }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['push_access_levels'].count).to eq(1)
          expect(json_response['merge_access_levels'].count).to eq(1)
          expect(json_response['push_access_levels'][0]['user_id']).to eq(push_user.id)
          expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::MAINTAINER)
        end

        context 'when protected_refs_for_users feature is not available' do
          before do
            stub_licensed_features(protected_refs_for_users: false)
          end

          it 'cannot protect a branch for a user or group only' do
            allowed_to_create_param = [{ group_id: invited_group.id, user_id: project_member.id }]
            post post_endpoint, params: { name: branch_name, allowed_to_push: allowed_to_create_param }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
          end
        end
      end
    end

    context 'when authenticated as a developer' do
      before do
        project.add_developer(user)
      end

      it 'returns a 403 response' do
        post post_endpoint, params: { name: branch_name }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when authenticated as a guest' do
      before do
        project.add_guest(user)
      end

      it 'returns a 403 response' do
        post post_endpoint, params: { name: branch_name }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
