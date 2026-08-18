# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Client, feature_category: :ai_abstraction_layer do
  include StubRequests

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:active_token) { create(:service_access_token, :active) }

  let(:expected_body) { { prompt: 'anything' } }
  let(:timeout) { Gitlab::AiGateway.timeout }
  let(:service) { instance_double(CloudConnector::BaseAvailableServiceData, name: :test) }
  let(:enabled_by_namespace_ids) { [1, 2] }
  let(:enablement_type) { 'add_on' }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response,
      namespace_ids: enabled_by_namespace_ids, enablement_type: enablement_type)
  end

  let(:expected_access_token) { active_token.token }
  let(:expected_gitlab_realm) { ::CloudConnector::GITLAB_REALM_SELF_MANAGED }
  let(:expected_gitlab_host_name) { Gitlab.config.gitlab.host }
  let(:expected_instance_id) { Gitlab::GlobalAnonymousId.instance_id }
  let(:expected_user_id) { Gitlab::GlobalAnonymousId.user_id(user) }
  let(:expected_request_headers) do
    {
      'X-Gitlab-Instance-Id' => expected_instance_id,
      'X-Gitlab-Global-User-Id' => expected_user_id,
      'X-Gitlab-Host-Name' => expected_gitlab_host_name,
      'X-Gitlab-Realm' => expected_gitlab_realm,
      'X-Gitlab-Authentication-Type' => 'oidc',
      'Authorization' => "Bearer #{expected_access_token}",
      "X-Gitlab-Feature-Enabled-By-Namespace-Ids" => [enabled_by_namespace_ids.join(',')],
      'X-Gitlab-Subject-Type' => 'human',
      'X-Gitlab-Feature-Enablement-Type' => enablement_type,
      'Content-Type' => 'application/json',
      'X-Request-ID' => Labkit::Correlation::CorrelationId.current_or_new_id
    }
  end

  let(:expected_response) { { "response" => "Response" } }
  let(:endpoint) { '/v1/test' }
  let(:url) { "#{::Gitlab::AiGateway.url}#{endpoint}" }
  let(:tracking_context) { { request_id: 'uuid', action: 'test' } }
  let(:response_body) { expected_response.to_json }
  let(:http_status) { 200 }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }
  let(:logger) { instance_double('Gitlab::Llm::Logger') }

  before do
    allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
    allow(logger).to receive(:conditional_info)
    allow(logger).to receive(:info)

    stub_request(:post, url)
      .with(
        body: expected_body,
        headers: expected_request_headers
      )
      .to_return(
        status: http_status,
        body: response_body,
        headers: response_headers
      )

    allow(user).to receive(:allowed_to_use).and_return(auth_response)
    allow(Namespace).to receive(:root_ids_for).with(enabled_by_namespace_ids).and_return(enabled_by_namespace_ids)
  end

  subject(:ai_client) do
    described_class.new(user, unit_primitive_name: :test, tracking_context: tracking_context)
  end

  describe '#complete' do
    subject(:complete) { ai_client.complete(url: url, body: expected_body) }

    context 'when measuring request success' do
      let(:client) { :ai_gateway }

      it_behaves_like 'measured Llm request'

      context 'when request raises an exception' do
        before do
          allow(Gitlab::HTTP).to receive(:post).and_raise(StandardError)
        end

        it_behaves_like 'measured Llm request with error', StandardError
      end

      context 'when request is retried' do
        let(:http_status) { 429 }

        before do
          allow(logger).to receive(:error)
          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request with error', Gitlab::Llm::Concerns::ExponentialBackoff::RateLimitError
      end

      context 'when request is retried once' do
        before do
          allow(logger).to receive(:error)
          stub_request(:post, url)
            .to_return(status: 429, body: '', headers: response_headers)
            .then.to_return(status: 200, body: response_body, headers: response_headers)

          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request'
      end
    end

    it 'returns response' do
      expect(Gitlab::HTTP).to receive(:post)
        .with(anything, hash_including(timeout: timeout))
        .and_call_original
      expect(complete.parsed_response).to eq(expected_response)
    end

    it 'logs request and response' do
      expect(Gitlab::HTTP).to receive(:post)
                                .with(anything, hash_including(timeout: timeout))
                                .and_call_original
      expect(complete).to be_a(HTTParty::Response)
      expect(complete.code).to eq(200)

      expect(logger).to have_received(:conditional_info)
        .with(user, a_hash_including(message: "Performing request to AI Gateway", body: expected_body, timeout: timeout,
          url: url, stream: false))
      expect(logger).to have_received(:conditional_info)
        .with(user, a_hash_including(message: "Received response from AI Gateway",
          response_from_llm: response_body,
          latency_seconds: be_a(Float)))
    end

    context 'when response includes token usage' do
      let(:expected_response) do
        { "response" => "Response", "usage" => { "input_tokens" => 100, "output_tokens" => 42 } }
      end

      let(:response_body) { expected_response.to_json }

      it 'logs input_tokens and output_tokens' do
        complete

        expect(logger).to have_received(:conditional_info)
          .with(user, a_hash_including(
            message: "Received response from AI Gateway",
            response_from_llm: response_body,
            input_tokens: 100,
            output_tokens: 42
          ))
      end
    end

    context 'when response is a non-Hash JSON value' do
      shared_examples 'logs the response without token fields' do
        it 'does not raise and logs the response without token fields', :aggregate_failures do
          expect { complete }.not_to raise_error

          expect(logger).to have_received(:conditional_info)
            .with(user, a_hash_including(
              message: "Received response from AI Gateway",
              response_from_llm: response_body))
          expect(logger).not_to have_received(:conditional_info)
            .with(user, a_hash_including(:input_tokens))
        end
      end

      context 'with a JSON scalar body' do
        let(:response_body) { 'git log -10 --pretty=%s'.to_json }

        it_behaves_like 'logs the response without token fields'
      end

      context 'with a JSON array body' do
        let(:response_body) { %w[a b].to_json }

        it_behaves_like 'logs the response without token fields'
      end
    end

    context 'when request is a 500 error with text body' do
      let(:http_status) { 500 }
      let(:response_headers) { nil }
      let(:response_body) { 'Internal server error' }

      it 'logs an error and returns nil' do
        expect(logger).to receive(:error)
          .with(a_hash_including(message: "Error response from AI Gateway", event_name: 'error_response_received',
            status: 500, body: nil))

        expect(complete).to be_nil
      end
    end

    context 'when request is a 500 error with JSON details' do
      let(:http_status) { 500 }
      let(:response_headers) { { 'Content-Type' => 'application/json' } }
      let(:response_body) { { 'detail' => 'System not ready' }.to_json }

      it 'logs an error and returns the detail' do
        expect(logger).to receive(:error)
          .with(a_hash_including(message: "Error response from AI Gateway", event_name: 'error_response_received',
            status: 500, body: 'System not ready'))

        expect(complete).to be_nil
      end
    end

    context 'when calling AI Gateway with Claude 2.1 model' do
      let(:model) { Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET }
      let(:options) { { model: model } }

      it 'returns expected response' do
        expect(Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(timeout: Gitlab::AiGateway.timeout))
          .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when governing_namespace is set' do
      before do
        allow(user).to receive(:governing_namespace).and_return(group)
      end

      it 'passes non-nil organization_id to headers' do
        allow(Gitlab::AiGateway).to receive(:headers).and_call_original

        expect(Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(timeout: timeout))
          .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
        expect(Gitlab::AiGateway).to have_received(:headers)
          .with(hash_including(organization_id: group.organization_id))
      end
    end

    context 'when governing_namespace is not set' do
      before do
        allow(user).to receive(:governing_namespace).and_return(nil)
      end

      it 'passes nil organization_id to headers' do
        allow(Gitlab::AiGateway).to receive(:headers).and_call_original

        expect(Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(timeout: timeout))
          .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
        expect(Gitlab::AiGateway).to have_received(:headers)
          .with(hash_including(organization_id: nil))
      end
    end
  end

  describe '#complete_prompt' do
    subject(:complete_prompt) do
      ai_client.complete_prompt(
        base_url: ::Gitlab::AiGateway.url,
        prompt_name: 'test_prompt_name',
        inputs: { 'test' => 'Hello' },
        timeout: 10,
        prompt_version: '5.0.0',
        model_metadata: { name: 'mistral' }
      )
    end

    it 'completes with the correct values' do
      expected_body = {
        'inputs' => { 'test' => 'Hello' },
        'prompt_version' => '5.0.0',
        'model_metadata' => { name: 'mistral' }
      }
      expected_url = "#{::Gitlab::AiGateway.url}/v2/prompts/test_prompt_name"

      expect(ai_client).to receive(:complete).with(url: expected_url, body: expected_body, timeout: 10)

      complete_prompt
    end

    context 'when ai_prompts_v2 is disabled' do
      before do
        stub_feature_flags(ai_prompts_v2: false)
      end

      it 'completes with the correct values' do
        expected_body = {
          'inputs' => { 'test' => 'Hello' },
          'prompt_version' => '5.0.0',
          'model_metadata' => { name: 'mistral' }
        }
        expected_url = "#{::Gitlab::AiGateway.url}/v1/prompts/test_prompt_name"

        expect(ai_client).to receive(:complete).with(url: expected_url, body: expected_body, timeout: 10)

        complete_prompt
      end
    end
  end

  describe '#stream' do
    subject { ai_client.stream(url: url, body: expected_body) }

    context 'when streaming the request' do
      let(:response_body) { expected_response }

      context 'when response is successful' do
        let(:expected_response) { 'Hello' }

        it 'provides parsed streamed response' do
          expect { |b| ai_client.stream(url: url, body: expected_body, &b) }.to yield_with_args('Hello')
        end

        it 'returns response' do
          expect(Gitlab::HTTP).to receive(:post)
            .with(anything, hash_including(stream_body: true, timeout: timeout))
            .and_call_original

          expect(ai_client.stream(url: url, body: expected_body)).to eq("Hello")
        end

        it 'logs latency_seconds and user_id on success' do
          expect(logger).to receive(:conditional_info)
            .with(user, a_hash_including(
              message: "Received response from AI Gateway",
              latency_seconds: be_a(Float)))

          ai_client.stream(url: url, body: expected_body)
        end

        context 'when setting a timeout' do
          it 'uses the timeout for the request' do
            expect(Gitlab::HTTP).to receive(:post)
              .with(anything, hash_including(stream_body: true, timeout: 50.seconds))
              .and_call_original

            ai_client.stream(url: url, body: expected_body, timeout: 50.seconds)
          end
        end

        context 'when url is passed as a parameter' do
          let(:url) { "http://127.0.0.1:5000" }

          it 'sends requests to this host instead' do
            ai_client.stream(url: url, body: expected_body)
          end
        end
      end

      context 'when response contains multiple events' do
        let(:expected_response) { "Hello World" }
        let(:success) do
          instance_double(HTTParty::Response,
            code: 200,
            success?: true,
            parsed_response: response_body,
            headers: response_headers,
            body: response_body
          )
        end

        before do
          allow(Gitlab::HTTP).to receive(:post).and_return(success)
            .and_yield("Hello").and_yield(" ").and_yield("World")
        end

        it 'provides parsed streamed response' do
          expect { |b| ai_client.stream(url: url, body: expected_body, &b) }
            .to yield_successive_args('Hello', ' ', 'World')
        end

        it 'returns response' do
          expect(ai_client.stream(url: url, body: expected_body)).to eq(expected_response)
        end
      end

      context 'when response is not successful' do
        let(:response_body) do
          { "detail" => [{ "msg" => "Input is invalid" }] }.to_json
        end

        let(:failure) do
          instance_double(HTTParty::Response,
            code: http_code,
            success?: false,
            headers: response_headers,
            body: response_body,
            forbidden?: forbidden_status,
            parsed_response: Gitlab::Json.parse(response_body)
          )
        end

        # rubocop:disable RSpec/MultipleMemoizedHelpers -- All helpers are needed
        before do
          allow(ai_client).to receive(:perform_completion_request).and_yield(response_body).and_return(failure)
          allow(logger).to receive(:error)
        end

        context 'when there is problem with connection' do
          let(:http_code) { 400 }
          let(:forbidden_status) { false }

          it 'raises error' do
            expect { ai_client.stream(url: url, body: expected_body) }
              .to raise_error(Gitlab::Llm::AiGateway::Client::ConnectionError)

            expect(logger).to have_received(:error).with(a_hash_including(
              message: "Error response from AI Gateway",
              body: "Input is invalid",
              status: http_code
            ))
          end

          context 'when the response has no detail' do
            let(:response_body) do
              "Input is invalid".to_json
            end

            it 'raises error' do
              expect { ai_client.stream(url: url, body: expected_body) }
                .to raise_error(Gitlab::Llm::AiGateway::Client::ConnectionError)

              expect(logger).to have_received(:error).with(a_hash_including(
                message: "Error response from AI Gateway",
                body: nil,
                status: http_code
              ))
            end
          end
        end

        context 'when instance do not have access to feature' do
          let(:http_code) { 403 }
          let(:forbidden_status) { true }

          it 'raises error' do
            expect { ai_client.stream(url: url, body: expected_body) }
              .to raise_error(Gitlab::AiGateway::ForbiddenError)

            expect(logger).to have_received(:error).with(a_hash_including(
              message: "Error response from AI Gateway",
              body: "Input is invalid",
              status: http_code
            ))
          end
        end
      end
      # rubocop:enable RSpec/MultipleMemoizedHelpers
    end
  end

  describe '#complete with namespace, project and governing context' do
    let(:ai_client_with_context) do
      described_class.new(
        user,
        unit_primitive_name: :test,
        tracking_context: tracking_context,
        namespace_id: 10,
        project_id: 20,
        governing_namespace_id: 30
      )
    end

    subject(:complete) { ai_client_with_context.complete(url: url, body: expected_body) }

    it 'forwards them to Gitlab::AiGateway.headers' do
      allow(Gitlab::AiGateway).to receive(:headers).and_call_original

      expect(Gitlab::HTTP).to receive(:post)
        .with(anything, hash_including(timeout: timeout)).and_call_original
      complete
      expect(Gitlab::AiGateway).to have_received(:headers)
        .with(hash_including(namespace_id: 10, project_id: 20, governing_namespace_id: 30))
    end
  end
end
