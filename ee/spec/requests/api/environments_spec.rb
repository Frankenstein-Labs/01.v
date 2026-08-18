# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::Environments, feature_category: :continuous_delivery do
  describe 'PUT /projects/:id/environments/:environment_id', :request_store do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, group: group) }
    let_it_be(:environment) { create(:environment, project: project, tier: 'production') }
    let_it_be(:developer_no_access) { create(:user) }
    let_it_be(:developer_with_access) { create(:user) }
    let_it_be(:maintainer_no_access) { create(:user) }

    let(:docs_url) do
      ::Gitlab::Routing.url_helpers.help_page_url('ci/environments/protected_environments.md')
    end

    before_all do
      project.add_developer(developer_no_access)
      project.add_developer(developer_with_access)
      project.add_maintainer(maintainer_no_access)
    end

    before do
      stub_licensed_features(protected_environments: true)
    end

    def expected_protected_env_message
      "403 Forbidden - You do not have permission to modify the protected environment " \
        "'#{environment.name}'. This endpoint enforces Protected Environment access policies.\n" \
        "To resolve this, ask a project Maintainer or Owner to grant you access under " \
        "Settings > CI/CD > Protected environments, or use an account with the required " \
        "permissions.\nLearn more: #{docs_url}"
    end

    context 'when environment is protected at project level' do
      let!(:protected_environment) do
        create(:protected_environment, :project_level, name: environment.name, project: project)
      end

      it 'returns 403 with a descriptive message for a developer without deploy access' do
        put api("/projects/#{project.id}/environments/#{environment.id}", developer_no_access),
          params: { external_url: 'https://updated.example.com' }

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq(expected_protected_env_message)
      end

      it 'returns 200 for a developer with deploy access' do
        protected_environment.deploy_access_levels.create!(user: developer_with_access)

        put api("/projects/#{project.id}/environments/#{environment.id}", developer_with_access),
          params: { external_url: 'https://updated.example.com' }

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'returns 403 with a descriptive message for a maintainer without deploy access' do
        put api("/projects/#{project.id}/environments/#{environment.id}", maintainer_no_access),
          params: { external_url: 'https://updated.example.com' }

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq(expected_protected_env_message)
      end

      it 'returns 200 for a maintainer with deploy access' do
        protected_environment.deploy_access_levels.create!(user: maintainer_no_access)

        put api("/projects/#{project.id}/environments/#{environment.id}", maintainer_no_access),
          params: { external_url: 'https://updated.example.com' }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when environment is protected at group level' do
      let!(:protected_environment) do
        create(:protected_environment, :group_level, name: environment.tier, group: group)
      end

      it 'returns 403 with a descriptive message for a developer without deploy access' do
        put api("/projects/#{project.id}/environments/#{environment.id}", developer_no_access),
          params: { external_url: 'https://updated.example.com' }

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq(expected_protected_env_message)
      end

      it 'returns 200 for a developer with deploy access via group' do
        operator_group = create(:group)
        operator_group.add_developer(developer_with_access)
        protected_environment.deploy_access_levels.create!(group: operator_group)

        put api("/projects/#{project.id}/environments/#{environment.id}", developer_with_access),
          params: { external_url: 'https://updated.example.com' }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when protected_environments feature is unlicensed' do
      before do
        stub_licensed_features(protected_environments: false)
      end

      it 'returns 200 for a developer' do
        put api("/projects/#{project.id}/environments/#{environment.id}", developer_no_access),
          params: { external_url: 'https://updated.example.com' }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
