# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ThreadEnsurer, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:organization) { create(:organization) }

  subject(:thread_ensurer) { described_class.new(user, organization) }

  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    where(:provide_thread_id, :conversation_type, :write_mode, :expected_thread_type) do
      false | nil              | true  | :legacy_thread
      false | nil              | false | :legacy_thread

      true  | nil              | true  | :find_thread
      true  | :duo_chat        | false | :find_thread
      true  | :duo_chat_legacy | false | :find_thread

      false | :duo_chat        | true  | :create_thread
      false | :duo_chat_legacy | true  | :create_thread

      false | :duo_chat        | false | :last_thread
      false | :duo_chat_legacy | false | :legacy_thread
    end

    with_them do
      let!(:expected_thread) do
        seed_params = {
          user: user,
          organization: organization,
          conversation_type: conversation_type || :duo_chat_legacy
        }

        thread1 = create(:ai_conversation_thread, **seed_params)
        thread2 = create(:ai_conversation_thread, **seed_params)

        case expected_thread_type
        when :find_thread
          thread1
        when :last_thread, :legacy_thread
          thread2
        end
      end

      let(:execute_result) do
        thread_ensurer.execute(
          thread_id: provide_thread_id ? expected_thread.id : nil,
          conversation_type: conversation_type,
          write_mode: write_mode
        )
      end

      it 'behaves correctly for the parameter combination' do
        expected_row_change = expected_thread_type == :create_thread ? 1 : 0

        expect { execute_result }.to change {
          user.ai_conversation_threads.for_conversation_type(conversation_type || :duo_chat_legacy).count
        }.by(expected_row_change)

        expect(execute_result.conversation_type.to_sym).to eq(
          conversation_type || :duo_chat_legacy
        )
      end
    end

    context 'when conversation_type is duo_chat_legacy but no thread exists' do
      it 'creates a legacy thread' do
        expect do
          thread_ensurer.execute(conversation_type: :duo_chat_legacy)
        end.to change { ::Ai::Conversation::Thread.duo_chat_legacy.count }.by(1)
      end
    end

    context 'when thread_id can not be found' do
      it 'raises error' do
        expect do
          thread_ensurer.execute(
            thread_id: -1,
            conversation_type: :duo_chat
          )
        end.to raise_error("Thread not found. It may have expired.")
      end
    end

    context 'when conversation_type is invalid' do
      it 'raises error' do
        expect do
          thread_ensurer.execute(
            thread_id: nil,
            conversation_type: :invalid_type,
            write_mode: true
          )
        end.to raise_error("Failed to create a thread for invalid_type.")
      end
    end
  end
end
