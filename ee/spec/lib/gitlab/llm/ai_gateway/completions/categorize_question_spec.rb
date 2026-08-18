# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::CategorizeQuestion, feature_category: :duo_chat do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:ai_conversation_thread) { create(:ai_conversation_thread, user: user) }
  let_it_be(:ai_conversation_message) { create(:ai_conversation_message, thread: ai_conversation_thread) }
  let_it_be(:question) { 'What is the pipeline?' }
  let(:chat_message) do
    message = build(:ai_chat_message, content: question, id: ai_conversation_message.message_xid)
    message.active_record = ai_conversation_message
    message.thread = ai_conversation_thread
    message
  end

  let(:template_class) { ::Gitlab::Llm::Templates::CategorizeQuestion }
  let(:ai_client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:ai_response) { instance_double(HTTParty::Response, body: llm_analysis_response.to_json, success?: true) }
  let(:uuid) { SecureRandom.uuid }
  let(:tracking_context) { { action: :categorize_question, request_id: uuid } }
  let(:messages) { [chat_message] }
  let(:message_id) { chat_message.id }
  let(:ai_options) { { question: chat_message.content, message_id: message_id } }
  let(:prompt_message) { build(:ai_message, :categorize_question, user: user, request_id: uuid) }
  let(:llm_analysis_response) do
    {
      detailed_category: "Summarize Issue",
      category: 'Summarize something',
      labels: %w[contains_code is_related_to_gitlab],
      language: 'en',
      extra: 'foo'
    }.to_json
  end

  let(:model_metadata) { { provider: 'gitlab', feature_setting: 'duo_chat', identifier: nil } }

  before do
    allow_next_instance_of(::Gitlab::Llm::ChatStorage, user, chat_message.thread) do |storage|
      allow(storage).to receive(:messages_up_to).with(chat_message.id).and_return(messages)
    end
  end

  def expect_client
    expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
      user,
      unit_primitive_name: :duo_classic_chat,
      tracking_context: tracking_context,
      namespace_id: nil,
      project_id: nil,
      governing_namespace_id: nil
    ).and_return(ai_client)
    expect(ai_client).to receive(:complete_prompt).with(
      base_url: Gitlab::AiGateway.url,
      prompt_name: :categorize_question,
      inputs: inputs,
      model_metadata: model_metadata,
      prompt_version: "^1.0.0",
      timeout: Gitlab::AiGateway.timeout
    ).and_return(ai_response)

    expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original
  end

  describe "#execute" do
    let(:inputs) do
      {
        previous_answer: nil,
        question: question
      }
    end

    subject(:execute) { described_class.new(prompt_message, template_class, ai_options).execute }

    it 'executes a completion request and calls the response chains' do
      expect_client
      expect(execute[:ai_message].errors).to be_empty

      expect_snowplow_event(
        category: described_class.to_s,
        action: 'ai_question_category',
        requestId: uuid,
        user: user,
        context: [{
          schema: described_class::SCHEMA_URL,
          data: {
            'detailed_category' => "Summarize Issue",
            'category' => "Summarize something",
            'contains_code' => true,
            'is_related_to_gitlab' => true,
            'number_of_conversations' => 1,
            'number_of_questions_in_conversation' => 1,
            'length_of_questions_in_conversation' => 21,
            'length_of_questions' => 21,
            'first_question_after_reset' => false,
            'time_since_beginning_of_conversation' => 0,
            'language' => "en"
          }
        }]
      )
    end

    context 'when previous answer is present' do
      let(:previous_answer) { build(:ai_chat_message, :assistant, content: '<answer>') }
      let(:messages) { [previous_answer, chat_message] }

      let(:inputs) do
        {
          previous_answer: previous_answer.content,
          question: question
        }
      end

      it 'includes previous answer as input' do
        expect_client
        expect(execute[:ai_message].errors).to be_empty
      end
    end

    context 'when no attributes are returned' do
      let(:llm_analysis_response) do
        {}.to_json
      end

      it 'returns error message' do
        expect_client
        expect(execute[:ai_message].errors).to include('Event not tracked')
      end
    end

    context 'when the AI Gateway response is unsuccessful' do
      let(:ai_response) { instance_double(HTTParty::Response, body: '', success?: false) }

      it 'returns the error without tracking an event', :aggregate_failures do
        expect_client

        result = execute

        expect(result[:ai_message].errors).to include('An unexpected error has occurred.')
        expect_no_snowplow_event(category: described_class.to_s)
      end
    end

    context 'when a successful AI Gateway response has non-String content' do
      let(:logger) { instance_double(Gitlab::Llm::Logger) }
      let(:ai_response) do
        instance_double(HTTParty::Response, body: { content: { unexpected: 'shape' } }.to_json, success?: true)
      end

      before do
        allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      end

      it 'returns the default error without tracking an event', :aggregate_failures do
        expect_client
        expect(logger).to receive(:error).with(a_hash_including(
          message: 'Expected response content to be a String, got Hash instead',
          event_name: 'error',
          ai_component: 'duo_chat'
        )).once

        result = execute

        expect(result[:ai_message].errors).to include('An unexpected error has occurred.')
        expect_no_snowplow_event(category: described_class.to_s)
      end
    end

    context 'when a successful AI Gateway response contains unparseable prose' do
      let(:logger) { instance_double(Gitlab::Llm::Logger) }
      let(:prose_response) { "Here is a plain text answer.\nIt is not JSON." }
      let(:ai_response) do
        instance_double(HTTParty::Response, body: { content: prose_response }.to_json, success?: true)
      end

      before do
        allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      end

      it 'logs and returns the default error without tracking an event', :aggregate_failures do
        expect_client
        expect(logger).to receive(:error).with(a_hash_including(
          message: 'Response was not valid JSON',
          event_name: 'error',
          ai_component: 'duo_chat'
        )).once
        expect(logger).not_to receive(:error).with(a_hash_including(
          message: 'Expected response content to be a Hash, got String instead'
        ))

        result = execute

        expect(result[:ai_message].errors).to include('An unexpected error has occurred.')
        expect_no_snowplow_event(category: described_class.to_s)
      end
    end

    context 'when a successful AI Gateway response contains a JSON array' do
      let(:logger) { instance_double(Gitlab::Llm::Logger) }
      let(:ai_response) do
        instance_double(HTTParty::Response, body: { content: '[1,2]' }.to_json, success?: true)
      end

      before do
        allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      end

      it 'returns the default error without tracking an event', :aggregate_failures do
        expect_client
        expect(logger).to receive(:error).with(a_hash_including(
          message: 'Expected response content to be a Hash, got Array instead',
          event_name: 'error',
          ai_component: 'duo_chat'
        )).once

        result = execute

        expect(result[:ai_message].errors).to include('An unexpected error has occurred.')
        expect_no_snowplow_event(category: described_class.to_s)
      end
    end

    context 'when a successful AI Gateway response matches the default error detail' do
      let(:logger) { instance_double(Gitlab::Llm::Logger) }
      let(:content) { { detail: 'An unexpected error has occurred.' }.to_json }
      let(:ai_response) do
        instance_double(HTTParty::Response, body: { content: content }.to_json, success?: true)
      end

      before do
        allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
        allow(logger).to receive(:error)
      end

      it 'attempts to track the parsed response', :aggregate_failures do
        expect_client
        expect(logger).not_to receive(:error).with(a_hash_including(
          message: 'Response was not valid JSON'
        ))

        result = execute

        expect(result[:ai_message].errors).to include('Event not tracked')
        expect_no_snowplow_event(category: described_class.to_s)
      end
    end

    context 'when a successful AI Gateway response contains scalar labels' do
      let(:ai_response) do
        content = {
          category: 'Summarize something',
          detailed_category: 'Summarize Issue',
          labels: 1,
          language: 'en'
        }.to_json

        instance_double(HTTParty::Response, body: { content: content }.to_json, success?: true)
      end

      it 'skips the labels and tracks the categorization', :aggregate_failures do
        expect_client

        result = execute

        expect(result[:ai_message].errors).to be_empty
        expect_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          requestId: uuid,
          user: user,
          context: [{
            schema: described_class::SCHEMA_URL,
            data: {
              'detailed_category' => 'Summarize Issue',
              'category' => 'Summarize something',
              'number_of_conversations' => 1,
              'number_of_questions_in_conversation' => 1,
              'length_of_questions_in_conversation' => 21,
              'length_of_questions' => 21,
              'first_question_after_reset' => false,
              'time_since_beginning_of_conversation' => 0,
              'language' => 'en'
            }
          }]
        )
      end
    end

    context 'with invalid attributes' do
      let(:llm_analysis_response) do
        {
          detailed_category: "Foo Bar",
          category: 'Foo Bar',
          labels: %w[contains_code is_related_to_gitlab foo_bar],
          language: 'FooBar',
          extra: 'foo'
        }.to_json
      end

      it 'tracks event, replacing invalid attributes' do
        expect_client
        expect(execute[:ai_message].errors).to be_empty

        expect_snowplow_event(
          category: described_class.to_s,
          action: 'ai_question_category',
          requestId: uuid,
          user: user,
          context: [{
            schema: described_class::SCHEMA_URL,
            data: {
              'detailed_category' => "[Invalid]",
              'category' => "[Invalid]",
              'contains_code' => true,
              'is_related_to_gitlab' => true,
              'number_of_conversations' => 1,
              'number_of_questions_in_conversation' => 1,
              'length_of_questions_in_conversation' => 21,
              'length_of_questions' => 21,
              'first_question_after_reset' => false,
              'time_since_beginning_of_conversation' => 0,
              'language' => "[Invalid]"
            }
          }]
        )
      end
    end

    context 'when message_id no longer exists' do
      let(:message_id) { nil }

      it 'raises error' do
        expect(Gitlab::Llm::AiGateway::Client).not_to receive(:new)
        expect(execute).to be_nil
      end
    end
  end
end
