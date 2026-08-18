# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SeatUsageHistoryExportService, feature_category: :seat_cost_management do
  let(:group) { build_stubbed(:group) }
  let(:user) { build_stubbed(:user) }
  let(:subscription_histories) { GitlabSubscriptions::SubscriptionHistory.none }
  let(:subscription_history) do
    build_stubbed(
      :gitlab_subscription_history,
      namespace: group,
      start_date: 1.year.ago,
      end_date: Time.now.utc,
      seats: 10,
      seats_in_use: 8,
      max_seats_used: 12,
      change_type: :gitlab_subscription_updated
    )
  end

  subject(:result) { described_class.new(group.gitlab_subscription_histories).csv_data }

  context 'when group has subscription histories' do
    it 'returns csv data' do
      expect(subscription_histories).to receive(:preload).and_return([subscription_history])
      expect(group).to receive(:gitlab_subscription_histories).and_return(subscription_histories)

      expect(result).to eq(
        "History entry date,Subscription updated at,Start date,End date," \
          "Seats purchased,Seats in use,Max seats used,Change Type\n" \
          "#{subscription_history.created_at},#{subscription_history.gitlab_subscription_updated_at}," \
          "#{subscription_history.start_date},#{subscription_history.end_date}," \
          "#{subscription_history.seats},#{subscription_history.seats_in_use}," \
          "#{subscription_history.max_seats_used},#{subscription_history.change_type}\n"
      )
    end
  end

  context 'when group has no subscription history' do
    it 'returns only headers' do
      expect(group).to receive(:gitlab_subscription_histories).and_return(subscription_histories)

      expect(result).to eq(
        "History entry date,Subscription updated at,Start date,End date," \
          "Seats purchased,Seats in use,Max seats used,Change Type\n" \
      )
    end
  end
end
