# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::CodeSuggestionsClient, feature_category: :code_suggestions do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:self_hosted_model) { create(:ai_self_hosted_model) }

  let(:unit_primitive) { :complete_code }
  let(:ai_gateway_headers) { { 'header' => 'value' } }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response, namespace_ids: [1, 2], enablement_type: 'add_on')
  end

  let(:cloud_connector_auth_endpoint_url) do
    "#{Gitlab::AiGateway.cloud_connector_auth_url}#{Gitlab::AiGateway::ACCESS_TOKEN_PATH}"
  end

  let(:self_hosted_auth_endpoint_url) { "#{Gitlab::AiGateway.self_hosted_url}#{Gitlab::AiGateway::ACCESS_TOKEN_PATH}" }

  let(:expected_ai_feature) { :code_suggestions }

  let(:body) { { choices: [{ text: "puts \"Hello World!\"\nend", index: 0, finish_reason: "length" }] } }
  let(:code) { 200 }
  let(:cloud_connector_code_suggestions_url) { 'https://cloud-connector.gitlab.com/v4/code/suggestions' }
  let(:feature_setting) { nil }
  let(:organization_id) { user.governing_namespace&.organization_id }
  let(:governing_namespace_id) { user.governing_namespace&.id }

  before do
    allow(user).to receive_messages(governing_namespace: group, allowed_to_use: auth_response)
    allow(Gitlab::AiGateway).to receive_messages(
      self_hosted_url: 'http://local-aigw:5052',
      cloud_connector_url: 'https://cloud-connector.gitlab.com',
      cloud_connector_auth_url: 'https://cloud-connector.gitlab.com/auth'
    )
    allow(Gitlab::AiGateway).to receive(:headers).with(
      user: user, unit_primitive_name: unit_primitive, ai_feature_name: expected_ai_feature,
      namespace_id: nil, project_id: nil, governing_namespace_id: governing_namespace_id,
      organization_id: organization_id, feature_setting: feature_setting
    ).and_return(ai_gateway_headers)
  end

  shared_examples "error response" do |message|
    it "returns an error" do
      expect(result).to eq(message)
    end
  end

  shared_context 'with completions' do
    context 'when response does not contain a valid choice' do
      let(:body) { { choices: [] } }

      it_behaves_like 'error response', "Response doesn't contain a completion"
    end
  end

  shared_context 'with tests requests' do
    before do
      [
        cloud_connector_code_suggestions_url,
        /#{Gitlab::AiGateway.url}/
      ].each do |url|
        stub_request(:post, url).to_return(
          status: code,
          body: body.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end
    end

    it 'returns nil if there is no error' do
      expect(result).to be_nil
    end

    context 'when request raises an error' do
      before do
        [
          cloud_connector_code_suggestions_url,
          /#{Gitlab::AiGateway.url}/
        ].each do |url|
          stub_request(:post, url).to_raise(StandardError.new('an error'))
        end
      end

      it 'tracks an exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(StandardError))

        result
      end

      it_behaves_like 'error response', 'an error'
    end
  end

  describe "#test_completion" do
    subject(:result) { described_class.new(user).test_completion }

    include_examples 'with tests requests' do
      include_examples 'with completions'
    end

    context 'when response code is not 200' do
      let(:code) { 401 }
      let(:body) { 'an error' }

      it_behaves_like 'error response', 'AI Gateway returned code 401: "an error"'
    end

    context 'when governing_namespace is nil' do
      let(:organization_id) { nil }
      let(:governing_namespace_id) { nil }

      before do
        allow(user).to receive(:governing_namespace).and_return(nil)
      end

      include_context 'with tests requests'
    end

    context 'when the v4 code completion endpoint is enabled' do
      before do
        stub_feature_flags(code_completion_v4_endpoint: true)
        stub_request(:post, /#{Gitlab::AiGateway.url}/).to_return(
          status: 200,
          body: body.to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it 'sends the test content in the v4 prompt_components payload' do
        result

        expect(
          a_request(:post, %r{/v4/code/suggestions}).with do |req|
            payload = ::Gitlab::Json.safe_parse(req.body).dig('prompt_components', 0, 'payload')
            payload['content_above_cursor'] == 'def hello_world' && payload['file_name'] == 'test.rb'
          end
        ).to have_been_made
      end
    end
  end

  describe '#direct_access_token', :with_cloud_connector do
    include StubRequests

    let(:expected_token) { 'user token' }
    let(:expires_at) { 1.hour.from_now.to_i }
    let(:expected_response) { { token: expected_token, expires_at: expires_at } }
    let(:response_body) { expected_response.to_json }
    let(:http_status) { 200 }
    let(:client) { described_class.new(user) }

    let(:auth_url) { self_hosted_auth_endpoint_url }

    let(:feature_setting) do
      create(:ai_feature_setting, :code_completions, provider: :self_hosted, self_hosted_model: self_hosted_model)
    end

    subject(:result) { client.direct_access_token }

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

    it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }

    context 'when code_completions is vendored' do
      let(:feature_setting) { create(:ai_feature_setting, :code_completions, provider: :vendored) }

      let(:auth_url) { cloud_connector_auth_endpoint_url }

      it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }

      context 'when the code_suggestions_direct_access_cloud_connected feature flag is disabled' do
        before do
          stub_feature_flags(code_suggestions_direct_access_cloud_connected: false)
        end

        it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }
      end

      context 'when there is no self-hosted AI Gateway' do
        before do
          allow(Gitlab::AiGateway).to receive(:self_hosted_url).and_return(nil)
        end

        it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }
      end
    end

    context 'when code_completions is self-hosted' do
      let(:expected_ai_feature) { :code_suggestions }

      it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }

      context 'when the code_suggestions_direct_access_cloud_connected feature flag is disabled' do
        before do
          stub_feature_flags(code_suggestions_direct_access_cloud_connected: false)
        end

        it { is_expected.to match({ status: :success, token: expected_token, expires_at: expires_at }) }
      end
    end

    context 'when minting the token on SaaS' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)

        allow(Gitlab::AiGateway).to receive(:headers).and_call_original

        stub_request(:post, auth_url).to_return(
          status: http_status,
          body: response_body,
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'includes gitlab_root_namespace_id in the CloudConnector extra claims' do
        expect(::CloudConnector::Tokens)
          .to receive(:get)
          .with(hash_including(extra_claims: hash_including(gitlab_root_namespace_id: group.id)))
          .and_return('instance jwt')

        expect(result).to match(a_hash_including(status: :success))
      end
    end

    context 'when a project is given' do
      let_it_be(:project) { create(:project, group: group) }

      let(:client) { described_class.new(user, project: project) }

      before do
        allow(Gitlab::AiGateway).to receive(:headers).with(
          user: user, unit_primitive_name: unit_primitive, ai_feature_name: expected_ai_feature,
          namespace_id: project.namespace_id, project_id: project.id, governing_namespace_id: group.id,
          organization_id: group.organization_id, feature_setting: feature_setting
        ).and_return(ai_gateway_headers)
      end

      it 'sends the namespace context to the AI Gateway', :aggregate_failures do
        expect(result).to match({ status: :success, token: expected_token, expires_at: expires_at })

        expect(Gitlab::AiGateway).to have_received(:headers).with(
          hash_including(
            namespace_id: project.namespace_id,
            project_id: project.id,
            governing_namespace_id: group.id
          )
        )
      end
    end

    context 'when there is no self-hosted AI Gateway and no feature setting' do
      let(:feature_setting) { nil }

      let(:auth_url) { cloud_connector_auth_endpoint_url }

      before do
        allow(Gitlab::AiGateway).to receive(:self_hosted_url).and_return(nil)
      end

      it 'issues a token through the cloud connector', :aggregate_failures do
        expect(result).to match({ status: :success, token: expected_token, expires_at: expires_at })

        expect(a_request(:post, cloud_connector_auth_endpoint_url)).to have_been_made
      end

      context 'when the code_suggestions_direct_access_cloud_connected feature flag is disabled' do
        before do
          stub_feature_flags(code_suggestions_direct_access_cloud_connected: false)
        end

        it 'returns an error and does not request a token', :aggregate_failures do
          expect(result).to match(
            status: :error,
            message: 'Code Completion direct access is not yet available',
            context: {
              response_code: 400,
              error: 'Direct connections are not enabled for this instance yet. ' \
                'Code completion uses the standard connection instead.'
            }
          )

          expect(a_request(:post, cloud_connector_auth_endpoint_url)).not_to have_been_made
        end
      end
    end

    context 'when no model is pinned for code_completions feature setting' do
      let(:http_status) { 400 }
      let(:error_message) do
        'Please, assign a model to the ' \
          '"Code completion" feature settings in your duo settings'
      end

      let(:response_body) { { detail: error_message }.to_json }

      let(:feature_setting) { nil }

      it { is_expected.to match(a_hash_including(status: :error)) }

      it 'includes error context in the response' do
        expect(result).to match(
          status: :error,
          message: 'No Code Completion model provided',
          context: {
            response_code: 400,
            error: error_message
          }
        )
      end
    end

    context 'when the code_completions provider is unassigned' do
      let(:feature_setting) { create(:ai_feature_setting, :code_completions, provider: :unassigned) }

      it 'returns an error and does not request a token', :aggregate_failures do
        expect(result).to match(
          status: :error,
          message: 'No Code Completion model provided',
          context: {
            response_code: 400,
            error: 'Please, assign a model to the ' \
              '"Code completion" feature settings in your duo settings'
          }
        )

        expect(a_request(:post, auth_url)).not_to have_been_made
      end
    end

    context 'when direct access token creation request fails' do
      let(:http_status) { 401 }
      let(:error_message) { 'No authorization header presented' }
      let(:response_body) { { detail: error_message }.to_json }

      it { is_expected.to match(a_hash_including(status: :error)) }

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          satisfy { |exception, _extra|
            exception.is_a?(described_class::AiGatewayError) &&
              exception.message == 'Token creation failed'
          },
          {
            response_code: 401,
            detail: error_message
          }
        )

        result
      end

      it 'includes error context in the response' do
        expect(result).to match(
          status: :error,
          message: 'Token creation failed',
          context: {
            response_code: 401,
            detail: error_message
          }
        )
      end
    end

    context 'when token is not included in response' do
      let(:response_body) { { foo: :bar }.to_json }

      it { is_expected.to match(a_hash_including(status: :error)) }

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          satisfy { |exception|
            exception.is_a?(described_class::AiGatewayError) &&
              exception.message == 'Token is missing in response'
          },
          {
            response_code: 200
          }
        )

        result
      end

      it 'includes error context in the response' do
        expect(result).to match(
          status: :error,
          message: 'Token is missing in response',
          context: {
            response_code: 200
          }
        )
      end
    end

    context 'when returning a string error' do
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

      it { is_expected.to match(a_hash_including(status: :error)) }

      it 'logs the error' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          satisfy { |exception|
            exception.is_a?(described_class::AiGatewayError) &&
              exception.message == 'Token creation failed'
          },
          {
            response_code: 503,
            detail: 'Service Unavailable'
          }
        )

        result
      end

      it 'includes error context in the response' do
        expect(result).to match(
          status: :error,
          message: 'Token creation failed',
          context: {
            response_code: 503,
            detail: 'Service Unavailable'
          }
        )
      end
    end

    context 'when response includes structured error fields' do
      let(:http_status) { 402 }
      let(:error_code) { 'quota_exceeded' }
      let(:response_body) do
        {
          detail: 'Payment required',
          error: 'usage_limit_error',
          error_code: error_code,
          message: 'Usage quota has been exceeded'
        }.to_json
      end

      it 'includes all error fields in the response context' do
        expect(result).to match(
          status: :error,
          message: 'Token creation failed',
          context: {
            response_code: 402,
            detail: 'Payment required',
            error: 'usage_limit_error',
            error_code: error_code,
            message: 'Usage quota has been exceeded'
          }
        )
      end
    end

    context 'when response is nil' do
      before do
        allow(Gitlab::HTTP).to receive(:post).and_return(nil)
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:direct_access_token).and_call_original
        end
      end

      it 'handles nil response gracefully' do
        expect { result }.to raise_error(NoMethodError)
      end
    end

    context 'when response.parsed_response does not respond to dig' do
      let(:http_status) { 500 }

      before do
        stub_request(:post, auth_url)
          .to_return(
            status: http_status,
            body: 'Internal Server Error',
            headers: { 'Content-Type' => 'text/plain' }
          )
      end

      it 'includes only response_code and detail in context' do
        expect(result).to match(
          status: :error,
          message: 'Token creation failed',
          context: {
            response_code: 500,
            detail: 'Internal Server Error'
          }
        )
      end
    end

    context 'when response.parsed_response.dig returns nil values' do
      let(:http_status) { 400 }
      let(:response_body) { {}.to_json }

      it 'includes only response_code in context' do
        expect(result).to match(
          status: :error,
          message: 'Token creation failed',
          context: {
            response_code: 400
          }
        )
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
end
