# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionsUsage::UserWithConsumption,
  feature_category: :consumables_cost_management do
  let(:user) { build(:user) }
  let(:consumption) do
    {
      totalCredits: 100.0,
      creditsUsed: 50.0,
      monthlyCommitmentCreditsUsed: 30.0,
      monthlyWaiverCreditsUsed: 10.0,
      overageCreditsUsed: 10.0,
      paidTierTrialCreditsUsed: 5.0,
      entityType: 'NON_HUMAN'
    }
  end

  subject(:user_with_consumption) { described_class.new(user, consumption) }

  it 'delegates to the underlying user object' do
    expect(user_with_consumption.id).to eq(user.id)
    expect(user_with_consumption.name).to eq(user.name)
    expect(user_with_consumption.username).to eq(user.username)
  end

  describe '#usage' do
    it 'returns a UserConsumptionStatistics instance' do
      expect(user_with_consumption.usage).to be_a(
        GitlabSubscriptions::SubscriptionsUsage::UserConsumptionStatistics
      )
    end

    it 'exposes consumption data through usage' do
      usage = user_with_consumption.usage

      expect(usage.total_credits).to eq(100.0)
      expect(usage.credits_used).to eq(50.0)
      expect(usage.monthly_commitment_credits_used).to eq(30.0)
      expect(usage.monthly_waiver_credits_used).to eq(10.0)
      expect(usage.overage_credits_used).to eq(10.0)
      expect(usage.paid_tier_trial_credits_used).to eq(5.0)
    end
  end

  describe '#entity_type' do
    it 'returns the normalized entity type from the consumption data' do
      expect(user_with_consumption.entity_type).to eq('non_human')
    end

    context 'when consumption entity type is missing' do
      let(:consumption) { super().merge(entityType: nil) }
      let(:user) { build(:user, :service_account) }

      it 'falls back to user' do
        expect(user_with_consumption.entity_type).to eq('user')
      end
    end
  end

  describe '#declarative_policy_subject' do
    it 'returns the underlying user object' do
      expect(user_with_consumption.declarative_policy_subject).to eq(user)
    end
  end
end
