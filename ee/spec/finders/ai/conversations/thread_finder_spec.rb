# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Conversations::ThreadFinder, :clean_gitlab_redis_shared_state, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:another_user) { create(:user) }

  let_it_be(:thread_1) { create(:ai_conversation_thread, user: user, last_updated_at: 1.day.ago) }
  let_it_be(:thread_2) { create(:ai_conversation_thread, user: user) }
  let_it_be(:thread_3) { create(:ai_conversation_thread, user: another_user) }

  let(:params) { {} }
  let(:redis) { Gitlab::Redis::SharedState.with { |redis| redis } }

  subject(:threads) { described_class.new(user, params).execute }

  it 'returns threads' do
    expect(threads).to eq([thread_2, thread_1])
  end

  context 'when filtering by id' do
    let(:params) { { id: thread_1.id } }

    it 'returns the thread' do
      expect(threads).to eq([thread_1])
    end
  end

  context 'when filtering by conversation_type' do
    let(:params) { { conversation_types: :duo_chat } }

    it 'returns threads' do
      expect(threads).to eq([thread_2, thread_1])
    end
  end
end
