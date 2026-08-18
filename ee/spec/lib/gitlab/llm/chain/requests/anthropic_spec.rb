# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Requests::Anthropic, feature_category: :duo_chat do
  let_it_be(:user) { build(:user) }

  describe 'initializer' do
    it 'initializes the anthropic client' do
      request = described_class.new(user, unit_primitive: 'duo_chat')

      expect(request.ai_client.class).to eq(::Gitlab::Llm::Anthropic::Client)
    end
  end

  describe '#request' do
    subject(:request) { instance.request(params) }

    let(:instance) { described_class.new(user, unit_primitive: 'duo_chat') }
    let(:logger) { instance_double(Gitlab::Llm::Logger) }
    let(:ai_client) { double }
    let(:prompt_message) do
      [
        {
          role: :user,
          content: "Some user request"
        }
      ]
    end

    let(:response) do
      {
        "delta" => {
          "type" => "text_delta",
          "text" => "Hello World"
        }
      }
    end

    let(:expected_params) do
      {
        messages: prompt_message
      }
    end

    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      allow(instance).to receive(:ai_client).and_return(ai_client)
    end

    context 'with prompt' do
      let(:params) do
        { messages: prompt_message, max_tokens: 4000 }
      end

      it 'calls the anthropic messages streaming endpoint and yields response without stripping it' do
        expect(ai_client).to receive(:messages_stream).with(expected_params.merge(max_tokens: 4000)).and_yield(response)

        expect { |b| instance.request(params, &b) }.to yield_with_args("Hello World")
      end

      it 'returns the response from anthropic' do
        expect(ai_client).to receive(:messages_stream).with(expected_params.merge({ max_tokens: 4000 }))
          .and_return(response)

        expect(request["delta"]["text"]).to eq("Hello World")
      end
    end

    context 'when options are not present' do
      let(:params) { { messages: prompt_message } }

      it 'calls the anthropic streaming endpoint' do
        expect(ai_client).to receive(:messages_stream).with(expected_params)

        request
      end
    end

    context 'when stream errors' do
      let(:params) { { messages: prompt_message } }
      let(:response) { { "error" => { "type" => "overload_error", message: "Overloaded" } } }

      it 'logs the error' do
        expect(ai_client).to receive(:messages_stream).with(expected_params).and_yield(response)
        expect(logger).to receive(:error).with(hash_including(message: "Streaming error",
          error: response.dig("error", "type")))

        request
      end
    end
  end
end
