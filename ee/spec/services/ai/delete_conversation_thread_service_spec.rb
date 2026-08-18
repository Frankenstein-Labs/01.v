# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DeleteConversationThreadService, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be_with_refind(:thread) { create(:ai_conversation_thread, user: user) }

  let(:current_user) { user }

  describe '#execute' do
    subject(:result) { described_class.new(current_user: current_user).execute(thread) }

    context 'when user owns the thread' do
      it { is_expected.to be_success }

      it 'deletes the thread' do
        create(:ai_conversation_message, thread: thread)
        create(:ai_conversation_message, thread: thread)

        expect { result }
          .to change { Ai::Conversation::Thread.count }.by(-1)
      end

      context 'when destroy fails' do
        before do
          allow(thread).to receive(:destroy).and_return(false)
          thread.errors.add(:base, 'something went wrong')
        end

        it { is_expected.to be_error }

        it 'returns error messages' do
          expect(result.message).to contain_exactly('something went wrong')
        end
      end
    end

    context 'when user does not own the thread' do
      let(:current_user) { other_user }

      it { is_expected.to be_error }

      it 'returns error message' do
        expect(result.message).to eq('User not authorized to delete thread')
      end

      it 'does not delete the thread' do
        expect { result }.not_to change { Ai::Conversation::Thread.count }
      end
    end
  end
end
