# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::VertexAi::Client, feature_category: :ai_abstraction_layer do
  let_it_be(:user) { create(:user) }

  let(:access_token) { SecureRandom.uuid }
  let(:url) { 'https://example.com/api' }
  let(:host) { 'example.com' }
  let(:options) { {} }
  let(:unit_primitive) { 'explain_vulnerability' }
  let(:tracking_context) { { request_id: 'uuid', action: 'chat' } }
  let(:model_config) do
    instance_double(
      ::Gitlab::Llm::VertexAi::ModelConfigurations::CodeChat,
      url: url,
      host: host,
      payload: request_payload
    )
  end

  let(:response_headers) { { 'Content-Type' => 'application/json' } }

  let(:headers) do
    {
      accept: 'application/json',
      'Authorization' => "Bearer #{access_token}",
      'Content-Type' => 'application/json',
      'Host' => host
    }
  end

  let(:request_payload) do
    {
      instances: [
        {
          messages: [
            {
              author: "content",
              content: "Hello, world!"
            }
          ]
        }
      ],
      parameters: {
        temperature: Gitlab::Llm::VertexAi::Configuration::DEFAULT_TEMPERATURE
      }
    }
  end

  let(:successful_response) do
    {
      safetyAttributes: { blocked: false },
      predictions: [candidates: [{ content: "Hello, world" }]],
      metadata: {
        tokenMetadata: {
          inputTokenCount: { totalTokens: 10, totalBillableCharacters: 30 },
          outputTokenCount: { totalTokens: 20, totalBillableCharacters: 41 }
        }
      }
    }
  end

  let(:client) { described_class.new(user, unit_primitive: unit_primitive, tracking_context: tracking_context) }
  let(:logger) { instance_double('Gitlab::Llm::Logger') }

  RSpec.shared_context 'when request is successful' do
    before do
      allow_next_instance_of(Gitlab::Llm::VertexAi::Configuration) do |instance|
        allow(instance).to receive(:model_config).and_return(model_config)
        allow(instance).to receive(:headers).and_return(headers)
        allow(instance).to receive(:access_token).and_return(access_token)

        stub_request(:post, url).with(
          headers: headers,
          body: request_payload
        ).to_return(status: 200, body: successful_response.to_json, headers: response_headers)
      end
    end
  end

  RSpec.shared_context 'when a failed response is returned from the API' do
    let(:too_many_requests_response) do
      {
        error: {
          code: 429,
          message: 'Rate Limit Exceeded',
          status: 'RATE_LIMIT_EXCEEDED',
          details: [
            {
              "@type": 'type.googleapis.com/google.rpc.ErrorInfo',
              reason: 'RATE_LIMIT_EXCEEDED',
              metadata: {
                service: 'aiplatform.googleapis.com',
                method: 'google.cloud.aiplatform.v1.PredictionService.Predict'
              }
            }
          ]
        }
      }
    end

    before do
      allow_next_instance_of(Gitlab::Llm::VertexAi::Configuration) do |instance|
        allow(instance).to receive(:model_config).and_return(model_config)
        allow(instance).to receive(:headers).and_return(headers)
        allow(instance).to receive(:access_token).and_return(access_token)
      end

      stub_request(:post, url)
        .to_return(status: 429, body: too_many_requests_response.to_json, headers: response_headers)
        .then.to_return(status: 429, body: too_many_requests_response.to_json, headers: response_headers)
        .then.to_return(status: 200, body: successful_response.to_json, headers: response_headers)

      allow(client).to receive(:sleep).and_return(nil)
    end
  end

  shared_examples 'forwarding the request correctly' do
    before do
      allow_next_instance_of(Gitlab::Llm::VertexAi::Configuration) do |instance|
        allow(instance).to receive(:model_config).and_return(model_config)
        allow(instance).to receive(:headers).and_return(headers)
        allow(instance).to receive(:access_token).and_return(access_token)
      end
    end

    context 'when a successful response is returned from the API' do
      include_context 'when request is successful'

      it 'returns the response' do
        expect(response).to be_present
        expect(::Gitlab::Json.parse(response.body, symbolize_names: true))
          .to match(hash_including(successful_response))
      end
    end

    context 'when a 403 error is returned from the API' do
      before do
        stub_request(:post, url).to_return(status: 403, body: "403 Unauthorized")
      end

      it 'returns a 403 response' do
        expect(response.code).to eq(403)
      end
    end

    context 'when a failed response is returned from the API' do
      include_context 'when a failed response is returned from the API'

      it 'retries the request' do
        expect(response).to be_present
        expect(response.code).to eq(200)
      end
    end

    context 'when a content blocked response is returned from the API' do
      let(:content_blocked_response) do
        { safetyAttributes: { blocked: true }, predictions: [candidates: [{ content: "I am just an AI..." }]] }
      end

      context 'and retry_content_blocked_requests is true' do
        let(:client) { described_class.new(user, unit_primitive: unit_primitive, retry_content_blocked_requests: true) }

        before do
          stub_request(:post, url)
            .to_return(status: 200, body: content_blocked_response.to_json, headers: response_headers)
            .then.to_return(status: 200, body: successful_response.to_json, headers: response_headers)

          allow(client).to receive(:sleep).and_return(nil)
        end

        it 'retries the request' do
          expect(response).to be_present
          expect(response.code).to eq(200)
          expect(client).to have_received(:sleep)
        end
      end

      context 'and retry_content_blocked_requests is false' do
        let(:client) do
          described_class.new(user, unit_primitive: unit_primitive, retry_content_blocked_requests: false)
        end

        before do
          stub_request(:post, url)
            .to_return(status: 200, body: content_blocked_response.to_json, headers: response_headers)

          allow(client).to receive(:sleep).and_return(nil)
        end

        it 'retries the request' do
          expect(response).to be_present
          expect(response.code).to eq(200)
          expect(client).not_to have_received(:sleep)
        end
      end
    end
  end

  describe '#chat' do
    subject(:response) { client.chat(content: 'anything', **options) }

    it_behaves_like 'forwarding the request correctly'

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when request is successful'
    end

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when a failed response is returned from the API'
    end
  end

  describe '#messages_chat' do
    let(:messages) do
      [
        { author: 'user', content: 'any' },
        { author: 'content', content: 'th' },
        { author: 'user', content: 'ing' }
      ]
    end

    subject(:response) { client.messages_chat(content: messages, **options) }

    it_behaves_like 'forwarding the request correctly'
    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when request is successful'
    end

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when a failed response is returned from the API'
    end
  end

  describe '#text' do
    subject(:response) { client.text(content: 'anything', **options) }

    it_behaves_like 'forwarding the request correctly'

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when request is successful'
    end

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when a failed response is returned from the API'
    end
  end

  describe '#code' do
    subject(:response) { client.code(content: 'anything', **options) }

    it_behaves_like 'forwarding the request correctly'

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when request is successful'
    end

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when a failed response is returned from the API'
    end
  end

  describe '#code_completion' do
    subject(:response) do
      client.code_completion(content: { content_above_cursor: "any", content_below_cursor: "thing" }, **options)
    end

    it_behaves_like 'forwarding the request correctly'

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when request is successful'
    end

    it_behaves_like 'tracks events for AI requests', 10, 20 do
      include_context 'when a failed response is returned from the API'
    end
  end

  describe '#request' do
    let(:url) { 'https://example.com/api' }

    let(:successful_response) do
      { safetyAttributes: { blocked: false }, predictions: [candidates: [{ content: "Hello, world" }]] }
    end

    let(:config) do
      instance_double(
        ::Gitlab::Llm::VertexAi::Configuration,
        headers: {},
        payload: {},
        url: url
      )
    end

    let(:http_status) { 200 }

    subject { described_class.new(user, unit_primitive: unit_primitive).text(content: 'anything', **options) }

    before do
      allow(Gitlab::Llm::VertexAi::Configuration).to receive(:new).and_return(config)
      stub_request(:post, url).to_return(
        status: http_status, body: successful_response.to_json, headers: response_headers
      )
    end

    context 'when measuring request success' do
      let(:client) { :vertex_ai }

      before do
        allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
        allow(logger).to receive(:conditional_info)
        allow(logger).to receive(:info)
        allow(logger).to receive(:error)
      end

      it_behaves_like 'measured Llm request'

      it 'logs the response' do
        subject # rubocop: disable RSpec/NamedSubject -- We cannot name it as it is used in shared context above

        expect(logger).to have_received(:info).with(a_hash_including(message: "Performing request to Vertex",
          options: config))
        expect(logger).to have_received(:conditional_info).with(user, a_hash_including(
          message: "Response content",
          response_from_llm: successful_response.to_json))
      end

      context 'when request raises an exception' do
        before do
          allow(Gitlab::HTTP).to receive(:post).and_raise(StandardError)
        end

        it_behaves_like 'measured Llm request with error', StandardError
      end

      context 'when request is retried' do
        let(:http_status) { 429 }

        before do
          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request with error', Gitlab::Llm::Concerns::ExponentialBackoff::RateLimitError
      end

      context 'when response is empty' do
        before do
          stub_request(:post, url).to_return(
            status: http_status, body: nil, headers: response_headers
          )
        end

        it 'does not fail and logs an error' do
          subject # rubocop: disable RSpec/NamedSubject -- We cannot name it as it is used in shared context above
          expect(logger).to have_received(:error).with(a_hash_including(message: "Empty response from Vertex"))
        end
      end
    end
  end
end
