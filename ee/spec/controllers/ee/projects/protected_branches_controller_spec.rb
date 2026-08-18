# frozen_string_literal: true

require "spec_helper"

RSpec.describe Projects::ProtectedBranchesController, feature_category: :source_code_management do
  let(:project) { create(:project, :repository) }
  let(:protected_branch) { create(:protected_branch, project: project) }
  let(:project_params) { { namespace_id: project.namespace.to_param, project_id: project } }
  let(:user) { create(:user) }

  before do
    project.add_maintainer(user)
  end

  context 'when using custom roles' do
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, :repository, group: group) }
    let(:base_params) { project_params.merge(id: protected_branch.id) }

    let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }
    let_it_be(:another_user) { create(:user) }

    let(:maintainer_access_level) { [{ access_level: Gitlab::Access::MAINTAINER }] }
    let(:access_level_params) do
      { merge_access_levels_attributes: maintainer_access_level,
        push_access_levels_attributes: maintainer_access_level }
    end

    let(:create_params) do
      attributes_for(:protected_branch).merge(access_level_params)
    end

    let(:update_params) { { name: 'new_name' } }

    before do
      sign_in(another_user)
    end

    context 'when a user has custom roles with `admin_protected_branch` assigned' do
      let_it_be(:role) { create(:member_role, :guest, :admin_protected_branch, namespace: group) }
      let_it_be(:membership) do
        create(:group_member, :guest, member_role: role, user: another_user, group: group)
      end

      context 'when custom_roles feature is available' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        describe "POST #create" do
          subject(:create_request) { post(:create, params: project_params.merge(protected_branch: create_params)) }

          it 'creates a protected branch' do
            expect { create_request }.to change { ProtectedBranch.count }.by(1)

            expect(response).to have_gitlab_http_status(:found)
          end
        end

        describe "PUT #update" do
          subject(:update_request) { put(:update, params: base_params.merge(protected_branch: update_params)) }

          it 'creates a protected branch' do
            expect { update_request }.to change { protected_branch.reload.name }

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end
  end

  describe "POST #create" do
    shared_examples "protected branch with code owner approvals feature" do |boolean|
      it "sets code owner approvals to #{boolean} when protecting the branch" do
        expect do
          post(:create, params: project_params.merge(protected_branch: create_params))
        end.to change { ProtectedBranch.count }.by(1)

        expect(ProtectedBranch.last.attributes["code_owner_approval_required"]).to eq(boolean)
      end
    end

    let(:maintainer_access_level) { [{ access_level: Gitlab::Access::MAINTAINER }] }
    let(:access_level_params) do
      { merge_access_levels_attributes: maintainer_access_level,
        push_access_levels_attributes: maintainer_access_level }
    end

    let(:create_params) do
      attributes_for(:protected_branch).merge(access_level_params)
    end

    before do
      sign_in(user)
    end

    context "when code_owner_approval_required is 'false'" do
      before do
        create_params[:code_owner_approval_required] = false
      end

      it_behaves_like "protected branch with code owner approvals feature", false
    end

    context "when code_owner_approval_required is 'true'" do
      before do
        create_params[:code_owner_approval_required] = true
      end

      context "when the feature is enabled" do
        before do
          stub_licensed_features(code_owner_approval_required: true)
        end

        it_behaves_like "protected branch with code owner approvals feature", true
      end

      context "when the feature is not enabled" do
        before do
          stub_licensed_features(code_owner_approval_required: false)
        end

        it_behaves_like "protected branch with code owner approvals feature", false
      end
    end
  end

  describe "PUT/PATCH #update" do
    let(:new_name) { "foobar" }

    let(:params) do
      { namespace_id: project.namespace.to_param,
        project_id: project.to_param,
        id: protected_branch.id,
        protected_branch: { name: new_name } }
    end

    subject(:update_protected_branch) { put(:update, params: params) }

    before do
      sign_in(user)
    end

    context 'without blocking scan result policy' do
      it 'renames' do
        expect { update_protected_branch }.to change { protected_branch.reload.name }.to(new_name)
      end
    end

    describe 'MR approval policies' do
      let(:branch_name) { protected_branch.name }
      let(:policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project)
      end

      describe 'block_branch_modification' do
        include_context 'with approval security policy blocking protected branches'

        it 'does not rename' do
          expect { update_protected_branch }.not_to change { protected_branch.reload.name }
        end

        it 'responds with 403' do
          update_protected_branch

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      describe 'prevent_pushing_and_force_pushing' do
        include_context 'with approval security policy preventing force pushing'

        context 'when updating `allow_force_push`' do
          let(:params) do
            { namespace_id: project.namespace.to_param,
              project_id: project.to_param,
              id: protected_branch.id,
              protected_branch: { allow_force_push: true } }
          end

          it 'responds with 403 and does not update', :aggregate_failures do
            expect { update_protected_branch }.not_to change { protected_branch.allow_force_push }
            expect(response).to have_gitlab_http_status(:forbidden)
          end

          context 'when security orchestration policies are not licensed',
            feature_category: :security_policy_management do
            before do
              stub_licensed_features(security_orchestration_policies: false)
            end

            it 'responds with success and updates the protected branch', :aggregate_failures do
              update_protected_branch

              expect(response).to have_gitlab_http_status(:ok)
              expect(protected_branch.reload.allow_force_push).to be(true)
            end
          end
        end

        context 'when updating merge access levels' do
          let(:params) do
            { namespace_id: project.namespace.to_param,
              project_id: project.to_param,
              id: protected_branch.id,
              protected_branch: { merge_access_levels_attributes: [{ user_id: project.owner.id }] } }
          end

          it 'responds with 2xx and updates', :aggregate_failures do
            expect { update_protected_branch }.to change { protected_branch.merge_access_levels.count }.by(1)
            expect(response).to have_gitlab_http_status(:success)
          end
        end
      end
    end
  end
end
