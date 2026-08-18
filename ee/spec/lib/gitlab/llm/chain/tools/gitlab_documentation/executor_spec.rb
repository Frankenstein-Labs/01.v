# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::GitlabDocumentation::Executor, :saas, feature_category: :duo_chat do
  describe '#execute' do
    subject(:result) { tool.execute }

    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, developers: user) }

    let(:tool) { described_class.new(context: context, options: options, stream_response_handler: response_service) }
    let(:completion) { { 'completion' => 'In your User settings. ATTRS: CNT-IDX-123' }.to_json }
    let(:response_service) { nil }

    let(:search_documents) { build_list(:vertex_gitlab_documentation, 1) }
    let(:response) do
      Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot.new(completion, user, search_documents: search_documents)
    end

    let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }

    let(:options) { { input: "how to reset the password?" } }
    let(:context) do
      Gitlab::Llm::Chain::GitlabContext.new(
        container: group,
        resource: nil,
        current_user: user,
        ai_request: ai_request_double
      )
    end

    context 'when context is authorized' do
      before do
        allow(user).to receive(:can?).with(:access_duo_entry_point).and_return(true)
      end

      let(:expected_params) do
        {
          current_user: user,
          question: options[:input],
          search_documents: search_documents,
          tracking_context: { action: 'chat_documentation' }
        }
      end

      let(:docs_search_response) do
        {
          'response' => { 'results' => search_documents }
        }
      end

      it 'responds with the message from TanukiBot' do
        expect_next_instance_of(
          ::Gitlab::Llm::AiGateway::DocsClient, user, namespace_id: nil, project_id: nil
        ) do |instance|
          expect(instance).to receive(:search).with(query: options[:input]).and_return(docs_search_response)
        end

        expect_next_instance_of(::Gitlab::Llm::Chain::Tools::EmbeddingsCompletion, **expected_params) do |instance|
          expect(instance).to receive(:execute).and_return(response).and_yield('In').and_yield('your')
        end

        expect(result.content).to eq("In your User settings.")
        expect(result.extras).to eq(sources: [])
      end

      context 'with a stream_response_handler set' do
        let(:response_service) { instance_double(::Gitlab::Llm::ResponseService) }
        let(:first_response_double) { double }
        let(:second_response_double) { double }

        before do
          allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with("In", { chunk_id: 1 })
            .and_return(first_response_double)

          allow(Gitlab::Llm::Chain::StreamedResponseModifier).to receive(:new).with("your", { chunk_id: 2 })
            .and_return(second_response_double)
        end

        it 'calls the stream_response_handler with the chunks' do
          expect_next_instance_of(
            ::Gitlab::Llm::AiGateway::DocsClient, user, namespace_id: nil, project_id: nil
          ) do |instance|
            expect(instance).to receive(:search).with(query: options[:input]).and_return(docs_search_response)
          end

          expect_next_instance_of(::Gitlab::Llm::Chain::Tools::EmbeddingsCompletion, **expected_params) do |instance|
            expect(instance).to receive(:execute).and_return(response).and_yield('In').and_yield('your')
          end

          expect(response_service).to receive(:execute).with(
            response: first_response_double,
            options: { chunk_id: 1 }
          )
          expect(response_service).to receive(:execute).with(
            response: second_response_double,
            options: { chunk_id: 2 }
          )
          expect(result.content).to eq("In your User settings.")
          expect(result.extras).to eq(sources: [])
        end
      end

      context 'when the question is not provided' do
        let(:options) { { input: "" } }

        it 'returns an empty response message' do
          response = "I'm sorry, I couldn't find any documentation to answer your question."

          expect(result.content).to eq(response)
          expect(result.error_code).to eq("M2000")
          expect(result.extras).to be_nil
        end
      end
    end

    context 'when context is not authorized' do
      before do
        allow(user).to receive(:can?).with(:access_duo_entry_point).and_return(false)
      end

      it 'responds with the message from TanukiBot' do
        response = "I'm sorry, I can't generate a response. You might want to try again. " \
          "You could also be getting this error because the items you're asking about " \
          "either don't exist, you don't have access to them, or your session has expired."

        expect(result.content).to eq(response)
        expect(result.error_code).to eq("M3003")
        expect(result.extras).to be_nil
      end
    end
  end

  describe '#name' do
    it 'returns tool name' do
      expect(described_class::NAME).to eq('GitlabDocumentation')
    end

    it 'returns tool human name' do
      expect(described_class::HUMAN_NAME).to eq('GitLab Documentation')
    end
  end
end
