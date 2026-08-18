# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageUsersUsage'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageUsersUsage') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([
      :total_active_users,
      :total_users_using_credits,
      :total_users_using_monthly_commitment,
      :total_users_using_overage,
      :credits_used,
      :daily_usage,
      :users
    ])
  end

  it 'sets max_page_size of 20 to users field' do
    expect(described_class.fields['users'].max_page_size).to eq(20)
  end

  describe 'users field arguments' do
    it 'has username argument' do
      expect(described_class.fields['users'].arguments['username'].type.to_type_signature).to eq('String')
    end

    it 'has sort argument with GitlabSubscriptionsUserSort type' do
      expect(described_class.fields['users'].arguments['sort'].type.to_type_signature)
        .to eq('GitlabSubscriptionUsageUserSort')
    end
  end

  describe '#total_active_users' do
    let(:user_usage) { instance_double(GitlabSubscriptions::SubscriptionsUsage::UserUsage) }
    let(:context) { { flow_types: %w[chat] } }
    let(:type) { described_class.send(:new, user_usage, context) }

    it 'passes flow_types from context to the model' do
      expect(user_usage).to receive(:total_active_users).with(flow_types: %w[chat])
      type.total_active_users
    end
  end

  describe '#users' do
    let(:user_usage) { instance_double(GitlabSubscriptions::SubscriptionsUsage::UserUsage) }
    let(:context) { { flow_types: %w[chat] } }
    let(:type) { described_class.send(:new, user_usage, context) }

    it 'passes flow_types from context to the model' do
      expect(user_usage).to receive(:users).with(
        search_query: nil,
        sort: nil,
        username: nil,
        first: nil,
        last: nil,
        after: nil,
        before: nil,
        flow_types: %w[chat]
      )
      type.users
    end

    it 'passes sort and username along with flow_types' do
      expect(user_usage).to receive(:users).with(
        search_query: nil,
        sort: :name_asc,
        username: 'alice',
        first: nil,
        last: nil,
        after: nil,
        before: nil,
        flow_types: %w[chat]
      )
      type.users(sort: :name_asc, username: 'alice')
    end

    it 'passes pagination params to the model' do
      expect(user_usage).to receive(:users).with(
        search_query: nil,
        sort: nil,
        username: nil,
        first: 20,
        last: nil,
        after: 'cursor123',
        before: nil,
        flow_types: %w[chat]
      )
      type.users(first: 20, after: 'cursor123')
    end
  end
end
