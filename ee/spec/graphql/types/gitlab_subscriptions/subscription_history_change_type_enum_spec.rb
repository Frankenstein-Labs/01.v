# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['SubscriptionHistoryChangeType'], feature_category: :seat_cost_management do
  it 'exposes the correct subscription history change types' do
    expect(described_class.values.keys)
      .to match_array(%w[GITLAB_SUBSCRIPTION_UPDATED GITLAB_SUBSCRIPTION_DESTROYED])
  end
end
