# frozen_string_literal: true

RSpec.shared_examples 'anthropic client' do
  include StubRequests

  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, :repository, group: group) }
  let_it_be(:user, freeze: false) { create(:user, maintainer_of: project) }

  let(:enabled_by_namespace_ids) { [1, 2] }
  let(:enablement_type) { 'add_on' }
  let(:options) { {} }
  let(:expected_request_body) { default_body_params }
  let(:auth_response) do
    instance_double(Ai::UserAuthorizable::Response,
      namespace_ids: enabled_by_namespace_ids, enablement_type: enablement_type)
  end

  let(:aigw_headers) { { 'header' => 'value' } }
  let(:expected_request_headers) do
    aigw_headers.merge({
      'Accept' => 'application/json',
      'anthropic-version' => '2023-06-01',
      'X-Gitlab-Unit-Primitive' => unit_primitive.to_s
    })
  end

  let(:default_body_params) do
    {
      prompt: "anything",
      model: ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET,
      max_tokens_to_sample: described_class::DEFAULT_MAX_TOKENS,
      temperature: described_class::DEFAULT_TEMPERATURE
    }
  end

  let(:expected_response) do
    {
      'completion' => 'data: { response: Completion Response }',
      'stop' => nil,
      'stop_reason' => 'max_tokens',
      'truncated' => false,
      'log_id' => 'b454d92a4e108ab78dcccbcc6c83f7ba',
      'model' => 'claude-v1.3',
      'exception' => nil
    }
  end

  let(:tracking_context) { { request_id: 'uuid', action: 'chat' } }
  let(:response_body) { expected_response.to_json }
  let(:http_status) { 200 }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }
  let(:logger) { instance_double('Gitlab::Llm::Logger') }
  let(:ai_gateway_url) { 'https://cloud.example.com/ai' }

  before do
    stub_application_setting(ai_gateway_url: ai_gateway_url)
    allow(user).to receive_messages(governing_namespace: group, allowed_to_use: auth_response)

    allow(Gitlab::AiGateway)
      .to receive(:headers)
      .with(user: user, unit_primitive_name: unit_primitive, ai_feature_name: :anthropic_proxy,
        organization_id: user.governing_namespace&.organization_id,
        governing_namespace_id: user.governing_namespace&.id)
      .and_return(aigw_headers)

    stub_request(:post, "#{ai_gateway_url}/v1/proxy/anthropic/v1/complete")
      .with(
        body: expected_request_body.to_json,
        headers: expected_request_headers
      )
      .to_return(
        status: http_status,
        body: response_body,
        headers: response_headers
      )
    allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
    allow(logger).to receive(:conditional_info)
    allow(logger).to receive(:info)
  end

  describe '#complete' do
    subject(:complete) do
      described_class.new(user, unit_primitive: unit_primitive, tracking_context: tracking_context)
        .complete(prompt: 'anything', **options)
    end

    context 'when measuring request success' do
      let(:client) { :anthropic }

      it_behaves_like 'measured Llm request'

      context 'when request raises an exception' do
        before do
          allow(Gitlab::HTTP).to receive(:post).and_raise(StandardError)
        end

        it_behaves_like 'measured Llm request with error', StandardError
      end

      context 'when response is a 500 error' do
        let(:http_status) { 500 }
        let(:response_body) { nil }
        let(:response_headers) { nil }

        it 'returns nil' do
          expect(complete).to be_nil
        end
      end

      context 'when response is 204 No Content' do
        let(:http_status) { 204 }
        let(:response_body) { nil }
        let(:response_headers) { nil }

        it_behaves_like 'measured Llm request'
      end

      context 'when response is a bad request with no body' do
        let(:http_status) { 400 }
        let(:response_body) { nil }
        let(:response_headers) { nil }

        it 'returns nil' do
          expect(complete).to be_nil
        end
      end

      context 'when response is a an authentication error' do
        let(:http_status) { 401 }
        let(:response_body) do
          {
            "type" => "error",
            "error" => {
              "type" => "authentication_error",
              "message" => "There’s an issue with your API key."
            }
          }.to_json
        end

        it 'returns a response' do
          expect(complete).to be_present
          expect(complete.parsed_response['type']).to eq('error')
          expect(complete.parsed_response['error']['type']).to eq('authentication_error')
        end
      end

      context 'when request is retried' do
        let(:http_status) { 429 }

        before do
          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request with error', Gitlab::Llm::Concerns::ExponentialBackoff::RateLimitError
      end

      context 'when request is retried once' do
        before do
          stub_request(:post, "#{ai_gateway_url}/v1/proxy/anthropic/v1/complete")
            .to_return(status: 429, body: '', headers: response_headers)
            .then.to_return(status: 200, body: response_body, headers: response_headers)

          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'tracks events for AI requests', 2, 9
      end
    end

    it_behaves_like 'tracks events for AI requests', 2, 9

    it 'logs the response' do
      complete
      expected_logging_response = expected_response["completion"]

      expect(logger).to have_received(:info).with(a_hash_including(message: "Performing request to Anthropic",
        options: options))
      expect(logger).to have_received(:conditional_info).with(user, a_hash_including(
        message: "Response content",
        response_from_llm: expected_logging_response))
    end

    context 'when feature flag and API key is set' do
      it 'returns response' do
        expect(Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
          .and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when governing_namespace is nil' do
      before do
        allow(user).to receive(:governing_namespace).and_return(nil)
        allow(Gitlab::AiGateway)
          .to receive(:headers)
          .with(user: user, unit_primitive_name: unit_primitive, ai_feature_name: :anthropic_proxy,
            organization_id: nil, governing_namespace_id: nil)
          .and_return(aigw_headers)
      end

      it 'passes nil organization_id to headers' do
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when using options' do
      let(:options) { { temperature: 0.1, timeout: 50.seconds } }

      let(:expected_request_body) do
        {
          prompt: "anything",
          model: ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET,
          max_tokens_to_sample: described_class::DEFAULT_MAX_TOKENS,
          temperature: options[:temperature]
        }
      end

      it 'returns response' do
        expect(Gitlab::HTTP).to receive(:post).with(anything, hash_including(timeout: 50.seconds)).and_call_original
        expect(complete.parsed_response).to eq(expected_response)
      end
    end

    context 'when passing stream: true' do
      let(:options) { { stream: true } }
      let(:expected_request_body) { default_body_params }

      it 'does not pass stream: true as we do not want to retrieve SSE events' do
        expect(complete.parsed_response).to eq(expected_response)
      end
    end
  end

  describe '#stream' do
    subject do
      described_class.new(user, unit_primitive: unit_primitive, tracking_context: tracking_context)
        .stream(prompt: 'anything', **options)
    end

    context 'when streaming the request' do
      let(:response_body) { expected_response }
      let(:options) { { stream: true } }
      let(:expected_request_body) { default_body_params.merge(stream: true) }

      context 'when response is successful' do
        let(:expected_response) do
          <<-DOC
          event: completion\r\n
          data: {"completion": "Hello", "stop_reason": null, "model": "claude-2.0"}\r\n
          \r\n
          DOC
        end

        context 'when json is malformed' do
          let(:expected_response) do
            <<-DOC
            event: completion
            data: {invalid json}

            DOC
          end

          it 'ignores the malformed event and does not crash' do
            expect do
              described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options)
            end.not_to raise_error
          end
        end

        it 'provides parsed streamed response' do
          expect do |b|
            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options, &b)
          end.to yield_with_args(
            {
              "completion" => "Hello",
              "stop_reason" => nil,
              "model" => "claude-2.0"
            }
          )
        end

        it 'returns response' do
          expect(Gitlab::HTTP).to receive(:post)
            .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
            .and_call_original

          expect(
            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options)
          ).to eq("Hello")
        end

        it 'logs the response' do
          described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options)
          expected_logging_response = "Hello"

          expect(logger).to have_received(:info).with(a_hash_including(message: "Performing request to Anthropic",
            options: options))
          expect(logger).to have_received(:conditional_info).with(user, a_hash_including(
            message: "Response content",
            response_from_llm: expected_logging_response))
        end

        context 'when setting a timeout' do
          let(:options) { { timeout: 50.seconds } }

          it 'uses the timeout for the request' do
            expect(Gitlab::HTTP).to receive(:post)
              .with(anything, hash_including(timeout: 50.seconds))
              .and_call_original

            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options)
          end
        end

        it_behaves_like 'tracks events for AI requests', 2, 1
      end

      context 'when response contains multiple events' do
        let(:expected_response) do
          <<-DOC
          event: completion\r
          data: {"completion":"Hello", "stop_reason": null, "model": "claude-2.0" }\r
          \r
          event: completion\r
          data: {"completion":" World", "stop_reason": null, "model": "claude-2.0" }\r
          \r
          DOC
        end

        it 'provides parsed streamed response' do
          expect do |b|
            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options, &b)
          end.to yield_successive_args(
            {
              "completion" => "Hello",
              "stop_reason" => nil,
              "model" => "claude-2.0"
            },
            {
              "completion" => " World",
              "stop_reason" => nil,
              "model" => "claude-2.0"
            }
          )
        end

        it 'returns response' do
          expect(
            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options)
          ).to eq("Hello World")
        end
      end

      context 'when response is an error' do
        let(:expected_response) do
          <<-DOC
          event: error\r
          data: {"error": {"type": "overloaded_error", "message": "Overloaded"}}\r
          \r
          DOC
        end

        it 'provides parsed streamed response' do
          expect do |b|
            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options, &b)
          end.to yield_with_args(
            {
              "error" => { "message" => "Overloaded", "type" => "overloaded_error" }
            }
          )
        end

        it 'returns empty response' do
          expect(
            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options)
          ).to eq("")
        end
      end

      context 'when response is a ping' do
        let(:expected_response) do
          <<-DOC
          event: ping\r
          data: {}\r
          \r\n
          DOC
        end

        it 'provides parsed streamed response' do
          expect do |b|
            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options, &b)
          end.to yield_with_args({})
        end

        it 'returns empty response' do
          expect(
            described_class.new(user, unit_primitive: unit_primitive).stream(prompt: 'anything', **options)
          ).to eq("")
        end
      end
    end
  end

  describe '#messages_complete' do
    let(:messages_body_params) do
      {
        messages: 'anything',
        model: ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET,
        max_tokens: described_class::DEFAULT_MAX_TOKENS,
        temperature: described_class::DEFAULT_TEMPERATURE
      }
    end

    let(:expected_messages_response) do
      {
        'id' => 'msg_01JPMpeAAtZdoNLvq8Nqhd3D',
        'type' => 'message',
        'role' => 'assistant',
        'model' => 'claude-v1.3',
        'content' => [
          {
            'type' => 'text',
            'text' => 'data: { response: Completion Response }'
          }
        ],
        'stop_reason' => 'end_turn',
        'stop_sequence' => nil,
        'usage' => {
          'input_tokens' => 130,
          'output_tokens' => 26
        }
      }
    end

    let(:expected_request_body) { messages_body_params }
    let(:response_body) { expected_messages_response.to_json }

    before do
      stub_request(:post, "#{ai_gateway_url}/v1/proxy/anthropic/v1/messages")
        .with(
          body: expected_request_body.to_json,
          headers: expected_request_headers
        )
        .to_return(
          status: http_status,
          body: response_body,
          headers: response_headers
        )
    end

    subject(:messages_complete) do
      described_class.new(user, unit_primitive: unit_primitive, tracking_context: tracking_context)
        .messages_complete(messages: 'anything', **options)
    end

    context 'when measuring request success' do
      let(:client) { :anthropic }

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
          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'measured Llm request with error', Gitlab::Llm::Concerns::ExponentialBackoff::RateLimitError
      end

      context 'when response is a service error' do
        let(:http_status) { 500 }

        it 'returns nil response' do
          expect(subject).to be_nil
        end
      end

      context 'when response is a bad request with no body' do
        let(:http_status) { 400 }
        let(:response_body) { nil }
        let(:response_headers) { nil }

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end

      context 'when response is a an authentication error' do
        let(:http_status) { 401 }
        let(:response_body) do
          {
            "type" => "error",
            "error" => {
              "type" => "authentication_error",
              "message" => "There’s an issue with your API key."
            }
          }.to_json
        end

        it 'returns a response' do
          expect(subject).to be_present
          expect(subject.parsed_response['type']).to eq('error')
          expect(subject.parsed_response['error']['type']).to eq('authentication_error')
        end
      end

      context 'when request is retried once' do
        before do
          stub_request(:post, "#{ai_gateway_url}/v1/proxy/anthropic/v1/messages")
            .to_return(status: 429, body: '', headers: response_headers)
            .then.to_return(status: 200, body: response_body, headers: response_headers)

          stub_const("Gitlab::Llm::Concerns::ExponentialBackoff::INITIAL_DELAY", 0.0)
        end

        it_behaves_like 'tracks events for AI requests', 2, 9
      end
    end

    it_behaves_like 'tracks events for AI requests', 2, 9

    it 'logs the response' do
      messages_complete
      expected_logging_response = expected_messages_response.dig('content', 0, 'text')

      expect(logger).to have_received(:info).with(a_hash_including(message: "Performing request to Anthropic",
        options: options))
      expect(logger).to have_received(:conditional_info).with(user, a_hash_including(
        message: "Response content",
        response_from_llm: expected_logging_response))
    end

    context 'when feature flag and API key is set' do
      it 'returns response' do
        expect(Gitlab::HTTP).to receive(:post)
          .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
          .and_call_original
        expect(messages_complete.parsed_response).to eq(expected_messages_response)
      end
    end

    context 'when using options' do
      let(:options) { { temperature: 0.1, timeout: 50.seconds } }

      let(:expected_request_body) do
        {
          messages: 'anything',
          model: ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET,
          max_tokens: described_class::DEFAULT_MAX_TOKENS,
          temperature: options[:temperature]
        }
      end

      it 'returns response' do
        expect(Gitlab::HTTP).to receive(:post).with(anything, hash_including(timeout: 50.seconds)).and_call_original
        expect(messages_complete.parsed_response).to eq(expected_messages_response)
      end
    end

    context 'when passing stream: true' do
      let(:options) { { stream: true } }
      let(:expected_request_body) { messages_body_params }

      it 'does not pass stream: true as we do not want to retrieve SSE events' do
        expect(messages_complete.parsed_response).to eq(expected_messages_response)
      end
    end

    context 'when forbidden' do
      before do
        stub_request(:post, "#{ai_gateway_url}/v1/proxy/anthropic/v1/messages")
          .to_return(status: 403, body: '', headers: response_headers)
      end

      it 'raises a forbidden error' do
        expect { messages_complete }.to raise_error { Gitlab::AiGateway::ForbiddenError }
      end
    end
  end

  describe '#messages_stream' do
    let(:messages_body_params) do
      {
        messages: 'anything',
        model: ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET,
        max_tokens: described_class::DEFAULT_MAX_TOKENS,
        temperature: described_class::DEFAULT_TEMPERATURE
      }
    end

    subject do
      described_class.new(user, unit_primitive: unit_primitive, tracking_context: tracking_context)
                     .messages_stream(messages: 'anything', **options)
    end

    before do
      stub_request(:post, "#{ai_gateway_url}/v1/proxy/anthropic/v1/messages")
        .with(
          body: expected_request_body.to_json,
          headers: expected_request_headers
        )
        .to_return(
          status: http_status,
          body: response_body,
          headers: response_headers
        )
    end

    context 'when streaming the request' do
      let(:response_body) { expected_response }
      let(:options) { { stream: true } }
      let(:expected_request_body) { messages_body_params.merge(stream: true) }

      context 'when response is successful' do
        let(:expected_response) do
          <<-DOC
          event: content_block_delta\r
          data: {"delta": { "text": "Hello" } }\r
          DOC
        end

        context 'when json is malformed' do
          let(:expected_response) do
            <<-DOC
            event: completion
            data: {invalid json}

            DOC
          end

          it 'ignores the malformed event and does not crash' do
            expect { subject }.not_to raise_error
          end

          it 'logs the parse failure' do
            subject
            expect(logger).to have_received(:info).with(
              a_hash_including(message: 'Failed to parse SSE event', event_name: 'parse_sse_event_error')
            )
          end
        end

        it 'provides parsed streamed response' do
          expect do |b|
            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options,
              &b)
          end.to yield_with_args(
            {
              "delta" => { "text" => "Hello" }
            }
          )
        end

        it 'returns response' do
          expect(Gitlab::HTTP).to receive(:post)
                                    .with(anything, hash_including(timeout: described_class::DEFAULT_TIMEOUT))
                                    .and_call_original

          expect(
            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options)
          ).to eq("Hello")
        end

        it 'logs the response' do
          described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options)
          expected_logging_response = "Hello"

          expect(logger).to have_received(:info).with(a_hash_including(message: "Performing request to Anthropic",
            options: options))
          expect(logger).to have_received(:conditional_info).with(user, a_hash_including(
            message: "Response content",
            response_from_llm: expected_logging_response))
        end

        context 'when setting a timeout' do
          let(:options) { { timeout: 50.seconds } }

          it 'uses the timeout for the request' do
            expect(Gitlab::HTTP).to receive(:post)
                                      .with(anything, hash_including(timeout: 50.seconds))
                                      .and_call_original

            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options)
          end
        end

        it_behaves_like 'tracks events for AI requests', 2, 1
      end

      context 'when response contains multiple events' do
        let(:expected_response) do
          <<-DOC
          event: content_block_delta\r
          data: {"delta": { "text": "Hello " } }\r
          \r
          event: content_block_delta\r
          data: {"delta": { "text": "World" } }\r
          \r
          DOC
        end

        it 'provides parsed streamed response' do
          expect do |b|
            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options,
              &b)
          end.to yield_successive_args(
            {
              "delta" => { "text" => "Hello " }
            },
            {
              "delta" => { "text" => "World" }
            }
          )
        end

        it 'returns response' do
          expect(
            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options)
          ).to eq("Hello World")
        end
      end

      context 'when response is an error' do
        let(:expected_response) do
          <<-DOC
          event: error\r
          data: {"error": {"type": "overloaded_error", "message": "Overloaded"}}\r
          \r
          DOC
        end

        it 'provides parsed streamed response' do
          expect do |b|
            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options,
              &b)
          end.to yield_with_args(
            {
              "error" => { "message" => "Overloaded", "type" => "overloaded_error" }
            }
          )
        end

        it 'returns empty response' do
          expect(
            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options)
          ).to eq("")
        end
      end

      context 'when response is a ping' do
        let(:expected_response) do
          <<-DOC
          event: ping\r
          data: {}\r
          \r\n
          DOC
        end

        it 'provides parsed streamed response' do
          expect do |b|
            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options,
              &b)
          end.to yield_with_args({})
        end

        it 'returns empty response' do
          expect(
            described_class.new(user, unit_primitive: unit_primitive).messages_stream(messages: 'anything', **options)
          ).to eq("")
        end
      end
    end
  end
end
