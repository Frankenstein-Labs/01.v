# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Utils::ChatConversation, feature_category: :duo_chat do
  describe "#truncated_conversation_list" do
    subject(:conversation) { described_class.new(user, thread).truncated_conversation_list }

    let_it_be(:organization) { create(:organization) }
    let(:user) { create(:user, organizations: [organization]) }
    let(:thread) { create(:ai_conversation_thread, user: user) }

    before do
      allow(::Gitlab::Llm::ChatStorage).to receive(:last_conversation).and_return(messages)
    end

    context "with different messages" do
      let(:messages) do
        [
          build(:ai_chat_message, request_id: "uuid1", content: "question 1"),
          build(:ai_chat_message, request_id: "uuid2", content: "question 2"),
          build(:ai_chat_message, request_id: "uuid3", content: "question 3"),
          build(:ai_chat_message, request_id: "uuid4", content: "question 4"),
          build(:ai_chat_message, :assistant, request_id: "uuid3", errors: ["error"], content: "answer 3"),
          build(:ai_chat_message, :assistant, request_id: "uuid2", content: "answer 2"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: "answer 1")
        ]
      end

      let(:history) { conversation.pluck(:content) }

      it "returns only successful conversations in a right order" do
        expect(history).to contain_exactly("question 1", "answer 1", "question 2", "answer 2")
      end

      context "with limit on messages" do
        subject(:conversation) { described_class.new(user, thread).truncated_conversation_list(last_n: 3) }

        it "returns exact number of messages" do
          expect(history).to contain_exactly("answer 1", "question 2", "answer 2")
        end
      end

      context "with more messages than default limit" do
        before do
          stub_const("#{described_class}::LAST_N_MESSAGES", 3)
        end

        it "returns exact number of messages" do
          expect(history).to contain_exactly("answer 1", "question 2", "answer 2")
        end
      end
    end

    context "with empty history" do
      let(:messages) { [] }

      it "returns an empty conversation" do
        expect(conversation).to be_empty
      end
    end

    context "with nil message" do
      let(:messages) do
        [
          build(:ai_chat_message, request_id: "uuid1", content: "question 1"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: nil),
          build(:ai_chat_message, request_id: "uuid1", content: "question 2"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: "answer 2")
        ]
      end

      let(:history) { conversation.pluck(:content) }

      it "returns only successful conversations in a right order" do
        expect(history).to contain_exactly("question 2", "answer 2")
      end
    end

    context "with empty message" do
      let(:messages) do
        [
          build(:ai_chat_message, request_id: "uuid1", content: "question 1"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: ""),
          build(:ai_chat_message, request_id: "uuid1", content: "question 2"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: "answer 2")
        ]
      end

      let(:history) { conversation.pluck(:content) }

      it "returns only successful conversations in a right order" do
        expect(history).to contain_exactly("question 2", "answer 2")
      end
    end

    context "with duplicating roles message" do
      let(:messages) do
        [
          build(:ai_chat_message, request_id: "uuid1", content: "question 1"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: "answer 1"),
          build(:ai_chat_message, request_id: "uuid1", content: "question 2"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: "answer 2"),
          build(:ai_chat_message, :assistant, request_id: "uuid1", content: "answer 3")
        ]
      end

      let(:history) { conversation.pluck(:content) }

      it "returns only successful conversations in a right order" do
        expect(history).to contain_exactly("question 1", "answer 1", "question 2", "answer 3")
      end
    end

    context "with the last user message" do
      let(:messages) do
        [
          build(:ai_chat_message, :assistant, request_id: nil, content: 'comment 1'),
          build(:ai_chat_message, request_id: nil, content: "follow up question")
        ]
      end

      let(:history) { conversation.pluck(:content) }

      it "does not include the last user message" do
        expect(history).to contain_exactly("comment 1")
      end
    end

    context "with the last assistant message" do
      let(:messages) do
        [
          build(:ai_chat_message, request_id: nil, content: "question 1"),
          build(:ai_chat_message, :assistant, request_id: nil, content: 'answer 1')
        ]
      end

      let(:history) { conversation.pluck(:content) }

      it "does not remove the last assistant message" do
        expect(history).to contain_exactly("question 1", "answer 1")
      end
    end

    context "with messages containing all fields" do
      let(:messages) do
        [
          build(:ai_chat_message,
            request_id: "uuid1",
            content: "Question",
            extras: { 'additional_context' => additional_context }
          ),
          build(:ai_chat_message, :assistant,
            request_id: "uuid1",
            content: "Answer",
            extras: {
              'additional_context' => [],
              'agent_scratchpad' => agent_scratchpad
            }
          )
        ]
      end

      let(:agent_scratchpad) do
        [{ thought: 'thought', observation: 'Please use this information about identified issue' }]
      end

      let(:additional_context) do
        [
          { category: 'SNIPPET', id: 'hello world', content: 'puts "Hello, world"', metadata: {} }
        ]
      end

      it "returns messages with all fields" do
        expect(conversation).to contain_exactly(
          {
            role: :user,
            content: "Question",
            additional_context: additional_context,
            agent_scratchpad: nil
          },
          {
            role: :assistant,
            content: "Answer",
            additional_context: [],
            agent_scratchpad: agent_scratchpad
          }
        )
      end
    end
  end
end
