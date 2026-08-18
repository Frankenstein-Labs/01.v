# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Branches, feature_category: :source_code_management do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project) do
    create(:project, :in_group, :repository, creator: user, path: 'my.project', maintainers: user)
  end

  let_it_be_with_reload(:protected_branch) { create(:protected_branch, project: project) }

  before_all do
    project.repository.add_branch(user, protected_branch.name, 'master')
  end

  describe "GET /projects/:id/repository/branches", :use_clean_rails_redis_caching, :clean_gitlab_redis_shared_state do
    let(:route) { "/projects/#{project.id}/repository/branches" }

    before_all do
      project.update!(visibility_level: Gitlab::VisibilityLevel::PUBLIC)
    end

    context 'when unauthenticated', 'and project is public' do
      describe 'caching' do
        context "when project's group's protected branches change" do
          it 'request for new value instantly' do
            get api(route), params: { per_page: 1 }

            ProtectedBranches::CreateService.new(project.group, user, { name: '*' }).execute(skip_authorization: true)

            expect(API::Entities::Branch).to receive(:represent)

            get api(route), params: { per_page: 1 }
          end
        end
      end
    end
  end

  describe 'PUT /projects/:id/repository/branches/:branch/protect' do
    subject(:protect) do
      put api("/projects/#{project.id}/repository/branches/#{protected_branch.name}/protect", user),
        params: { developers_can_push: true, developers_can_merge: true }
    end

    context "when no one can push" do
      before do
        protected_branch.push_access_levels.create!(access_level: Gitlab::Access::NO_ACCESS)
      end

      it "updates 'developers_can_push' without removing the 'no_one' access level" do
        protect

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['name']).to eq(protected_branch.name)
        expect(protected_branch.reload.push_access_levels.pluck(:access_level)).to include(Gitlab::Access::NO_ACCESS)
      end
    end
  end

  describe 'PUT /projects/:id/repository/branches/:branch/unprotect' do
    subject(:unprotect) do
      put api("/projects/#{project.id}/repository/branches/#{protected_branch.name}/unprotect", user)
    end

    context 'with blocking scan result policy' do
      include_context 'with approval policy blocking protected branches' do
        let(:branch_name) { protected_branch.name }
        let(:policy_configuration) do
          create(:security_orchestration_policy_configuration, project: protected_branch.project)
        end

        include_context 'with persisted approval policies'

        it 'blocks unprotecting branches' do
          unprotect

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end
end
