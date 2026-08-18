# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Answer, feature_category: :duo_chat do
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:project) { build_stubbed(:project) }

  let(:tools) { [Gitlab::Llm::Chain::Tools::IssueReader] }
  let(:tool_double) { instance_double(Gitlab::Llm::Chain::Tools::IssueReader::Executor) }
  let(:request_id) { 'uuid' }
  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::Anthropic) }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user,
      container: project,
      resource: nil,
      ai_request: ai_request_double,
      request_id: request_id
    )
  end

  let(:input) do
    <<-INPUT
      Thought: thought
      Action: IssueReader
      Action Input: Bar
    INPUT
  end

  describe '.from_response' do
    subject(:answer) { described_class.from_response(response_body: input, tools: tools, context: context) }

    before do
      allow(Gitlab::Llm::Chain::Tools::IssueReader::Executor).to receive(:new).and_return(tool_double)
    end

    it 'returns intermediate answer with parsed values and a tool' do
      expect(answer.is_final?).to be(false)
      expect(answer.tool::NAME).to eq('IssueReader')
    end

    context 'when parsed response is final' do
      it 'returns final answer' do
        allow_next_instance_of(Gitlab::Llm::Chain::Parsers::ChainOfThoughtParser) do |parser|
          allow(parser).to receive(:final_answer).and_return(true)
        end

        expect(answer.is_final?).to be(true)
      end
    end

    context 'when tool is nil' do
      let(:input) do
        <<-INPUT
          Thought: thought
          Action: Nil
          Action Input: Bar
        INPUT
      end

      it 'returns final answer with default response' do
        expect(answer.is_final?).to be(true)
        expect(answer.content).to eq(described_class.default_final_message)
      end
    end

    context 'when response is empty' do
      let(:input) { '' }

      it 'returns final answer with default response' do
        expect(answer.is_final?).to be(true)
        expect(answer.content).to eq(described_class.default_final_message)
      end
    end

    context 'when response is empty but framed into thought' do
      let(:input) { 'Thought: ' }

      it 'returns final answer with default response' do
        expect(answer.is_final?).to be(true)
        expect(answer.content).to eq(described_class.default_final_message)
      end
    end

    context 'when response is empty but framed into action' do
      let(:input) { 'Action: ' }

      it 'returns final answer with default response' do
        expect(answer.is_final?).to be(true)
        expect(answer.content).to eq(described_class.default_final_message)
      end
    end

    context 'when tool does not contain any of expected keyword' do
      let(:input) { 'Here is my freestyle answer.' }

      it 'returns final answer with default response' do
        expect(answer.is_final?).to be(true)
        expect(answer.content).to eq(input)
      end
    end
  end

  describe '.final_answer' do
    subject(:answer) { described_class.final_answer(context: context, content: "yay!") }

    it 'returns final answer with correct response' do
      expect(answer.is_final?).to be(true)
      expect(answer.content).to eq("yay!")
      expect(answer.tool).to be_nil
      expect(answer.status).to eq(:ok)
    end
  end

  describe '.error_answer' do
    subject(:answer) do
      described_class.error_answer(
        context: context,
        content: "error",
        error_code: error_code,
        error: error,
        source: "chat_v2"
      )
    end

    let(:error_code) { nil }
    let(:error) { StandardError.new('hello world') }

    context 'when the answer has no error code' do
      it 'returns final answer with error response' do
        expect(answer.is_final?).to be(true)
        expect(answer.content).to eq("error")
        expect(answer.tool).to be_nil
        expect(answer.status).to eq(:error)
        expect(answer.error_code).to be_nil
      end
    end

    context 'when answer has an error code' do
      let(:error_code) { "A2000" }
      let(:logger) { instance_double(Gitlab::Llm::Logger) }

      before do
        allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
        allow(logger).to receive(:error)
      end

      it 'tracks the error code' do
        expect(answer.content).to eq("error")
        expect(answer.status).to eq(:error)
        expect(answer.error_code).to eq(error_code)
      end

      it 'logs the error code' do
        answer

        expect(logger).to have_received(:error).with(a_hash_including(error: "error", duo_chat_error_code: error_code,
          message: 'hello world', source: "chat_v2"))
      end

      context 'when error has no message' do
        let(:error) { StandardError.new }

        it 'logs the error code' do
          answer

          expect(logger).to have_received(:error).with(a_hash_including(error: "error", duo_chat_error_code: error_code,
            message: 'StandardError', source: "chat_v2"))
        end
      end

      context 'when error is not passed' do
        subject(:answer) do
          described_class.error_answer(
            context: context,
            content: "error",
            error_code: error_code
          )
        end

        it 'logs the error code' do
          answer

          expect(logger).to have_received(:error).with(
            a_hash_including(message: "Error", error: "error", duo_chat_error_code: error_code, source: "unknown")
          )
        end
      end
    end

    it 'tracks a snowplow event' do
      answer

      expect_snowplow_event(
        category: described_class.to_s,
        action: 'error_answer',
        property: 'uuid',
        label: 'gitlab_duo_chat_answer',
        user: user,
        project: project,
        namespace: project.namespace
      )
    end
  end

  describe '.default_final_answer' do
    subject(:answer) { described_class.default_final_answer(context: context) }

    let(:expected_response) do
      "I'm sorry, I couldn't respond in time. Please try a more specific request or enter /clear to start a new chat."
    end

    it 'returns final answer with the default response' do
      expect(answer.is_final?).to be(true)
      expect(answer.content).to eq(expected_response)
      expect(answer.tool).to be_nil
      expect(answer.status).to eq(:ok)
    end

    it 'tracks a snowplow event' do
      answer

      expect_snowplow_event(
        category: described_class.to_s,
        action: 'default_answer',
        property: 'uuid',
        label: 'gitlab_duo_chat_answer',
        user: user,
        project: project,
        namespace: project.namespace
      )
    end
  end
end
