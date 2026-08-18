# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::LastCodeSuggestionUsageService, feature_category: :duo_chat do
  subject(:service_response) do
    described_class.new(
      current_user,
      user_ids: user_ids,
      from: from,
      to: to
    ).execute
  end

  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:unmatched_user) { create(:user) }

  let(:current_user) { user1 }
  let(:user_ids) { [user1.id, user2.id] }
  let(:from) { Time.zone.now }
  let(:to) { Time.zone.now }

  before do
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
  end

  context 'when the clickhouse is not available for analytics' do
    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
    end

    it 'returns service error' do
      expect(service_response).to be_error

      message = s_('AiAnalytics|the ClickHouse data store is not available')
      expect(service_response.message).to eq(message)
    end
  end

  context 'when the feature is available', :click_house, :freeze_time do
    let(:from) { 14.days.ago }
    let(:to) { 1.day.ago }

    before do
      clickhouse_fixture(:ai_usage_events, [
        { user_id: user1.id, event: 1, timestamp: to - 3.days },
        { user_id: user1.id, event: 1, timestamp: to - 4.days },
        { user_id: user1.id, event: 1, timestamp: to + 1.day },
        { user_id: user1.id, event: 1, timestamp: from - 1.day },
        { user_id: user2.id, event: 1, timestamp: to - 2.days },
        { user_id: unmatched_user.id, event: 1, timestamp: to - 2.days }
      ])
    end

    it 'returns last code suggestion day matched to filters grouped by user' do
      expect(service_response).to be_success
      expect(service_response.payload).to match({
        user1.id => 4.days.ago.to_date,
        user2.id => 3.days.ago.to_date
      })
    end
  end
end
