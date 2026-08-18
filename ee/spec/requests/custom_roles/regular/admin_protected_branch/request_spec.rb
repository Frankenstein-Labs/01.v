# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_protected_branch custom role', feature_category: :source_code_management do
  include ApiHelpers

  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  let_it_be(:current_user) { create(:user) }
  let_it_be(:role) do
    create(:member_role, :guest, namespace: group, read_code: true, admin_protected_branch: true)
  end

  let_it_be(:membership) do
    create(:group_member, :guest, member_role: role, user: current_user, group: group)
  end

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(current_user)
  end

  describe Projects::ProtectedBranchesController do
    describe 'POST #create' do
      include_context 'with correct create params'

      it 'user can create protected branch via a custom role' do
        post project_protected_branches_path(project, params: { protected_branch: create_params })

        expect(response).to have_gitlab_http_status(:found)
      end
    end

    describe 'PUT #update' do
      include_context 'with correct update params'

      it 'user can update the protected branch via a custom role' do
        put project_protected_branch_path(project, id: protected_branch, params: { protected_branch: update_params })

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe 'DELETE #destroy' do
      it 'user can destroy the protected branch via a custom role' do
        delete project_protected_branch_path(project, id: protected_branch)

        expect(response).to have_gitlab_http_status(:found)
      end
    end
  end

  describe Projects::Settings::RepositoryController do
    describe 'GET show' do
      it 'user can see project repository settings page via a custom role' do
        get namespace_project_settings_repository_path(namespace_id: group, project_id: project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe API::ProtectedBranches do
    describe "GET /projects/:id/protected_branches" do
      it 'user can see a protected branches list via a custom role' do
        get api("/projects/#{project.id}/protected_branches", current_user)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe "GET /projects/:id/protected_branches/:branch" do
      it 'user can see a protected branch detail via a custom role' do
        get api("/projects/#{project.id}/protected_branches/#{protected_branch.name}", current_user)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe "PATCH /projects/:id/protected_branches/:branch" do
      let(:params) do
        { access_level_param:
          [
            {
              access_level: Gitlab::Access::MAINTAINER
            }
          ] }
      end

      it 'user can update a protected branch via a custom role' do
        patch api("/projects/#{project.id}/protected_branches/#{protected_branch.name}", current_user), params: params

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe 'POST /projects/:id/protected_branches' do
      it 'user can create a protected branch via a custom role' do
        post api("/projects/#{project.id}/protected_branches", current_user), params: { name: 'branch_name' }

        expect(response).to have_gitlab_http_status(:created)
      end
    end

    describe 'DELETE /projects/:id/protected_branches/:name' do
      it 'user can create a protected branch via a custom role' do
        delete api("/projects/#{project.id}/protected_branches/#{protected_branch.name}", current_user)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end
  end
end
