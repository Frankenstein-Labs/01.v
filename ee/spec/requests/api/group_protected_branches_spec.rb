# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::GroupProtectedBranches, feature_category: :source_code_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }
  let_it_be(:guest) { create(:user, guest_of: group) }

  let(:protected_name) { 'feature' }
  let(:branch_name) { protected_name }

  let!(:protected_branch) do
    create(:protected_branch, project: nil, group: group, name: protected_name)
  end

  describe "GET /groups/:id/protected_branches" do
    let(:params) { {} }
    let(:route) { "/groups/#{group.id}/protected_branches" }

    it_behaves_like 'authorizing granular token permissions', :read_protected_branch do
      let(:boundary_object) { group }
      let(:user) { owner }
      let(:request) do
        get api(route, personal_access_token: pat)
      end
    end

    shared_examples_for 'protected branches' do
      it 'returns the protected branches' do
        get api(route, user), params: params.merge(per_page: 100)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to include_pagination_headers
        expect(response).to match_response_schema('protected_branches')
        protected_branch_names = json_response.pluck('name')
        expect(protected_branch_names).to match_array(expected_branch_names)
        expect(json_response).not_to include('inherited')
      end
    end

    context 'when authenticated as a owner' do
      let(:user) { owner }

      context 'when search param is not present' do
        it_behaves_like 'protected branches' do
          let(:expected_branch_names) { group.protected_branches.pluck('name') }
        end
      end

      context 'when search param is present' do
        it_behaves_like 'protected branches' do
          let(:another_protected_branch) { create(:protected_branch, project: nil, group: group, name: 'stable') }
          let(:params) { { search: another_protected_branch.name } }
          let(:expected_branch_names) { [another_protected_branch.name] }
        end
      end
    end

    context 'when authenticated as a guest' do
      let(:user) { guest }

      it_behaves_like '403 response' do
        let(:request) { get api(route, user) }
      end
    end

    describe 'avoid N+1 sql queries' do
      it 'does not perform N+1 sql queries' do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          get api(route, owner), params: params.merge(per_page: 100)
        end

        create_list(:protected_branch, 2, project: nil, group: group)

        expect do
          get api(route, owner), params: params.merge(per_page: 100)
        end.not_to exceed_all_query_limit(control)
      end

      context 'with member_role access levels' do
        before do
          stub_licensed_features(custom_roles: true)
          stub_feature_flags(custom_roles_for_protected_branches: true)
          member_role = create(:member_role, namespace: group)
          pb = create(:protected_branch, project: nil, group: group)
          create(:protected_branch_push_access_level, protected_branch: pb, member_role: member_role)
          create(:protected_branch_merge_access_level, protected_branch: pb, member_role: member_role)
        end

        it 'does not perform N+1 sql queries' do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            get api(route, owner), params: params.merge(per_page: 100)
          end

          member_role2 = create(:member_role, namespace: group)
          pb2 = create(:protected_branch, project: nil, group: group)
          create(:protected_branch_push_access_level, protected_branch: pb2, member_role: member_role2)
          create(:protected_branch_merge_access_level, protected_branch: pb2, member_role: member_role2)

          expect do
            get api(route, owner), params: params.merge(per_page: 100)
          end.not_to exceed_all_query_limit(control)
        end
      end
    end
  end

  describe "GET /groups/:id/protected_branches/:branch" do
    it_behaves_like 'authorizing granular token permissions', :read_protected_branch do
      let(:boundary_object) { group }
      let(:user) { owner }
      let(:request) do
        get api("/groups/#{group.id}/protected_branches/#{branch_name}", personal_access_token: pat)
      end
    end

    let(:route) { "/groups/#{group.id}/protected_branches/#{branch_name}" }

    shared_examples_for 'protected branch' do
      it 'returns the protected branch' do
        get api(route, user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to match_response_schema('protected_branch')
        expect(json_response['name']).to eq(branch_name)
        expect(json_response['allow_force_push']).to be(false)
        expect(json_response['push_access_levels'][0]['access_level']).to eq(::Gitlab::Access::MAINTAINER)
        expect(json_response['merge_access_levels'][0]['access_level']).to eq(::Gitlab::Access::MAINTAINER)
      end

      context 'when protected branch does not exist' do
        let(:branch_name) { 'unknown' }

        it_behaves_like '404 response' do
          let(:request) { get api(route, user) }
          let(:message) { '404 ProtectedBranch Not Found' }
        end
      end
    end

    context 'when authenticated as a owner' do
      let(:user) { owner }

      it_behaves_like 'protected branch'

      context 'when protected branch contains a wildcard' do
        let(:protected_name) { 'feature*' }

        it_behaves_like 'protected branch'
      end

      context 'when protected branch contains a period' do
        let(:protected_name) { 'my.feature' }

        it_behaves_like 'protected branch'
      end
    end

    context 'when authenticated as a guest' do
      let(:user) { guest }

      it_behaves_like '403 response' do
        let(:request) { get api(route, user) }
      end
    end

    context 'with member_role access levels' do
      let_it_be(:member_role) { create(:member_role, :developer, namespace: group) }

      context 'when custom roles are licensed' do
        before do
          stub_licensed_features(custom_roles: true)
          protected_branch.push_access_levels.create!(
            member_role: member_role, access_level: member_role.base_access_level
          )
        end

        it 'returns member_role_id and member_role_name in push access levels', :aggregate_failures do
          get api(route, owner)

          expect(response).to have_gitlab_http_status(:ok)
          push_level = json_response['push_access_levels'].find { |l| l['member_role_id'].present? }
          expect(push_level).to be_present
          expect(push_level['member_role_id']).to eq(member_role.id)
          expect(push_level['member_role_name']).to eq(member_role.name)
        end

        it 'returns null member_role fields for access levels without a member role', :aggregate_failures do
          get api(route, owner)

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

          get api(route, owner)

          expect(response).to have_gitlab_http_status(:ok)
          merge_level = json_response['merge_access_levels'].find { |l| l['member_role_id'].present? }
          expect(merge_level).to be_present
          expect(merge_level['member_role_id']).to eq(member_role.id)
          expect(merge_level['member_role_name']).to eq(member_role.name)
        end

        context 'when custom_roles_for_protected_branches is disabled' do
          before do
            stub_feature_flags(custom_roles_for_protected_branches: false)
          end

          it 'does not expose member_role_id or member_role_name', :aggregate_failures do
            get api(route, owner)

            expect(response).to have_gitlab_http_status(:ok)
            json_response['push_access_levels'].each do |level|
              expect(level).not_to have_key('member_role_id')
              expect(level).not_to have_key('member_role_name')
            end
          end
        end
      end

      context 'when custom roles are unlicensed' do
        before do
          stub_licensed_features(custom_roles: true)
          protected_branch.push_access_levels.create!(
            member_role: member_role, access_level: member_role.base_access_level
          )
          stub_licensed_features(custom_roles: false)
        end

        it 'does not expose member_role_id or member_role_name', :aggregate_failures do
          get api(route, owner)

          expect(response).to have_gitlab_http_status(:ok)
          json_response['push_access_levels'].each do |level|
            expect(level).not_to have_key('member_role_id')
            expect(level).not_to have_key('member_role_name')
          end
        end
      end
    end
  end

  describe 'POST /groups/:id/protected_branches' do
    it_behaves_like 'authorizing granular token permissions', :create_protected_branch do
      let(:boundary_object) { group }
      let(:user) { owner }
      let(:request) do
        post api("/groups/#{group.id}/protected_branches", personal_access_token: pat), params: { name: 'new_branch' }
      end
    end

    let(:branch_name) { 'new_branch' }
    let(:post_endpoint) { api("/groups/#{group.id}/protected_branches", user) }

    def expect_protection_to_be_successful
      expect(response).to have_gitlab_http_status(:created)
      expect(json_response['name']).to eq(branch_name)
    end

    context 'when authenticated as a owner' do
      let(:user) { owner }

      context 'when protects by different params' do
        using RSpec::Parameterized::TableSyntax

        where(:allow_force_push, :push_access_level, :merge_access_level) do
          nil   | nil                       | nil
          nil   | Gitlab::Access::DEVELOPER | nil
          nil   | nil                       | Gitlab::Access::DEVELOPER
          nil   | Gitlab::Access::DEVELOPER | Gitlab::Access::DEVELOPER
          nil   | Gitlab::Access::NO_ACCESS | nil
          nil   | nil                       | Gitlab::Access::NO_ACCESS
          nil   | Gitlab::Access::NO_ACCESS | Gitlab::Access::NO_ACCESS
          true  | nil                       | nil
        end

        with_them do
          let(:allow_force_push_result) { allow_force_push || false }
          let(:push_access_level_result) { push_access_level || Gitlab::Access::MAINTAINER }
          let(:merge_access_level_result) { merge_access_level || Gitlab::Access::MAINTAINER }
          let(:api_params) do
            {
              name: branch_name,
              allow_force_push: allow_force_push,
              push_access_level: push_access_level,
              merge_access_level: merge_access_level
            }.compact
          end

          it do
            post post_endpoint, params: api_params

            expect_protection_to_be_successful
            expect(response).to match_response_schema('protected_branch')
            expect(json_response['allow_force_push']).to eq(allow_force_push_result)
            expect(json_response['push_access_levels'][0]['access_level']).to eq(push_access_level_result)
            expect(json_response['merge_access_levels'][0]['access_level']).to eq(merge_access_level_result)
          end
        end
      end

      describe 'code_owner_approval_required' do
        using RSpec::Parameterized::TableSyntax

        where(:feature_available, :param_value, :result_value) do
          false | false | false
          false | true  | false
          true  | false | false
          true  | true  | true
        end

        with_them do
          before do
            stub_licensed_features(code_owner_approval_required: feature_available)
          end

          it do
            post post_endpoint, params: { name: branch_name, code_owner_approval_required: param_value }

            expect_protection_to_be_successful
            expect(response).to match_response_schema('protected_branch')
            expect(json_response['code_owner_approval_required']).to eq(result_value)
          end
        end
      end

      it 'returns a 409 error if the same branch is protected twice' do
        post post_endpoint, params: { name: protected_name }

        expect(response).to have_gitlab_http_status(:conflict)
      end

      context 'when branch has a wildcard in its name' do
        let(:branch_name) { 'feature/*' }

        it "protects multiple branches with a wildcard in the name" do
          post post_endpoint, params: { name: branch_name }

          expect_protection_to_be_successful
          expect(json_response['push_access_levels'][0]['access_level']).to eq(Gitlab::Access::MAINTAINER)
          expect(json_response['merge_access_levels'][0]['access_level']).to eq(Gitlab::Access::MAINTAINER)
        end
      end

      context 'when a policy restricts rule creation' do
        before do
          disallow(:create_protected_branch, an_instance_of(ProtectedBranch))
        end

        it 'prevents creations of the protected branch rule' do
          post post_endpoint, params: { name: branch_name }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when protected branch is invalid' do
        it "returns a 422" do
          post post_endpoint, params: { name: '' }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'with member_role_id' do
        let_it_be(:member_role) { create(:member_role, namespace: group) }

        context 'when custom roles are licensed' do
          before do
            stub_licensed_features(custom_roles: true)
          end

          it 'can protect a branch with a custom role allowed to merge, push, and unprotect', :aggregate_failures do
            post post_endpoint, params: {
              name: branch_name,
              allowed_to_merge: [{ member_role_id: member_role.id }],
              allowed_to_push: [{ member_role_id: member_role.id }],
              allowed_to_unprotect: [{ member_role_id: member_role.id }]
            }

            expect_protection_to_be_successful
            expect(json_response['merge_access_levels'].count).to eq(1)
            expect(json_response['merge_access_levels'][0]['member_role_id']).to eq(member_role.id)
            expect(json_response['push_access_levels'].count).to eq(1)
            expect(json_response['push_access_levels'][0]['member_role_id']).to eq(member_role.id)
            expect(json_response['unprotect_access_levels'].count).to eq(1)
            expect(json_response['unprotect_access_levels'][0]['member_role_id']).to eq(member_role.id)
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

            it 'returns an error', :aggregate_failures do
              post post_endpoint, params: {
                name: branch_name,
                allowed_to_merge: [{ member_role_id: member_role.id }]
              }

              expect(response).to have_gitlab_http_status(:unprocessable_entity)
              expect(json_response['message']).to include(
                'Merge access levels member role is not licensed for the root namespace'
              )
            end
          end
        end

        context 'when custom roles are unlicensed' do
          before do
            stub_licensed_features(custom_roles: false)
          end

          it 'returns an error', :aggregate_failures do
            post post_endpoint, params: {
              name: branch_name,
              allowed_to_merge: [{ member_role_id: member_role.id }]
            }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to include(
              'Merge access levels member role is not licensed for the root namespace'
            )
          end
        end
      end
    end

    context 'when authenticated as a guest' do
      let(:user) { guest }

      it "returns a 403 error if guest" do
        post post_endpoint, params: { name: branch_name }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH /groups/:id/protected_branches/:name' do
    let(:route) { "/groups/#{group.id}/protected_branches/#{branch_name}" }

    it_behaves_like 'authorizing granular token permissions', :update_protected_branch do
      let(:boundary_object) { group }
      let(:user) { owner }
      let(:request) do
        patch api(route, personal_access_token: pat),
          params: { allow_force_push: true }
      end
    end

    context 'when authenticated as a owner' do
      let(:user) { owner }

      it "updates a single branch" do
        expect do
          patch api(route, user), params: { allow_force_push: true }
        end.to change { protected_branch.reload.allow_force_push }.from(false).to(true)
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when returned protected branch is invalid' do
      let(:user) { owner }

      before do
        allow_next_found_instance_of(ProtectedBranch) do |instance|
          allow(instance).to receive(:valid?).and_return(false)
        end
      end

      it "returns a 422" do
        expect do
          patch api(route, user), params: { allow_force_push: true }
        end.not_to change { protected_branch.reload.allow_force_push }

        expect(response).to have_gitlab_http_status(:unprocessable_entity)
      end
    end

    context 'with member_role_id' do
      let_it_be(:member_role) { create(:member_role, namespace: group) }
      let(:user) { owner }

      context 'when custom roles are licensed' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'adds a member role access level to merge, push, and unprotect', :aggregate_failures do
          patch api(route, user), params: {
            allowed_to_merge: [{ member_role_id: member_role.id }],
            allowed_to_push: [{ member_role_id: member_role.id }],
            allowed_to_unprotect: [{ member_role_id: member_role.id }]
          }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['merge_access_levels'].last['member_role_id']).to eq(member_role.id)
          expect(json_response['push_access_levels'].last['member_role_id']).to eq(member_role.id)
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

          it 'returns an error', :aggregate_failures do
            patch api(route, user), params: {
              allowed_to_merge: [{ member_role_id: member_role.id }]
            }

            expect(response).to have_gitlab_http_status(:unprocessable_entity)
            expect(json_response['message']).to include(
              'Merge access levels member role is not licensed for the root namespace'
            )
          end
        end
      end

      context 'when custom roles are unlicensed' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'returns an error', :aggregate_failures do
          patch api(route, user), params: {
            allowed_to_merge: [{ member_role_id: member_role.id }]
          }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']).to include(
            'Merge access levels member role is not licensed for the root namespace'
          )
        end
      end
    end

    context 'when authenticated as a guest' do
      let(:user) { guest }

      it "returns a 403 error" do
        patch api(route, user), params: { allow_force_push: true }

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /groups/:id/protected_branches/unprotect/:branch" do
    it_behaves_like 'authorizing granular token permissions', :delete_protected_branch do
      let(:boundary_object) { group }
      let(:user) { owner }
      let(:request) do
        delete api("/groups/#{group.id}/protected_branches/#{branch_name}", personal_access_token: pat)
      end
    end

    let(:user) { owner }
    let(:delete_endpoint) { api("/groups/#{group.id}/protected_branches/#{branch_name}", user) }

    it "unprotects a single branch" do
      delete delete_endpoint

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "returns 404 if branch does not exist" do
      delete api("/groups/#{group.id}/protected_branches/barfoo", user)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when a policy restricts rule deletion' do
      it "prevents deletion of the protected branch rule" do
        disallow(:destroy_protected_branch, protected_branch)

        delete delete_endpoint

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when branch has a wildcard in its name' do
      let(:protected_name) { 'feature*' }

      it "unprotects a wildcard branch" do
        delete delete_endpoint

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  def disallow(ability, protected_branch)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, ability, protected_branch).and_return(false)
  end
end
