# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialsUsage::UserUsage, feature_category: :consumables_cost_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }

  let(:subscription_usage_client) { instance_double(Gitlab::SubscriptionPortal::SubscriptionUsageClient) }
  let(:trial_usage) do
    GitlabSubscriptions::TrialsUsage::Base.new(
      subscription_target: :namespace,
      subscription_usage_client: subscription_usage_client,
      namespace: group
    )
  end

  subject(:user_usage) { described_class.new(trial_usage: trial_usage) }

  before_all do
    group.add_developer(user1)
    group.add_developer(user2)
  end

  describe '#total_users_using_credits' do
    let(:trial_usage_response) do
      {
        trialUsage: {
          usersUsage: {
            totalUsersUsingCredits: 2
          }
        }
      }
    end

    before do
      allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
    end

    it 'returns the total number of users using credits' do
      expect(user_usage.total_users_using_credits).to eq(2)
    end
  end

  describe '#credits_used' do
    let(:trial_usage_response) do
      {
        trialUsage: {
          usersUsage: {
            creditsUsed: 12.5
          }
        }
      }
    end

    before do
      allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
    end

    it 'returns the total credits used' do
      expect(user_usage.credits_used).to eq(12.5)
    end
  end

  describe '#users' do
    let(:trial_usage_response) do
      {
        trialUsage: {
          usersUsage: {}
        }
      }
    end

    before do
      allow(subscription_usage_client).to receive(:get_trial_usage).and_return(trial_usage_response)
    end

    context 'when subscription target is namespace' do
      it 'returns users from descendant members' do
        users = user_usage.users

        expect(users).to include(user1, user2)
      end

      context 'with username filter' do
        it 'filters users by username' do
          users = user_usage.users(username: user1.username)

          expect(users).to contain_exactly(user1)
        end
      end
    end

    context 'when subscription target is instance' do
      let(:trial_usage) do
        GitlabSubscriptions::TrialsUsage::Base.new(
          subscription_target: :instance,
          subscription_usage_client: subscription_usage_client
        )
      end

      it 'returns all instance users' do
        users = user_usage.users

        expect(users).to include(user1, user2)
      end

      context 'with username filter' do
        it 'filters users by username' do
          users = user_usage.users(username: user1.username)

          expect(users).to contain_exactly(user1)
        end
      end
    end
  end

  describe '#declarative_policy_subject' do
    it 'returns the trial usage object' do
      expect(user_usage.declarative_policy_subject).to eq(trial_usage)
    end
  end
end
