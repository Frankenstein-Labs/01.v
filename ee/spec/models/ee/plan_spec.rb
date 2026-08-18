# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Plan, feature_category: :subscription_management do
  it 'has subscription history relation' do
    is_expected
      .to(
        have_many(:gitlab_subscription_histories)
          .class_name('GitlabSubscriptions::SubscriptionHistory')
          .with_foreign_key(:hosted_plan_id).inverse_of(:hosted_plan)
      )
  end

  describe '.free' do
    subject(:free) { described_class.free }

    context 'when gitlab_com_subscriptions feature is not available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: false)
      end

      it { is_expected.to be_nil }
    end

    context 'when gitlab_com_subscriptions feature is available' do
      before do
        stub_saas_features(gitlab_com_subscriptions: true)
      end

      context 'when free plan exists in database' do
        let_it_be(:existing_plan) { create(:plan, name: described_class::FREE) }

        it { is_expected.to eq(existing_plan) }

        it 'caches the result in SafeRequestStore', :request_store do
          first_result = described_class.free
          second_result = described_class.free

          expect(first_result).to eq(second_result)
          expect(first_result).to be(second_result)
        end
      end

      context 'when free plan does not exist in database' do
        it 'creates a new free plan' do
          expect { free }.to change { described_class.count }.by(1)

          expect(free.name).to eq(described_class::FREE)
          expect(free).to be_persisted
        end

        it 'returns the created plan on subsequent calls' do
          first_call = free
          second_call = described_class.free

          expect(first_call).to eq(second_call)
          expect(described_class.where(name: described_class::FREE).count).to eq(1)
        end
      end

      context 'for caching behavior' do
        it 'only creates one record even with multiple calls' do
          expect { 3.times { free } }.to change { described_class.count }.by(1)
        end

        it 'uses cached result for subsequent calls within same request', :request_store do
          first_result = free

          expect(described_class).not_to receive(:find_by)
          second_result = described_class.free

          expect(first_result).to be(second_result)
        end
      end
    end
  end

  describe '#paid?' do
    subject { plan.paid? }

    Plan.default_plans.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build(:"#{plan}_plan") }

        it { is_expected.to be_falsey }
      end
    end

    Plan::PAID_HOSTED_PLANS.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build(:"#{plan}_plan") }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#ultimate_or_ultimate_trial_plans?' do
    subject { plan.ultimate_or_ultimate_trial_plans? }

    (Plan.all_plans - Plan::ALL_ULTIMATE_PLANS).each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build(:"#{plan}_plan") }

        it { is_expected.to be_falsey }
      end
    end

    Plan::ALL_ULTIMATE_PLANS.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build(:"#{plan}_plan") }

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '::PLANS_ELIGIBLE_FOR_TRIAL' do
    subject { described_class::PLANS_ELIGIBLE_FOR_TRIAL }

    it { is_expected.to match_array(%w[default free premium]) }
  end

  describe '::ULTIMATE_TRIAL_PLANS' do
    subject { described_class::ULTIMATE_TRIAL_PLANS }

    it { is_expected.to match_array(%w[ultimate_trial ultimate_trial_paid_customer]) }
  end

  describe '::ALL_ULTIMATE_PLANS' do
    subject { described_class::ALL_ULTIMATE_PLANS }

    it { is_expected.to match_array(%w[ultimate ultimate_trial ultimate_trial_paid_customer]) }
  end

  describe '.with_subscriptions' do
    it 'includes plans that have attached subscriptions', :saas do
      group = create(:group_with_plan, plan: :free_plan)
      create(:premium_plan)
      create(:ultimate_plan)

      expect(described_class.with_subscriptions).to match_array([group.gitlab_subscription.hosted_plan])
    end
  end

  describe '.by_namespace' do
    it 'includes plans that have attached subscriptions', :saas do
      group = create(:group_with_plan, plan: :free_plan)
      another_group = create(:group_with_plan, plan: :premium_plan)
      create(:ultimate_plan)

      expect(described_class.with_subscriptions.by_namespace([another_group, group]))
        .to match_array([group.gitlab_subscription.hosted_plan, another_group.gitlab_subscription.hosted_plan])
    end
  end

  describe '.by_distinct_names' do
    it 'includes distinct plan names', :saas do
      free_plan = create(:free_plan)
      free_group = create(:group_with_plan, plan: :free_plan)
      another_free_group = create(:group_with_plan, plan: :free_plan)
      create(:premium_plan)
      not_found_premium_group = create(:group_with_plan, plan: :premium_plan)
      ultimate_plan = create(:ultimate_plan)
      ultimate_group = create(:group_with_plan, plan: :ultimate_plan)

      namespaces = [free_group, another_free_group, not_found_premium_group, ultimate_group]
      expect(described_class.with_subscriptions.by_namespace(namespaces).by_distinct_names(%w[free ultimate]))
        .to match_array([free_plan, ultimate_plan])
    end
  end

  describe '#paid_excluding_trials?' do
    subject { plan.paid_excluding_trials? }

    real_paid_plans = Plan::PAID_HOSTED_PLANS - Plan::FREE_TRIAL_PLANS

    Plan.default_plans.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build(:"#{plan}_plan") }

        it { is_expected.to be_falsey }
      end
    end

    real_paid_plans.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build(:"#{plan}_plan") }

        it { is_expected.to be_truthy }
      end
    end

    Plan::FREE_TRIAL_PLANS.each do |plan|
      context "when '#{plan}'" do
        let(:plan) { build(:"#{plan}_plan") }

        it { is_expected.to be_falsey }
      end
    end

    context 'with exclude_oss option' do
      let(:plan) { build(:opensource_plan) }

      context 'with exclude_oss option' do
        it { expect(plan.paid_excluding_trials?(exclude_oss: true)).to be false }
      end
    end
  end

  describe '#open_source?' do
    subject { plan.open_source? }

    context 'when is opensource' do
      let(:plan) { build(:opensource_plan) }

      it { is_expected.to be_truthy }
    end

    context 'when is not opensource' do
      let(:plan) { build(:free_plan) }

      it { is_expected.to be_falsey }
    end
  end
end
