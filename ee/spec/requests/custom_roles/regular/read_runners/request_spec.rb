# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User with read_runners custom role", feature_category: :runner_core do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be_with_reload(:group) { project.group }
  let_it_be(:role) { create(:member_role, :guest, :read_runners, namespace: project.group) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe Groups::RunnersController do
    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: user, source: group)
    end

    let_it_be_with_reload(:runner) do
      create(:ci_runner, :group, groups: [group], registration_type: :authenticated_user)
    end

    before do
      sign_in(user)
    end

    it "#index" do
      get group_runners_path(group)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#show" do
      get group_runners_path(group, runner)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#new" do
      get new_group_runner_path(group)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#register" do
      get register_group_runner_path(group, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#edit" do
      get edit_group_runner_path(group, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe Projects::RunnersController do
    let_it_be_with_reload(:runner) { create(:ci_runner, :project, projects: [project]) }
    let_it_be(:membership) do
      create(:project_member, :guest, member_role: role, user: user, source: project)
    end

    before do
      sign_in(user)
    end

    it "#index" do
      get project_runners_path(project)

      expect(response).to redirect_to(project_settings_ci_cd_path(project, anchor: 'js-runners-settings'))
    end

    describe '#show' do
      context 'with runner owned by project where user has the custom role' do
        it 'returns 200' do
          get project_runner_path(project, runner)

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'with runner owned by another project' do
        it 'returns 404' do
          get project_runner_path(project, create(:ci_runner, :project, projects: [create(:project)]))

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    it "#new" do
      get new_project_runner_path(project)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#toggle_shared_runners" do
      post toggle_shared_runners_project_runners_path(project)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#register" do
      get register_namespace_project_runner_path(group, project, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#destroy" do
      delete project_runner_path(project, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it "#pause" do
      post pause_project_runner_path(project, runner)

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe API::Ci::Runners do
    include ApiHelpers

    describe "GET /runners/:id" do
      subject do
        get api("/runners/#{runner.id}", user)
        response
      end

      context 'with a group runner' do
        let_it_be_with_reload(:runner) { create(:ci_runner, :group, groups: [project.group]) }

        it { is_expected.to have_gitlab_http_status(:forbidden) }

        context 'when user has the custom role' do
          before do
            create(:group_member, :guest, member_role: role, user: user, source: project.group)
          end

          it { is_expected.to have_gitlab_http_status(:ok) }
        end
      end

      context 'with a project runner' do
        let_it_be_with_reload(:runner) { create(:ci_runner, :project, projects: [project]) }

        it { is_expected.to have_gitlab_http_status(:forbidden) }

        context 'when user has the custom role' do
          context 'with custom role in the runner\'s owner project' do
            before do
              create(:project_member, :guest, member_role: role, user: user, source: project)
            end

            it { is_expected.to have_gitlab_http_status(:ok) }
          end

          context 'with custom role in a project that shares the runner' do
            let_it_be(:other_project) { create(:project, :in_group) }
            let_it_be(:role) do
              create(:member_role, :guest, :read_runners, namespace: other_project.group)
            end

            before do
              runner.projects << other_project
              create(:project_member, :guest, member_role: role, user: user, source: other_project)
            end

            it { is_expected.to have_gitlab_http_status(:ok) }
          end
        end
      end
    end
  end
end
