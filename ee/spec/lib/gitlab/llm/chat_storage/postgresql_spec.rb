# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ChatStorage::Postgresql, :clean_gitlab_redis_chat, feature_category: :duo_chat do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:request_id) { 'uuid' }
  let(:payload) do
    {
      request_id: request_id,
      errors: ['some error1', 'another error'],
      role: 'user',
      content: 'response',
      user: user,
      thread: thread,
      referer_url: 'http://127.0.0.1:3000',
      additional_context: Gitlab::Llm::AiMessageAdditionalContext.new(
        [
          { category: 'file', id: 'file.rb', content: 'puts "code"' }
        ]
      )
    }
  end

  let(:payload_active_record) do
    {
      request_id: request_id,
      error_details: ['some error1', 'another error'].to_json,
      role: 'user',
      content: 'response',
      thread: thread,
      referer_url: 'http://127.0.0.1:3000',
      extras: {
        additional_context:
          [
            { category: 'file', id: 'file.rb', content: 'puts "code"' }
          ]
      }.to_json
    }
  end

  let_it_be(:thread, freeze: false) { create(:ai_conversation_thread, user: user, organization: organization) }

  subject(:storage) { described_class.new(user, thread) }

  describe '#add' do
    let(:message) { build(:ai_chat_message, payload) }

    it 'adds new message to Postgresql', :aggregate_failures do
      uuid = 'unique_id'

      allow(SecureRandom).to receive(:uuid).and_return(uuid)
      expect(storage.messages).to be_empty

      result = storage.add(message)

      last = storage.messages.last
      expect(last.message_xid).to eq(uuid)
      expect(last.user).to eq(user)
      expect(last.request_id).to eq(request_id)
      expect(last.error_details).to match_array(['some error1', 'another error'])
      expect(last.content).to eq('response')
      expect(last.role).to eq('user')
      expect(last.ai_action).to eq('chat')
      expect(last.timestamp).not_to be_nil
      expect(last.referer_url).to eq('http://127.0.0.1:3000')
      expect(last.extras['additional_context']).to eq(payload[:additional_context].to_a)

      expect(result).to be_a(Ai::Conversation::Message)
      expect(result).to eq(last)
    end

    context 'when the content exceeds the text limit' do
      before do
        stub_const("::Gitlab::Llm::ChatStorage::Base::MAX_TEXT_LIMIT", 3)
      end

      it 'truncates the message content to MAX_TEXT_LIMIT' do
        storage.add(build(:ai_chat_message, payload.merge(content: 'msg1')))

        expect(storage.messages.last.content).to eq('msg')
      end
    end

    context 'when thread is nil' do
      subject(:storage) { described_class.new(user) }

      it 'raises error' do
        expect do
          storage.add(build(:ai_chat_message, payload.merge(content: 'msg1')))
        end.to raise_error('thread_absent')
      end
    end
  end

  describe '#messages' do
    before do
      create(:ai_conversation_message, payload_active_record.merge(content: 'msg1'))
      create(:ai_conversation_message, payload_active_record.merge(content: 'msg2'))
    end

    it 'retrieves all stored messages' do
      results = storage.messages

      expect(results).to all(be_an(Ai::Conversation::Message))
      expect(results.map(&:content)).to eq(%w[msg1 msg2])
    end

    context 'when the count of messages exceed the limit' do
      before do
        stub_const('Gitlab::Llm::ChatStorage::Postgresql::MAX_MESSAGES', 1)
      end

      it 'retrieves messages within the max limit' do
        expect(storage.messages.map(&:content)).to eq(%w[msg2])
      end
    end
  end

  describe '#clear!' do
    it 'creates a new thread' do
      storage.add(build(:ai_chat_message, payload.merge(content: 'msg1')))
      storage.add(build(:ai_chat_message, payload.merge(content: 'msg2')))

      expect(storage.messages.count).to eq(2)

      expect { storage.clear! }.to change { user.ai_conversation_threads.count }.by(1)

      expect(storage.messages).to be_empty
    end

    context 'when thread is nil' do
      subject(:storage) { described_class.new(user) }

      it 'raises error' do
        expect do
          storage.clear!
        end.to raise_error('thread_absent')
      end
    end
  end

  describe '#current_thread' do
    it 'returns the specified thread' do
      expect(storage.current_thread).to eq(thread)
    end
  end
end
