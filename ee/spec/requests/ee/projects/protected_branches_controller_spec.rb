# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProtectedBranchesController, feature_category: :source_code_management do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :repository, group: group) }
  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  let_it_be(:user) { create(:user) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group, admin_protected_branch: true) }
  let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

  let(:create_request) do
    post project_protected_branches_path(project, params: { protected_branch: create_params })
  end

  let(:update_request) do
    put project_protected_branch_path(project, id: protected_branch, params: { protected_branch: update_params })
  end

  subject(:delete_request) { delete project_protected_branch_path(project, id: protected_branch) }

  before do
    sign_in(user)
  end

  context 'with custom_roles feature enabled' do
    before do
      stub_licensed_features(custom_roles: true)
    end

    describe "POST #create" do
      include_context 'with correct create params'

      it 'creates a protected branch' do
        expect { create_request }.to change { ProtectedBranch.count }.by(1)

        expect(response).to have_gitlab_http_status(:found)
      end
    end

    describe "PUT #update" do
      include_context 'with correct update params'

      it 'updates the protected branch' do
        expect { update_request }.to change { protected_branch.reload.name }.to('new name')

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe "DELETE #destroy" do
      it 'destroys the protected branch' do
        expect { delete_request }.to change { ProtectedBranch.count }.by(-1)

        expect(response).to have_gitlab_http_status(:found)
      end
    end
  end

  context 'with custom_roles feature disabled' do
    before do
      stub_licensed_features(custom_roles: false)
    end

    describe "POST #create" do
      include_context 'with correct create params'

      it 'does not create a protected branch' do
        expect { create_request }.not_to change { ProtectedBranch.count }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    describe "PUT #update" do
      include_context 'with correct update params'

      it 'does not update the protected branch' do
        expect { update_request }.not_to change { protected_branch.reload.name }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    describe "DELETE #destroy" do
      it 'does not destroy the protected branch' do
        expect { delete_request }.not_to change { ProtectedBranch.count }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
