# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::GitlabSubscriptions::TrialUsage::UserType, feature_category: :consumables_cost_management do
  let_it_be(:user) { create(:user, name: 'Test User', username: 'testuser') }

  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

  it 'has the expected fields' do
    expected_fields = %w[
      avatarUrl
      id
      name
      usage
      username
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe 'UserUsage struct' do
    it 'has the expected structure' do
      user_usage = described_class::UserUsage.new(
        total_credits: 10.0,
        credits_used: 5.0,
        declarative_policy_subject: user
      )

      expect(user_usage.total_credits).to eq(10.0)
      expect(user_usage.credits_used).to eq(5.0)
      expect(user_usage.declarative_policy_subject).to eq(user)
    end
  end
end
