# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::SubscriptionsUsage::UserConsumptionStatistics,
  feature_category: :consumables_cost_management do
  let(:user) { build(:user) }
  let(:consumption) do
    {
      totalCredits: 100.0,
      creditsUsed: 50.0,
      totalCreditsUsed: 105.0,
      monthlyCommitmentCreditsUsed: 30.0,
      monthlyWaiverCreditsUsed: 10.0,
      overageCreditsUsed: 10.0,
      paidTierTrialCreditsUsed: 5.0
    }
  end

  subject(:statistics) { described_class.new(user, consumption) }

  describe '#total_credits' do
    it { expect(statistics.total_credits).to eq(100.0) }
  end

  describe '#credits_used' do
    it { expect(statistics.credits_used).to eq(50.0) }
  end

  describe '#total_credits_used' do
    it { expect(statistics.total_credits_used).to eq(105.0) }
  end

  describe '#monthly_commitment_credits_used' do
    it { expect(statistics.monthly_commitment_credits_used).to eq(30.0) }
  end

  describe '#monthly_waiver_credits_used' do
    it { expect(statistics.monthly_waiver_credits_used).to eq(10.0) }
  end

  describe '#overage_credits_used' do
    it { expect(statistics.overage_credits_used).to eq(10.0) }
  end

  describe '#paid_tier_trial_credits_used' do
    it { expect(statistics.paid_tier_trial_credits_used).to eq(5.0) }
  end

  describe '#declarative_policy_subject' do
    it { expect(statistics.declarative_policy_subject).to eq(user) }
  end
end
