# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageUser'], feature_category: :consumables_cost_management do
  include GraphqlHelpers

  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageUser') }
  it { expect(described_class).to require_graphql_authorizations(:read_user) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields(
      %i[avatar_url blocked_status entity_type id name username usage used_flow_types events]
    )
  end

  describe '#used_flow_types' do
    let_it_be(:user) { create(:user) }

    let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
    let(:context) { { current_user: user, subscription_usage_client: subscription_usage_client } }
    let(:user_type) do
      described_class.send(:new, user, context)
    end

    context 'when the client returns flow types' do
      let(:client_response) do
        {
          success: true,
          usedFlowTypes: [
            { id: 'code_suggestions', title: 'Code Suggestions' },
            { id: 'agentic_chat', title: 'Agentic Chat' }
          ]
        }
      end

      it 'returns FlowTypeInfo structs' do
        allow(subscription_usage_client).to receive(:get_used_flow_types_for_user_id)
          .with(user.id)
          .and_return(client_response)

        result = batch_sync { user_type.used_flow_types }

        expect(result).to contain_exactly(
          having_attributes(id: 'code_suggestions', title: 'Code Suggestions'),
          having_attributes(id: 'agentic_chat', title: 'Agentic Chat')
        )
      end
    end

    context 'when the client returns no flow types' do
      let(:client_response) { { success: true, usedFlowTypes: nil } }

      it 'returns nil' do
        allow(subscription_usage_client).to receive(:get_used_flow_types_for_user_id)
          .with(user.id)
          .and_return(client_response)

        result = batch_sync { user_type.used_flow_types }

        expect(result).to be_nil
      end
    end

    context 'when multiple user_ids are batched' do
      let_it_be(:other_user) { create(:user) }

      let(:other_user_type) { described_class.send(:new, other_user, context) }

      it 'returns nil because it only resolves for a single user' do
        expect(subscription_usage_client).not_to receive(:get_used_flow_types_for_user_id)

        result = batch_sync do
          user_type.used_flow_types
          other_user_type.used_flow_types
        end

        expect(result).to be_nil
      end
    end
  end

  describe '#entity_type' do
    let(:context) { instance_double(GraphQL::Query::Context) }
    let(:user_type) { described_class.send(:new, user, context) }

    context 'when user is a UserWithConsumption' do
      let(:user) do
        ::GitlabSubscriptions::SubscriptionsUsage::UserWithConsumption.new(
          build(:user),
          { entityType: 'NON_HUMAN' }
        )
      end

      it 'returns the entity type from the preloaded data' do
        expect(user_type.entity_type).to eq('non_human')
      end
    end

    context 'when user does not have consumer data' do
      let(:user) { build(:user) }

      it 'returns nil' do
        expect(user_type.entity_type).to be_nil
      end
    end
  end

  describe '#usage' do
    let(:user_type) { described_class.send(:new, user, context) }
    let(:context) { instance_double(GraphQL::Query::Context) }

    context 'when user is a UserWithConsumption' do
      let(:consumption) do
        {
          totalCredits: 100.12,
          creditsUsed: 50.34,
          monthlyCommitmentCreditsUsed: 30.56,
          monthlyWaiverCreditsUsed: 10.78,
          overageCreditsUsed: 10.91,
          paidTierTrialCreditsUsed: 5.12
        }
      end

      let(:user) do
        ::GitlabSubscriptions::SubscriptionsUsage::UserWithConsumption.new(build(:user), consumption)
      end

      it 'returns usage from the preloaded data' do
        result = user_type.usage

        expect(result).to be_a(::GitlabSubscriptions::SubscriptionsUsage::UserConsumptionStatistics)
        expect(result).to have_attributes(
          total_credits: 100.12,
          credits_used: 50.34,
          monthly_commitment_credits_used: 30.56,
          monthly_waiver_credits_used: 10.78,
          overage_credits_used: 10.91,
          paid_tier_trial_credits_used: 5.12
        )
      end
    end

    context 'when user does not have consumer data' do
      let(:user) { build(:user) }
      let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
      let(:usage_response) do
        {
          usersUsage: [
            {
              userId: user.id,
              totalCredits: 200.0,
              creditsUsed: 100.0,
              monthlyCommitmentCreditsUsed: 60.0,
              monthlyWaiverCreditsUsed: 20.0,
              overageCreditsUsed: 20.0,
              paidTierTrialCreditsUsed: 15.8
            }
          ]
        }
      end

      before do
        allow(context).to receive(:[]).and_return(nil)
        allow(context).to receive(:[]).with(:subscription_usage_client).and_return(subscription_usage_client)
        allow(subscription_usage_client).to receive(:get_usage_for_user_ids).and_return(usage_response)
      end

      it 'returns a BatchLoader for fetching usage' do
        result = user_type.usage

        expect(result).to be_a(BatchLoader::GraphQL)
      end

      context 'when flow_types is set in context' do
        before do
          allow(context).to receive(:[]).with(:flow_types).and_return(%w[chat])
          allow(subscription_usage_client).to receive(:get_usage_for_user_ids)
                                                .with([user.id], flow_types: %w[chat])
                                                .and_return(usage_response)
        end

        it 'passes flow_types to get_usage_for_user_ids' do
          batch_sync { user_type.usage }

          expect(subscription_usage_client).to have_received(:get_usage_for_user_ids)
                                                 .with([user.id], flow_types: %w[chat])
        end
      end
    end
  end

  describe '#blocked_status' do
    let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
    let(:context) { { current_user: build(:user), subscription_usage_client: subscription_usage_client } }
    let(:user_type) { described_class.send(:new, user, context) }

    context 'when user is a UserWithConsumption' do
      let_it_be(:underlying_user) { create(:user) }
      let(:user) do
        ::GitlabSubscriptions::SubscriptionsUsage::UserWithConsumption.new(underlying_user, {})
      end

      let(:client_response) do
        {
          success: true,
          blockedStatuses: [{ entityId: underlying_user.id.to_s, blocked: true, capType: 'FLAT_USER_CAP' }]
        }
      end

      it 'uses declarative_policy_subject from the UserWithConsumption' do
        allow(subscription_usage_client).to receive(:get_blocked_statuses)
          .with([underlying_user.id.to_s])
          .and_return(client_response)

        result = batch_sync { user_type.blocked_status }

        expect(result).to have_attributes(
          blocked: true,
          cap_type: 'FLAT_USER_CAP',
          declarative_policy_subject: underlying_user
        )
      end
    end

    context 'when user is a regular User' do
      let_it_be(:user) { create(:user) }

      let(:client_response) do
        {
          success: true,
          blockedStatuses: [
            { entityId: user.id.to_s, blocked: false, capType: nil },
            { entityId: '999999', blocked: true, capType: 'FLAT_USER_CAP' }
          ]
        }
      end

      it 'uses the user object as policy_subject and skips non-matching entity ids' do
        allow(subscription_usage_client).to receive(:get_blocked_statuses)
          .with([user.id.to_s])
          .and_return(client_response)

        result = batch_sync { user_type.blocked_status }

        expect(result).to have_attributes(
          blocked: false,
          cap_type: nil,
          declarative_policy_subject: user
        )
      end
    end

    context 'when blockedStatuses is missing from response' do
      let_it_be(:user) { create(:user) }

      it 'returns nil' do
        allow(subscription_usage_client).to receive(:get_blocked_statuses)
          .and_return({ success: true })

        result = batch_sync { user_type.blocked_status }

        expect(result).to be_nil
      end
    end
  end

  describe '#events' do
    let(:user_type) { described_class.send(:new, user, context) }
    let(:context) { instance_double(GraphQL::Query::Context) }

    context 'when user is a UserWithConsumption' do
      let(:user) do
        ::GitlabSubscriptions::SubscriptionsUsage::UserWithConsumption.new(build(:user), {})
      end

      it 'returns nil to skip batch loading' do
        result = user_type.events

        expect(result).to be_nil
      end
    end

    context 'when user does not have consumer data' do
      let(:user) { build(:user) }
      let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }

      before do
        allow(context).to receive(:[]).with(:subscription_usage_client).and_return(subscription_usage_client)
      end

      it 'returns a BatchLoader for fetching events' do
        result = user_type.events

        expect(result).to be_a(BatchLoader::GraphQL)
      end
    end
  end
end
