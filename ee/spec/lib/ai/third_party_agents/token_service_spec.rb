# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ThirdPartyAgents::TokenService, :with_current_organization, feature_category: :duo_agent_platform do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:governing_namespace) { nil }
  let(:ai_gateway_headers) { { 'header' => 'value' } }

  let(:public_headers) do
    {
      'x-gitlab-unit-primitive' => 'ai_gateway_model_provider_proxy',
      'x-gitlab-authentication-type' => 'oidc'
    }.tap do |h|
      h['x-gitlab-project-id'] = project.id.to_s if project
      h['x-gitlab-organization-id'] = current_organization.id.to_s if current_organization
      h['x-gitlab-root-namespace-id'] = governing_namespace&.id if governing_namespace&.id
    end
  end

  let(:token_scopes) { %w[complete_code ai_gateway_model_provider_proxy] }
  let(:expected_token) do
    header = Base64.urlsafe_encode64('{"alg":"none","typ":"JWT"}', padding: false)
    body = Base64.urlsafe_encode64({ scopes: token_scopes }.to_json, padding: false)
    "#{header}.#{body}."
  end

  let(:expires_at) { 1.hour.from_now.to_i }
  let(:response_body) { { token: expected_token, expires_at: expires_at }.to_json }
  let(:http_status) { 200 }
  let(:auth_url) { "#{Gitlab::AiGateway.url}#{Gitlab::AiGateway::ACCESS_TOKEN_PATH}" }

  subject(:token_service) do
    described_class.new(current_user: user, project: project, organization: current_organization)
  end

  before do
    allow(user).to receive(:governing_namespace).with(project).and_return(governing_namespace)
    allow(Gitlab::AiGateway).to receive(:headers)
      .with(user: user, unit_primitive_name: :ai_gateway_model_provider_proxy, namespace_id: project&.namespace_id,
        project_id: project&.id, organization_id: current_organization&.id,
        governing_namespace_id: governing_namespace&.id, ai_feature_name: :duo_workflow)
      .and_return(ai_gateway_headers)

    allow(Gitlab::AiGateway).to receive(:public_headers)
      .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :ai_gateway_model_provider_proxy,
        namespace_id: project&.namespace_id, project_id: project&.id,
        organization_id: current_organization&.id, governing_namespace_id: governing_namespace&.id)
      .and_return(public_headers)

    allow(Gitlab::AiGateway).to receive(:access_token_url)
      .with(nil)
      .and_return(auth_url)

    stub_request(:post, auth_url)
      .with(
        body: nil,
        headers: ai_gateway_headers
      )
      .to_return(
        status: http_status,
        body: response_body,
        headers: { 'Content-Type' => 'application/json' }
      )
  end

  describe '#direct_access_token' do
    subject(:result) { token_service.direct_access_token }

    it 'returns a successful service response with the token information' do
      expect(result).to be_success
      expect(result.payload).to include(
        headers: public_headers,
        token: expected_token,
        expires_at: expires_at
      )
    end

    it 'logs the token creation' do
      expect(token_service).to receive(:log_info).with(
        message: 'Creating user access token',
        event_name: 'user_token_created',
        ai_component: 'third_party_agents'
      )

      result
    end

    context 'when auditing the token creation' do
      it 'creates an audit event on successful token generation' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'third_party_agent_token_created',
            author: user,
            scope: user,
            target: user,
            message: "Generated third-party agent access token"
          )
        )

        result
      end

      it 'includes expiration, scope, organization and project details in additional_details' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            additional_details: hash_including(
              token_expires_at: expires_at,
              token_scopes: token_scopes,
              project_id: project.id,
              namespace_id: project.namespace_id,
              organization_id: current_organization.id
            )
          )
        )

        result
      end

      context 'when JWT decoding fails' do
        before do
          allow(JWT).to receive(:decode).and_raise(JWT::DecodeError)
        end

        it 'still returns a successful response' do
          expect(result).to be_success
        end

        it 'audits without token_scopes' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              additional_details: hash_excluding(:token_scopes)
            )
          )

          result
        end
      end

      context 'when token creation fails' do
        let(:http_status) { 401 }
        let(:response_body) { { detail: 'Unauthorized' }.to_json }

        it 'does not create an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          result
        end
      end

      context 'when agent_name and workflow_id are provided' do
        subject(:token_service) do
          described_class.new(
            current_user: user,
            project: project,
            organization: current_organization,
            agent_name: 'Amazon Q Developer Agent',
            workflow_id: 42
          )
        end

        it 'includes agent_name and workflow_id in additional_details' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              additional_details: hash_including(
                agent_name: 'Amazon Q Developer Agent',
                workflow_id: 42
              )
            )
          )

          result
        end
      end

      context 'without a project' do
        let(:project) { nil }

        subject(:token_service) do
          described_class.new(
            current_user: user,
            project: nil,
            organization: current_organization
          )
        end

        before do
          stub_request(:post, auth_url)
            .with(
              body: nil,
              headers: ai_gateway_headers
            )
            .to_return(
              status: http_status,
              body: response_body,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'creates an audit event without project details' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'third_party_agent_token_created',
              additional_details: hash_including(
                organization_id: current_organization.id,
                token_expires_at: expires_at,
                token_scopes: token_scopes
              )
            )
          )

          result
        end
      end
    end

    context 'when direct access token creation request fails' do
      let(:http_status) { 401 }
      let(:error_message) { 'No authorization header presented' }
      let(:response_body) { { detail: error_message }.to_json }

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to eq('Token creation failed')
      end

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(described_class::DirectAccessError),
          { ai_gateway_response_code: 401, ai_gateway_error_detail: error_message }
        )

        result
      end
    end

    context 'when token is not included in response' do
      let(:response_body) { { foo: :bar }.to_json }

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to eq('Token is missing in response')
      end

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(described_class::DirectAccessError),
          { ai_gateway_response_code: 200 }
        )

        result
      end
    end

    context 'when returning a server error' do
      let(:http_status) { 503 }

      before do
        stub_request(:post, auth_url)
          .with(
            body: nil,
            headers: ai_gateway_headers
          )
          .to_return(
            status: http_status,
            body: 'Service Unavailable',
            headers: { 'Content-Type' => 'text/plain' }
          )
      end

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to eq('Token creation failed')
      end

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(described_class::DirectAccessError),
          { ai_gateway_response_code: 503, ai_gateway_error_detail: 'Service Unavailable' }
        )

        result
      end
    end

    context 'when HTTP request raises an HTTP error' do
      Gitlab::HTTP::HTTP_ERRORS.each do |error_class|
        context "when #{error_class} is raised" do
          before do
            allow(Gitlab::HTTP).to receive(:post).and_raise(error_class.new('connection failed'))
          end

          it 'returns an error response and tracks the exception' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(error_class),
              {
                agent_name: nil,
                workflow_id: nil,
                project_id: project.id,
                namespace_id: project.namespace_id
              }
            )
            expect(result).to be_error
            expect(result.message).to eq('An HTTP error occurred when creating a Direct Access Token.')
          end
        end
      end

      context 'when project is nil' do
        let(:project) { nil }

        before do
          allow(Gitlab::HTTP).to receive(:post).and_raise(Net::ReadTimeout.new('connection failed'))
        end

        it 'returns an error response with nil project details' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(Net::ReadTimeout),
            {
              agent_name: nil,
              workflow_id: nil,
              project_id: nil,
              namespace_id: nil
            }
          )
          expect(result).to be_error
        end
      end
    end

    describe 'token inquiry timeout' do
      it 'uses TOKEN_TIMEOUT (3 seconds)' do
        expect(Gitlab::HTTP).to receive(:post).with(
          auth_url,
          hash_including(timeout: described_class::TOKEN_TIMEOUT)
        ).and_call_original

        result
      end
    end
  end

  describe 'creating AI gateway headers' do
    it 'uses the current user for public headers' do
      expect(Gitlab::AiGateway).to receive(:public_headers)
        .with(user: user, ai_feature_name: :duo_workflow, unit_primitive_name: :ai_gateway_model_provider_proxy,
          namespace_id: project.namespace_id, governing_namespace_id: governing_namespace&.id,
          project_id: project.id, organization_id: current_organization.id)
        .and_return(public_headers)

      token_service.direct_access_token
    end

    it 'includes the required headers' do
      expect(token_service.direct_access_token.payload[:headers]).to include(public_headers)
    end

    context 'without a project' do
      let(:project) { nil }

      before do
        stub_request(:post, auth_url)
          .with(
            body: nil,
            headers: ai_gateway_headers
          )
          .to_return(
            status: http_status,
            body: response_body,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      context 'with Duo SaaS-only features disabled' do
        before do
          stub_saas_features(gitlab_duo_saas_only: false)
        end

        it 'does not include the required headers' do
          expect(token_service.direct_access_token.payload[:headers].keys).not_to include(
            'x-gitlab-project-id', 'x-gitlab-namespace-id', 'x-gitlab-root-namespace-id'
          )
        end
      end

      context 'with Duo SaaS-only features enabled' do
        subject(:result) { token_service.direct_access_token }

        before do
          stub_saas_features(gitlab_duo_saas_only: true)
        end

        context 'with no default Duo namespace' do
          let(:governing_namespace) { nil }

          it 'fails fast when a user without a namespace preference selected' do
            expect(result).to be_error
            expect(result.message).to eq('Missing default GitLab Duo namespace user preference')
          end
        end

        context 'with default Duo namespace' do
          let(:governing_namespace) { group }

          before_all do
            group.add_developer(user)
          end

          it 'issues a direct access token' do
            expect(result).to be_success
            expect(result.payload).to include(
              headers: public_headers,
              token: expected_token,
              expires_at: expires_at
            )
          end
        end
      end
    end

    context 'when organization_id is nil' do
      let(:current_organization) { nil }

      before do
        allow(Gitlab::AiGateway).to receive(:headers)
          .with(user: user, unit_primitive_name: :ai_gateway_model_provider_proxy,
            namespace_id: project.namespace_id, project_id: project.id,
            organization_id: nil, governing_namespace_id: governing_namespace&.id,
            ai_feature_name: :duo_workflow)
          .and_return(ai_gateway_headers)

        allow(Gitlab::AiGateway).to receive(:public_headers)
          .with(user: user, unit_primitive_name: :ai_gateway_model_provider_proxy,
            namespace_id: project.namespace_id, project_id: project.id,
            organization_id: nil, governing_namespace_id: governing_namespace&.id,
            ai_feature_name: :duo_workflow)
          .and_return(public_headers)
      end

      it 'returns a successful response' do
        result = token_service.direct_access_token

        expect(result).to be_success
        expect(result.payload[:headers]).not_to have_key('x-gitlab-organization-id')
      end
    end
  end
end
