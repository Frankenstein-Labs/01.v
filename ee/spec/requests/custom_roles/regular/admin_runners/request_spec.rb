# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User with admin_runners custom role", feature_category: :runner_core do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be_with_reload(:group) { project.group }
  let_it_be(:role) { create(:member_role, :guest, :admin_runners, namespace: project.group) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  describe Groups::RunnersController, :freeze_time do
    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: user, source: group)
    end

    let_it_be(:runner) do
      create(:ci_runner, :group, :unregistered, groups: [group], registration_type: :authenticated_user)
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

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#register" do
      get register_group_runner_path(group, runner)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#edit" do
      get edit_group_runner_path(group, runner)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe Projects::RunnersController do
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

    it "#new" do
      get new_project_runner_path(project)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#toggle_shared_runners" do
      post toggle_shared_runners_project_runners_path(project)

      expect(response).to have_gitlab_http_status(:ok)
    end

    it "#register", :freeze_time do
      runner = create(:ci_runner, :project, :unregistered, projects: [project], registration_type: :authenticated_user)

      get register_namespace_project_runner_path(group, project, runner)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:register)
    end

    it "#destroy" do
      runner = create(:ci_runner, :project, projects: [project])

      expect_next_instance_of(Ci::Runners::UnregisterRunnerService, runner, user) do |service|
        expect(service).to receive(:execute).once.and_call_original
      end

      delete project_runner_path(project, runner)

      expect(response).to redirect_to(project_runners_path(project))
    end

    it "#pause" do
      runner = create(:ci_runner, :project, projects: [project])

      post pause_project_runner_path(project, runner)

      expect(response).to redirect_to(project_runners_path(project))
    end
  end

  describe Projects::PipelinesController do
    let_it_be(:membership) do
      create(:project_member, :guest, member_role: role, user: user, source: project)
    end

    before do
      sign_in(user)
    end

    it "#index" do
      get project_pipelines_path(project)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include("data-reset-cache-path=\"#{reset_cache_project_settings_ci_cd_path(project)}\"")
    end
  end

  describe ::Projects::Settings::CiCdController do
    let_it_be(:membership) do
      create(:project_member, :guest, member_role: role, user: user, source: project)
    end

    before do
      sign_in(user)
    end

    it "#show" do
      get project_settings_ci_cd_path(project)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include('CI/CD Settings')
    end

    it '#reset_cache' do
      post reset_cache_project_settings_ci_cd_path(project, format: :json)

      expect(response).to have_gitlab_http_status(:ok)
    end
  end

  describe ::Groups::Settings::CiCdController do
    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: user, source: group)
    end

    before do
      sign_in(user)
    end

    it "#show" do
      get group_settings_ci_cd_path(group)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include('CI/CD Settings')
    end
  end

  describe ::Projects::RunnerProjectsController do
    let_it_be(:membership) do
      create(:project_member, :guest, member_role: role, user: user, source: project)
    end

    before do
      sign_in(user)
    end

    it "#create" do
      runner = create(:ci_runner, :project, projects: [project])

      post namespace_project_runner_projects_path(group, project), params: {
        runner_project: {
          runner_id: runner.id
        }
      }

      expect(response).to have_gitlab_http_status(:redirect)
      expect(response).to redirect_to(project_runners_path(project))
    end

    it "#destroy" do
      runner = create(:ci_runner, :project, projects: [project])

      delete namespace_project_runner_project_path(group, project, runner.runner_projects.last)

      expect(response).to have_gitlab_http_status(:redirect)
      expect(response).to redirect_to(project_runners_path(project))
    end
  end

  describe API::Ci::Runners do
    include ApiHelpers

    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: user, source: group)
    end

    let_it_be(:project_runner) do
      create(:ci_runner, :project, description: 'Project runner', projects: [project])
    end

    let_it_be(:group_runner) { create(:ci_runner, :group, description: 'Group runner', groups: [group]) }

    describe "GET /runners" do
      it "returns eligible group runners",
        pending: 'Related to: https://gitlab.com/gitlab-org/gitlab/-/issues/477585' do
        get api("/runners", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(a_hash_including('description' => 'Group runner'))
      end

      it "returns eligible project runners",
        pending: 'Related to: https://gitlab.com/gitlab-org/gitlab/-/issues/477585' do
        get api("/runners", user)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(a_hash_including('description' => 'Project runner'))
      end
    end

    it "GET /runners/:id" do
      get api("/runners/#{project_runner.id}", user)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to include('description' => 'Project runner')
    end

    it "PUT /runners/:id" do
      put api("/runners/#{project_runner.id}", user), params: { description: "Example runner" }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to include('description' => 'Example runner')
    end

    it "DELETE /runners/:id" do
      expect do
        delete api("/runners/#{project_runner.id}", user)

        expect(response).to have_gitlab_http_status(:no_content)
      end.to change { ::Ci::Runner.count }.by(-1)
    end

    describe 'POST /projects/:id/runners', :request_store do
      let_it_be(:private_project) { create(:project, :private) }

      let_it_be(:runner_in_private_project) do
        create(:ci_runner, :project, projects: [private_project])
      end

      context 'when user tries to assign runner created in another private project' do
        let(:path) { "/projects/#{project.id}/runners" }
        let(:params) { { runner_id: runner_in_private_project.id } }

        it 'returns forbidden' do
          post api(path, user), params: params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe API::Groups do
    include ApiHelpers

    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: user, source: group)
    end

    describe "PUT /groups/:id" do
      it "updates the shared_runners_setting" do
        expect do
          put api("/groups/#{group.id}", user), params: {
            shared_runners_setting: 'disabled_and_unoverridable'
          }

          expect(response).to have_gitlab_http_status(:ok)
        end.to change { group.reload.shared_runners_setting }.to('disabled_and_unoverridable')
      end

      it "cannot update other attributes", :aggregate_failures do
        expect do
          put api("/groups/#{group.id}", user), params: {
            name: 'new-name'
          }

          expect(response).to have_gitlab_http_status(:unauthorized)
        end.to not_change { group.reload.name }
      end
    end
  end

  describe API::UserRunners do
    include ApiHelpers

    context 'with a group membership' do
      let_it_be(:membership) do
        create(:group_member, :guest, member_role: role, user: user, source: group)
      end

      it 'creates a group runner' do
        post api("/user/runners", user), params: {
          runner_type: 'group_type',
          group_id: group.id
        }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to include('id' => a_value, 'token' => a_value)
      end

      it 'creates a project runner' do
        post api("/user/runners", user), params: {
          runner_type: 'project_type',
          project_id: project.id
        }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to include('id' => a_value, 'token' => a_value)
      end
    end

    context 'without the admin_runners permission' do
      let_it_be(:role) { create(:member_role, :guest, namespace: group) }
      let_it_be(:membership) do
        create(:group_member, :guest, member_role: role, user: user, source: group)
      end

      it 'does not create a group runner' do
        post api("/user/runners", user), params: {
          runner_type: 'group_type',
          group_id: group.id
        }

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response).to include('message' => a_value)
      end
    end
  end

  describe Mutations::Ci::Runner::Create do
    include GraphqlHelpers

    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: user, source: group)
    end

    it "creates a project runner" do
      post_graphql_mutation(graphql_mutation(:runner_create, {
        runner_type: 'PROJECT_TYPE',
        project_id: project.to_global_id
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      mutation_response = graphql_mutation_response(:runner_create)

      expect(mutation_response).to be_present
      expect(mutation_response['runner']).to be_present
      expect(mutation_response['errors']).to be_empty
    end

    it "creates a group runner" do
      post_graphql_mutation(graphql_mutation(:runner_create, {
        runner_type: 'GROUP_TYPE',
        group_id: group.to_global_id
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      mutation_response = graphql_mutation_response(:runner_create)

      expect(mutation_response).to be_present
      expect(mutation_response['runner']).to be_present
      expect(mutation_response['errors']).to be_empty
    end
  end

  describe Mutations::Ci::Runner::Update do
    include GraphqlHelpers

    let_it_be(:membership) do
      create(:project_member, :guest, member_role: role, user: user, source: project)
    end

    let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }

    it "updates a runner" do
      post_graphql_mutation(graphql_mutation(:runner_update, {
        id: runner.to_global_id,
        description: 'Example'
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      mutation_response = graphql_mutation_response(:runner_update)

      expect(mutation_response).to be_present
      expect(mutation_response['runner']).to be_present
      expect(mutation_response['runner']['description']).to eq('Example')
      expect(mutation_response['errors']).to be_empty
    end
  end

  describe Mutations::Ci::Runner::Delete do
    include GraphqlHelpers

    let_it_be(:membership) do
      create(:project_member, :guest, member_role: role, user: user, source: project)
    end

    let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }

    it "deletes a runner" do
      post_graphql_mutation(graphql_mutation(:runner_delete, {
        id: runner.to_global_id
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      mutation_response = graphql_mutation_response(:runner_delete)
      expect(mutation_response).to be_present
      expect(mutation_response['errors']).to be_empty
    end
  end

  describe Mutations::Ci::Runner::BulkDelete do
    include GraphqlHelpers

    let_it_be(:membership) do
      create(:project_member, :guest, member_role: role, user: user, source: project)
    end

    let_it_be(:runners) { create_list(:ci_runner, 2, :project, projects: [project]) }

    it "deletes the runners" do
      post_graphql_mutation(graphql_mutation(:bulk_runner_delete, {
        ids: runners.map(&:to_global_id)
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      mutation_response = graphql_mutation_response(:bulk_runner_delete)
      expect(mutation_response).to be_present
      expect(mutation_response['errors']).to be_empty
    end
  end

  describe Mutations::Ci::Runner::Cache::Clear do
    include GraphqlHelpers

    let_it_be(:membership) do
      create(:project_member, :guest, member_role: role, user: user, source: project)
    end

    it "clears the runner cache" do
      post_graphql_mutation(graphql_mutation(:runner_cache_clear, {
        project_id: project.to_global_id
      }, 'errors'), current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      mutation_response = graphql_mutation_response(:runner_cache_clear)
      expect(mutation_response).to be_present
      expect(mutation_response['errors']).to be_empty
    end
  end

  describe Mutations::Ci::NamespaceCiCdSettingsUpdate do
    include GraphqlHelpers

    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: user, source: group)
    end

    it "updates the `allow_stale_runner_pruning` setting" do
      post_graphql_mutation(graphql_mutation(:namespace_ci_cd_settings_update, {
        full_path: group.full_path,
        allow_stale_runner_pruning: true
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)
      expect(fresh_response_data['errors']).to be_blank

      mutation_response = graphql_mutation_response(:namespace_ci_cd_settings_update)
      expect(mutation_response).to be_present
      expect(mutation_response['ciCdSettings']).to be_present
      expect(mutation_response['errors']).to be_empty
    end

    it "does not allow updating settings that are not related to runners" do
      arguments = described_class
        .own_arguments
        .map { |key, _value| key.underscore.to_sym }
        .excluding(:allow_stale_runner_pruning, :full_path)
      expect(arguments).to be_empty
    end
  end

  describe Mutations::Groups::Update do
    include GraphqlHelpers
    let_it_be(:membership) do
      create(:group_member, :guest, member_role: role, user: user, source: group)
    end

    it 'updates the shared_runners_setting setting' do
      post_graphql_mutation(graphql_mutation(:group_update, {
        full_path: group.full_path,
        shared_runners_setting: 'DISABLED_AND_UNOVERRIDABLE'
      }), current_user: user)

      expect(response).to have_gitlab_http_status(:success)

      mutation_response = graphql_mutation_response(:group_update)
      expect(mutation_response).to be_present
      expect(mutation_response['group']).to be_present
      expect(mutation_response['errors']).to be_empty
    end

    it 'cannot update any other individual setting', :aggregate_failures do
      expect do
        post_graphql_mutation(graphql_mutation(:group_update, {
          full_path: group.full_path,
          name: 'example'
        }), current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(fresh_response_data['errors']).to be_present
        expect(fresh_response_data['errors'][0]['message'])
          .to eq(Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR)
      end.to not_change { group.reload.name }
    end

    it 'cannot update any other combined settings', :aggregate_failures do
      expect do
        post_graphql_mutation(graphql_mutation(:group_update, {
          full_path: group.full_path,
          name: 'example',
          shared_runners_setting: 'DISABLED_AND_UNOVERRIDABLE'
        }), current_user: user)

        expect(response).to have_gitlab_http_status(:success)
        expect(fresh_response_data['errors']).to be_present
        expect(fresh_response_data['errors'][0]['message'])
          .to eq(Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR)
      end.to not_change { group.reload.name }
        .and not_change { group.shared_runners_setting }
    end
  end
end
