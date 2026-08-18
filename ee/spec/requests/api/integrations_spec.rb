# frozen_string_literal: true

require 'spec_helper'

# FIXME: feature_category is fixed but this test covers integrations that
# are owned by different groups
RSpec.describe API::Integrations, feature_category: :not_owned do # rubocop:disable RSpec/FeatureCategory -- See above
  include Integrations::TestHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, namespace: user.namespace) }
  let_it_be(:project2) { create(:project, creator_id: user.id, namespace: user.namespace) }

  let_it_be(:available_integration_names) do
    Integration::EE_PROJECT_LEVEL_ONLY_INTEGRATION_NAMES.union(Integration::GOOGLE_CLOUD_PLATFORM_INTEGRATION_NAMES)
  end

  let_it_be_with_reload(:project_integrations_map) do
    available_integration_names.index_with do |name|
      create(integration_factory(name), :inactive, project: project)
    end
  end

  before do
    stub_saas_features(google_cloud_support: true)
  end

  shared_examples 'handling google artifact registry conditions' do |unavailable_status: :not_found|
    shared_examples 'does not change integrations count' do
      it do
        expect { subject }.not_to change { project.integrations.count }
      end
    end

    context 'when google artifact registry feature is unavailable' do
      before do
        stub_saas_features(google_cloud_support: false)
      end

      it_behaves_like 'returning response status', unavailable_status
      it_behaves_like 'does not change integrations count'
    end
  end

  shared_examples 'observes allow list settings' do |allowed_status:, blocked_status:|
    def stub_allow_list_license(allowed:)
      licensed_features = { integrations_allow_list: allowed }
      licensed_features[:github_integration] = true if integration == 'github'

      stub_licensed_features(licensed_features)
    end

    context 'when application settings do not allow all integrations' do
      before do
        stub_allow_list_license(allowed: true)
        stub_application_setting(allow_all_integrations: false)
      end

      it "returns #{blocked_status}" do
        request

        expect(response).to have_gitlab_http_status(blocked_status)
      end

      context 'when integration is in allowlist' do
        before do
          stub_application_setting(allowed_integrations: [integration])
        end

        it "returns #{allowed_status}" do
          request

          expect(response).to have_gitlab_http_status(allowed_status)
        end
      end

      context 'when license is insufficient' do
        before do
          stub_allow_list_license(allowed: false)
        end

        it "returns #{allowed_status}" do
          request

          expect(response).to have_gitlab_http_status(allowed_status)
        end
      end
    end
  end

  %w[integrations services].each do |endpoint|
    where(:integration) do
      Integration::EE_PROJECT_LEVEL_ONLY_INTEGRATION_NAMES.union(Integration::GOOGLE_CLOUD_PLATFORM_INTEGRATION_NAMES)
    end

    with_them do
      integration = params[:integration]

      describe "PUT /projects/:id/#{endpoint}/#{integration.dasherize}" do
        it_behaves_like 'set up an integration', endpoint: endpoint, integration: integration,
          parent_resource_name: 'project' do
          let(:parent_resource) { project }
          let(:integrations_map) { project_integrations_map }

          it_behaves_like 'observes allow list settings', allowed_status: :ok, blocked_status: :bad_request
        end
      end

      describe "DELETE /projects/:id/#{endpoint}/#{integration.dasherize}" do
        it_behaves_like 'disable an integration', endpoint: endpoint, integration: integration,
          parent_resource_name: 'project' do
          let(:parent_resource) { project }
          let(:integrations_map) { project_integrations_map }

          it_behaves_like 'observes allow list settings', allowed_status: :no_content, blocked_status: :not_found
        end
      end

      describe "GET /projects/:id/#{endpoint}/#{integration.dasherize}" do
        it_behaves_like 'get an integration settings', endpoint: endpoint, integration: integration,
          parent_resource_name: 'project' do
          let(:parent_resource) { project }
          let(:integrations_map) { project_integrations_map }

          it_behaves_like 'observes allow list settings', allowed_status: :ok, blocked_status: :not_found
        end
      end
    end
  end

  describe 'POST /slack/trigger' do
    before do
      stub_application_setting(slack_app_verification_token: 'token')
    end

    let(:integration) { ::Integrations::GitlabSlackApplication.to_param }

    subject(:request) { post api('/slack/trigger'), params: { token: 'token', text: 'help' } }

    it_behaves_like 'observes allow list settings', allowed_status: :ok, blocked_status: :not_found
  end

  describe 'POST /projects/:id/integrations/mattermost_slash_commands/trigger' do
    before_all do
      create(:mattermost_slash_commands_integration, project: project)
    end

    let(:integration) { ::Integrations::MattermostSlashCommands.to_param }

    let(:params) { { token: 'secrettoken', text: 'help' } }

    subject(:request) { post api("/projects/#{project.id}/integrations/#{integration}/trigger"), params: params }

    it_behaves_like 'observes allow list settings', allowed_status: :ok, blocked_status: :not_found
  end

  describe 'Google Artifact Registry' do
    shared_examples 'handling google artifact registry conditions' do |unavailable_status: :not_found|
      shared_examples 'does not change integrations count' do
        it do
          expect { subject }.not_to change { project.integrations.count }
        end
      end

      context 'when google artifact registry feature is unavailable' do
        before do
          stub_saas_features(google_cloud_support: false)
        end

        it_behaves_like 'returning response status', unavailable_status
        it_behaves_like 'does not change integrations count'
      end
    end

    describe 'PUT /projects/:id/integrations/google-cloud-platform-artifact-registry' do
      let(:params) do
        {
          workload_identity_pool_project_number: '917659427920',
          workload_identity_pool_id: 'gitlab-gcp-demo',
          workload_identity_pool_provider_id: 'gitlab-gcp-prod-gitlab-org',
          artifact_registry_project_id: 'dev-gcp-9abafed1',
          artifact_registry_location: 'us-east1',
          artifact_registry_repositories: 'demo'
        }
      end

      let(:url) { api("/projects/#{project.id}/integrations/google-cloud-platform-artifact-registry", user) }

      it_behaves_like 'handling google artifact registry conditions', unavailable_status: :bad_request do
        subject { put url, params: params }
      end
    end

    describe 'DELETE /projects/:id/integrations/google-cloud-platform-artifact-registry' do
      let(:url) { api("/projects/#{project.id}/integrations/google-cloud-platform-artifact-registry", user) }

      before do
        project_integrations_map['google_cloud_platform_artifact_registry'].activate!
      end

      it_behaves_like 'handling google artifact registry conditions' do
        subject { delete url }
      end
    end

    describe 'GET /projects/:id/integrations/google-cloud-platform-artifact-registry' do
      let(:url) { api("/projects/#{project.id}/integrations/google-cloud-platform-artifact-registry", user) }

      before do
        project_integrations_map['google_cloud_platform_artifact_registry'].activate!
      end

      it_behaves_like 'handling google artifact registry conditions' do
        subject { get url }
      end
    end
  end

  context 'when Google Cloud Workload Identity Federation integration feature is unavailable' do
    let(:url) { api("/projects/#{project.id}/integrations/google-cloud-platform-workload-identity-federation", user) }

    before do
      project_integrations_map['google_cloud_platform_workload_identity_federation'].activate!
      stub_saas_features(google_cloud_support: false)
    end

    describe 'GET /projects/:id/integrations/google-cloud-workload-identity-federation' do
      it_behaves_like 'returning response status', :not_found do
        subject { get url }
      end
    end

    describe 'PUT /projects/:id/integrations/google-cloud-workload-identity-federation' do
      let(:params) do
        {
          workload_identity_federation_project_id: 'google-wlif-project-id',
          workload_identity_federation_project_number: '123456789',
          workload_identity_pool_id: 'wlif-pool-id',
          workload_identity_pool_provider_id: 'wlif-pool-provider-id'
        }
      end

      it_behaves_like 'returning response status', :bad_request do
        subject { put url, params: params }
      end
    end

    describe 'DELETE /projects/:id/integrations/google-cloud-workload-identity-federation' do
      it_behaves_like 'returning response status', :not_found do
        subject { delete url }
      end
    end
  end
end
