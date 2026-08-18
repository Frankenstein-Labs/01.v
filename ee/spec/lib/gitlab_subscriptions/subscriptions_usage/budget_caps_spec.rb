# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionsUsage::BudgetCaps, feature_category: :consumables_cost_management do
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }

  let(:subscription_usage) { instance_double(GitlabSubscriptions::SubscriptionUsage) }
  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

  subject(:budget_caps) { described_class.new(subscription_usage: subscription_usage) }

  before do
    allow(subscription_usage).to receive(:subscription_usage_client).and_return(subscription_usage_client)
  end

  describe '#subscription_cap' do
    before do
      allow(subscription_usage_client).to receive(:get_budget_caps).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) do
        { success: true, budgetControls: { subscription: { subscriptionCap: 500.0 } } }
      end

      it 'returns the subscription cap' do
        expect(budget_caps.subscription_cap).to eq(500.0)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(budget_caps.subscription_cap).to be_nil
      end
    end

    context 'when the response is missing subscription data' do
      let(:client_response) { { success: true, budgetControls: {} } }

      it 'returns nil' do
        expect(budget_caps.subscription_cap).to be_nil
      end
    end
  end

  describe '#subscription_cap_enabled' do
    before do
      allow(subscription_usage_client).to receive(:get_budget_caps).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) do
        { success: true, budgetControls: { subscription: { subscriptionCapEnabled: true } } }
      end

      it 'returns the enabled status' do
        expect(budget_caps.subscription_cap_enabled).to be(true)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(budget_caps.subscription_cap_enabled).to be_nil
      end
    end
  end

  describe '#flat_user_cap' do
    before do
      allow(subscription_usage_client).to receive(:get_budget_caps).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) do
        { success: true, budgetControls: { subscription: { flatUserCap: 100.0 } } }
      end

      it 'returns the flat user cap' do
        expect(budget_caps.flat_user_cap).to eq(100.0)
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:client_response) { { success: false } }

      it 'returns nil' do
        expect(budget_caps.flat_user_cap).to be_nil
      end
    end
  end

  describe '#flat_user_cap_enabled' do
    before do
      allow(subscription_usage_client).to receive(:get_budget_caps).and_return(client_response)
    end

    context 'when the client returns a successful response' do
      let(:client_response) do
        { success: true, budgetControls: { subscription: { flatUserCapEnabled: false } } }
      end

      it 'returns the enabled status' do
        expect(budget_caps.flat_user_cap_enabled).to be(false)
      end
    end
  end

  describe '#user_overrides' do
    let(:overrides_response) do
      {
        success: true,
        budgetControls: {
          userBudgetCapOverrides: {
            nodes: [
              {
                entityId: user1.id.to_s,
                cap: 150.0,
                capEnabled: true,
                createdAt: '2026-04-01T12:00:00Z',
                updatedAt: '2026-04-01T12:00:00Z'
              },
              {
                entityId: user2.id.to_s,
                cap: 200.0,
                capEnabled: false,
                createdAt: '2026-04-02T08:00:00Z',
                updatedAt: '2026-04-02T08:00:00Z'
              }
            ],
            pageInfo: {
              hasNextPage: true,
              hasPreviousPage: false,
              startCursor: 'start_cursor',
              endCursor: 'end_cursor'
            }
          }
        }
      }
    end

    before do
      allow(subscription_usage_client).to receive(:get_budget_caps).and_return(overrides_response)
    end

    it 'returns an ExternallyPaginatedArray' do
      result = budget_caps.user_overrides

      expect(result).to be_a(Gitlab::Graphql::ExternallyPaginatedArray)
    end

    it 'includes override nodes with correct data' do
      result = budget_caps.user_overrides

      expect(result.size).to eq(2)
      expect(result.first.entity_id).to eq(user1.id.to_s)
      expect(result.first.cap).to eq(150.0)
      expect(result.last.entity_id).to eq(user2.id.to_s)
      expect(result.last.cap).to eq(200.0)
    end

    it 'sets declarative_policy_subject on each override' do
      result = budget_caps.user_overrides

      result.each do |override|
        expect(override.declarative_policy_subject).to eq(subscription_usage)
      end
    end

    it 'preserves pagination info' do
      result = budget_caps.user_overrides

      expect(result.start_cursor).to eq('start_cursor')
      expect(result.end_cursor).to eq('end_cursor')
    end

    context 'with user_ids filter' do
      let(:user_gid) { ::Types::GlobalIDType[::User].coerce_isolated_input("gid://gitlab/User/#{user1.id}") }

      it 'converts GlobalIDs to entity_id strings' do
        expect(subscription_usage_client).to receive(:get_budget_caps)
          .with(entity_ids: [user1.id.to_s], args: {})
          .and_return(overrides_response)

        budget_caps.user_overrides(user_ids: [user_gid])
      end
    end

    context 'with pagination arguments' do
      it 'forwards first and after arguments' do
        expect(subscription_usage_client).to receive(:get_budget_caps)
          .with(entity_ids: nil, args: { first: 10, after: 'cursor123' })
          .and_return(overrides_response)

        budget_caps.user_overrides(first: 10, after: 'cursor123')
      end
    end

    context 'when the client returns an unsuccessful response' do
      let(:overrides_response) { { success: false } }

      it 'tracks the error and returns an empty page' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
          an_instance_of(StandardError),
          response: overrides_response
        )

        result = budget_caps.user_overrides

        expect(result).to be_a(Gitlab::Graphql::ExternallyPaginatedArray)
        expect(result).to be_empty
      end
    end

    context 'when overrides data is missing' do
      let(:overrides_response) { { success: true, budgetControls: {} } }

      it 'returns an empty page' do
        result = budget_caps.user_overrides

        expect(result).to be_a(Gitlab::Graphql::ExternallyPaginatedArray)
        expect(result).to be_empty
      end
    end

    context 'when nodes are empty' do
      let(:overrides_response) do
        { success: true, budgetControls: { userBudgetCapOverrides: { nodes: [] } } }
      end

      it 'returns an empty page' do
        result = budget_caps.user_overrides

        expect(result).to be_a(Gitlab::Graphql::ExternallyPaginatedArray)
        expect(result).to be_empty
      end
    end
  end

  describe '#declarative_policy_subject' do
    it 'delegates to subscription_usage' do
      expect(budget_caps.declarative_policy_subject).to eq(subscription_usage)
    end
  end

  describe 'strong memoization' do
    let(:client_response) do
      { success: true, budgetControls: { subscription: { subscriptionCap: 500.0 } } }
    end

    before do
      allow(subscription_usage_client).to receive(:get_budget_caps).and_return(client_response)
    end

    it 'memoizes subscription_data across multiple field accesses' do
      budget_caps.subscription_cap
      budget_caps.subscription_cap_enabled

      expect(subscription_usage_client).to have_received(:get_budget_caps).once
    end
  end
end
