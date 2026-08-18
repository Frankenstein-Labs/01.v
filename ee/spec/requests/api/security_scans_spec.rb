# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::SecurityScans, feature_category: :static_application_security_testing do
  include WorkhorseHelpers

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:user) { create(:user, developer_of: [project]) }

  let_it_be(:pats) do
    {
      api: create(:personal_access_token, scopes: %w[api], user: user),
      read_api: create(:personal_access_token, scopes: %w[read_api], user: user),
      no_read_api: create(:personal_access_token, scopes: %w[read_repository], user: user)
    }
  end

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?).with(user, :access_security_scans_api, project)
                                        .and_return(access_security_scans_api)
  end

  shared_examples 'a response' do |case_name|
    it "returns #{case_name} response", :freeze_time, :aggregate_failures do
      post_api

      expect(response).to have_gitlab_http_status(result)

      expect(json_response).to include(**response_body)
    end
  end

  shared_examples 'an unauthorized response' do
    include_examples 'a response', 'unauthorized' do
      let(:result) { :unauthorized }
      let(:response_body) do
        { "message" => "401 Unauthorized" }
      end
    end
  end

  describe 'POST /projects/:id/security_scans/sast/scan' do
    let_it_be(:jwt) { 'generated-jwt' }
    let(:headers) do
      {
        'X-Gitlab-Authentication-Type' => 'oidc',
        'X-Gitlab-Oidc-Token' => jwt,
        'Content-Type' => 'application/json',
        'User-Agent' => 'Super Awesome Browser 43.144.12'
      }
    end

    let(:file_path) { 'scripts/test.py' }
    let(:content) do
      <<~CONTENT
        def add(x, y):
          return x + y

        def sub(x, y):
          return x - y

        def multiple(x, y):
          return x * y

        def divide(x, y):
          return x / y
      CONTENT
    end

    let(:body) do
      {
        file_path: file_path,
        content: content
      }
    end

    subject(:post_api) do
      post api("/projects/#{project.id}/security_scans/sast/scan", current_user),
        headers: headers, params: body.to_json
    end

    before do
      allow(::CloudConnector::Tokens).to receive(:get).with(
        unit_primitive: :security_scans,
        resource: project
      ).and_return(jwt)
    end

    context 'when user can access the security scan api for the project' do
      let(:current_user) { user }
      let(:access_security_scans_api) { true }

      it_behaves_like 'authorizing granular token permissions', :create_security_scan do
        let(:boundary_object) { project }
        let(:request) do
          post api("/projects/#{project.id}/security_scans/sast/scan", personal_access_token: pat),
            headers: headers, params: body.to_json
        end
      end

      it 'sends request to the security scan endpoint' do
        expected_body = body.merge(
          project_id: project.id
        )
        expect(Gitlab::Workhorse)
          .to receive(:send_url)
          .with(
            'https://cloud.gitlab.com/sast/scan',
            hash_including(body: expected_body.to_json)
          )

        post_api
      end
    end

    context 'when user is not logged in' do
      let(:current_user) { nil }
      let(:access_security_scans_api) { true }

      include_examples 'an unauthorized response'
    end

    context 'when user does not have access to security scans' do
      let(:current_user) { user }
      let(:access_security_scans_api) { false }

      include_examples 'an unauthorized response'
    end

    context 'when user is logged in' do
      let(:current_user) { user }
      let(:access_security_scans_api) { true }

      it 'delegates downstream service call to Workhorse with correct JWT' do
        post_api

        expected_body = body.merge(
          project_id: project.id
        )
        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to eq("".to_json)
        command, params = workhorse_send_data
        expect(command).to eq('send-url')
        expect(params).to include(
          'URL' => 'https://cloud.gitlab.com/sast/scan',
          'AllowRedirects' => false,
          'Body' => expected_body.to_json,
          'Method' => 'POST',
          'ResponseHeaderTimeout' => '55s'
        )
        expect(params['Header']).to include(
          'x-gitlab-host-name' => [Gitlab.config.gitlab.host],
          'Authorization' => ["Bearer #{jwt}"],
          'Content-Type' => ['application/json'],
          'User-Agent' => ['Super Awesome Browser 43.144.12']
        )
      end
    end

    context 'when authenticated with token' do
      let(:current_user) { nil }
      let(:pat) { pats[:api] }
      let(:access_security_scans_api) { true }

      before do
        headers["Authorization"] = "Bearer #{pat.token}"

        post_api
      end

      context 'when using token with :api scope' do
        it { expect(response).to have_gitlab_http_status(:ok) }
      end

      context 'when using token with :read_api scope' do
        let(:pat) { pats[:read_api] }

        it { expect(response).to have_gitlab_http_status(:ok) }
      end

      context 'when using token without :read_api scope' do
        let(:pat) { pats[:no_read_api] }

        it { expect(response).to have_gitlab_http_status(:forbidden) }
      end

      context 'when using token with :read_api scope but for a user without access' do
        let(:pat) { pats[:read_api] }
        let(:access_security_scans_api) { false }

        it { expect(response).to have_gitlab_http_status(:unauthorized) }
      end
    end

    context 'without Workhorse JWT', :verify_workhorse_jwt do
      let(:current_user) { user }
      let(:access_security_scans_api) { true }

      it 'returns 403 forbidden' do
        post_api

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
