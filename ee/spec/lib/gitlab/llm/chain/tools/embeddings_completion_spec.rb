# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Llm::Chain::Tools::EmbeddingsCompletion, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:search_documents) { build_list(:vertex_gitlab_documentation, 2) }

  let(:question) { 'A question' }
  let(:answer) { 'The answer.' }
  let(:logger) { instance_double('Gitlab::Llm::Logger') }
  let(:instance) { described_class.new(current_user: user, question: question, search_documents: search_documents) }
  let(:attrs) { search_documents.pluck(:id).map { |x| "CNT-IDX-#{x}" }.join(", ") }
  let(:completion_response) { { 'response' => "#{answer} ATTRS: #{attrs}" } }
  let(:model) { ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_7_SONNET }
  let(:inputs) do
    {
      question: question,
      content_id: Gitlab::Llm::Anthropic::Templates::TanukiBot::CONTENT_ID_FIELD,
      documents: search_documents
    }
  end

  let(:ai_gateway_request) do
    ::Gitlab::Llm::Chain::Requests::AiGateway.new(user, unit_primitive_name: :duo_classic_chat)
  end

  describe '#execute' do
    subject(:execute) { instance.execute }

    before do
      allow(logger).to receive(:conditional_info)
      allow(logger).to receive(:info)

      allow(::Gitlab::Llm::Logger).to receive(:build).and_return(logger)

      allow(::Gitlab::Llm::DuoChat).to receive(:enabled_for?).and_return(true)

      allow(::Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).and_return(ai_gateway_request)

      allow(ai_gateway_request).to receive(:request).and_return(completion_response)
    end

    it 'executes calls and returns ResponseModifier' do
      expect(ai_gateway_request).to receive(:request)
        .with({ prompt: instance_of(Array),
          options: { inputs: inputs, model: model, max_tokens: 256 } },
          unit_primitive: :documentation_search)
        .once.and_return(completion_response)

      expect(execute).to be_an_instance_of(::Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot)
    end

    it 'yields the streamed response to the given block' do
      allow(Banzai).to receive(:render).and_return('absolute_links_content')

      expect(ai_gateway_request)
        .to receive(:request)
        .with({ prompt: instance_of(Array),
          options: { inputs: inputs, model: model, max_tokens: 256 } },
          unit_primitive: :documentation_search)
        .once
        .and_yield(answer)
        .and_return(completion_response)

      expect { |b| instance.execute(&b) }.to yield_with_args(answer)
    end

    it 'raises an error when request failed' do
      expect(logger).to receive(:error).with(a_hash_including(message: "Streaming error", error: anything))
      allow(ai_gateway_request).to receive(:request).once
                                                    .and_raise(::Gitlab::Llm::AiGateway::Client::ConnectionError.new)

      execute
    end
  end
end
