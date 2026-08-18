# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with admin_integrations custom role', feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:role) { create(:member_role, :guest, namespace: group, admin_integrations: true) }
  let_it_be(:membership) { create(:group_member, :guest, member_role: role, user: user, group: group) }

  before do
    stub_licensed_features(custom_roles: true)

    sign_in(user)
  end

  describe Groups::Settings::IntegrationsController do
    let_it_be(:jira_integration) { create(:jira_integration, :group, group: group) }

    describe '#index' do
      it 'user can access the page via a custom role' do
        get group_settings_integrations_path(group_id: group)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#edit' do
      it 'user can access the page via a custom role' do
        get edit_group_settings_integration_path(group_id: group, id: jira_integration.to_param)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#update' do
      include JiraIntegrationHelpers

      let(:params) { { url: 'https://jira.gitlab-example.com', password: 'password' } }

      before do
        stub_jira_integration_test
      end

      it 'user can access the page via a custom role' do
        put group_settings_integration_path(group_id: group, id: jira_integration.to_param, service: params)

        expect(response).to have_gitlab_http_status(:found)
      end
    end

    describe '#reset' do
      let_it_be(:inheriting_integration) { create(:jira_integration, inherit_from_id: jira_integration.id) }

      it 'user can access the page via a custom role' do
        post reset_group_settings_integration_path(group_id: group, id: jira_integration.to_param)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#test' do
      include JiraIntegrationHelpers

      before do
        stub_jira_integration_test
      end

      it 'user can access the page via a custom role' do
        put test_group_settings_integration_path(group_id: group, id: jira_integration.to_param)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe Projects::Settings::IntegrationsController do
    let_it_be(:jira_integration) { create(:jira_integration, project: project) }

    describe '#index' do
      it 'user can access the page via a custom role' do
        get namespace_project_settings_integrations_path(namespace_id: group, project_id: project)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#edit' do
      it 'user can access the page via a custom role' do
        get edit_namespace_project_settings_integration_path(namespace_id: group, project_id: project,
          id: jira_integration.to_param)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe '#update' do
      include JiraIntegrationHelpers

      let(:params) { { url: 'https://jira.gitlab-example.com', password: 'password' } }

      before do
        stub_jira_integration_test
      end

      it 'user can access the page via a custom role' do
        put namespace_project_settings_integration_path(namespace_id: group, project_id: project,
          id: jira_integration.to_param, service: params)

        expect(response).to have_gitlab_http_status(:found)
      end
    end

    describe '#test' do
      include JiraIntegrationHelpers

      before do
        stub_jira_integration_test
      end

      it 'user can access the page via a custom role' do
        put test_namespace_project_settings_integration_path(namespace_id: group, project_id: project,
          id: jira_integration.to_param)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe API::Integrations do
    include ApiHelpers

    let_it_be(:asana_integration) { create(:asana_integration, project: project) }

    describe 'GET /projects/:id/integrations' do
      it 'returns success for a user with custom role' do
        get api("/projects/#{project.id}/integrations", user)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe 'PUT /projects/:id/integrations/asana' do
      it 'returns success for a user with custom role' do
        put api("/projects/#{project.id}/integrations/asana", user), params: { api_key: 'key' }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    describe 'DELETE /projects/:id/integrations/asana' do
      it 'returns success for a user with custom role' do
        delete api("/projects/#{project.id}/integrations/asana", user)

        expect(response).to have_gitlab_http_status(:no_content)
      end
    end

    describe 'GET /projects/:id/integrations/asana' do
      it 'returns success for a user with custom role' do
        get api("/projects/#{project.id}/integrations/asana", user)

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
