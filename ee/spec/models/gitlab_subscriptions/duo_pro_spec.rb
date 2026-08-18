# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DuoPro, feature_category: :subscription_management do
  describe '.add_on_purchase_for_namespace' do
    let_it_be(:namespace) { create(:group) }

    subject { described_class.add_on_purchase_for_namespace(namespace) }

    context 'when there is an add_on_purchase' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when there is an add_on_purchase that is a trial' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :trial, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when there are no add_on_purchases' do
      it { is_expected.to be_nil }
    end
  end

  describe '.any_add_on_purchase_for_namespace' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.any_add_on_purchase_for_namespace(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when the add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired, namespace: namespace)
      end

      it { is_expected.to eq(add_on_purchase) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be_nil }
    end

    context 'when namespace id is passed' do
      subject { described_class.any_add_on_purchase_for_namespace(namespace.id) }

      context 'when there is an add-on purchase for the namespace' do
        let_it_be(:add_on_purchase) do
          create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
        end

        it { is_expected.to eq(add_on_purchase) }
      end

      context 'when there is no add-on purchase for the namespace' do
        it { is_expected.to be_nil }
      end
    end
  end

  describe '.no_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:namespace) }

    subject { described_class.no_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an add-on purchase for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when the add-on purchase is expired for the namespace' do
      let_it_be(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is no add-on purchase for the namespace' do
      it { is_expected.to be(true) }
    end
  end

  describe '.namespace_eligible?', :saas do
    context 'when namespace has an eligible plan' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :premium_plan) }

      it 'returns true' do
        expect(described_class.namespace_eligible?(namespace)).to be true
      end
    end

    context 'when namespace does not have an eligible plan' do
      let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }

      it 'returns false' do
        expect(described_class.namespace_eligible?(namespace)).to be false
      end
    end
  end
end
