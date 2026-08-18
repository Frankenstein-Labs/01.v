# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoEnterprise, feature_category: :subscription_management do
  describe '.no_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.no_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when the add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_enterprise, :expired, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be(true) }
    end
  end

  describe '.active_add_on_purchase_for_self_managed?' do
    let!(:add_on_purchase) do
      create(
        :gitlab_subscription_add_on_purchase,
        namespace: namespace,
        add_on: add_on,
        started_at: started_at,
        expires_on: expires_on
      )
    end

    let(:started_at) { 1.day.ago.to_date }
    let(:expires_on) { 1.year.from_now.to_date }
    let(:namespace) { nil } # self-managed
    let(:add_on) { build(:gitlab_subscription_add_on, :duo_enterprise) }

    it { expect(described_class).to be_active_add_on_purchase_for_self_managed }

    context 'with other add-on' do
      let(:add_on) { build(:gitlab_subscription_add_on, :duo_pro) }

      it { expect(described_class).not_to be_active_add_on_purchase_for_self_managed }
    end

    context 'with inactive add-on' do
      let(:started_at) { 1.year.ago.to_date }
      let(:expires_on) { 1.month.ago.to_date }

      it { expect(described_class).not_to be_active_add_on_purchase_for_self_managed }
    end

    context 'with GitLab.com add-on' do
      let(:namespace) { build(:namespace) }

      it { expect(described_class).not_to be_active_add_on_purchase_for_self_managed }
    end
  end

  describe '.namespace_eligible?', :saas_gitlab_com_subscriptions do
    subject { described_class.namespace_eligible?(namespace) }

    context 'when namespace has an eligible plan' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      context 'when namespace is an ultimate plan' do
        it { is_expected.to be(true) }
      end

      context 'when an add-on purchase exists for the namespace' do
        before_all do
          create(:gitlab_subscription_add_on_purchase, :duo_enterprise, namespace: namespace)
        end

        it { is_expected.to be(false) }
      end
    end

    context 'when namespace does not have an eligible plan' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :premium_plan) }

      it { is_expected.to be(false) }
    end
  end

  describe '.namespace_plan_eligible?', :saas_gitlab_com_subscriptions do
    subject { described_class.namespace_plan_eligible?(namespace) }

    context 'when namespace has an ultimate plan' do
      let(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      it { is_expected.to be true }
    end

    context 'when namespace has a non-ultimate plan' do
      let(:namespace) { create(:group) }

      it { is_expected.to be false }
    end
  end
end
