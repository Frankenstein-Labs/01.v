# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Conversation::CleanupService, feature_category: :duo_chat do
  describe '#execute' do
    let(:service) { described_class.new }

    context 'when there are expired threads' do
      let_it_be(:expired_thread) { create(:ai_conversation_thread, :expired) }
      let_it_be(:active_thread) { create(:ai_conversation_thread) }
      let_it_be(:setting) { create(:application_setting) }

      it 'deletes all expired threads' do
        expect(Ai::Conversation::Thread).to receive(:expired).with(
          setting.duo_chat_expiration_column,
          setting.duo_chat_expiration_days
        ).and_call_original

        expect { service.execute }.to change { Ai::Conversation::Thread.count }.from(2).to(1)

        expect(Ai::Conversation::Thread.exists?(expired_thread.id)).to be false
        expect(Ai::Conversation::Thread.exists?(active_thread.id)).to be true
      end
    end
  end
end
