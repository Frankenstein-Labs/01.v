# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoPro, feature_category: :subscription_management do
  let_it_be(:namespace) { create(:group) }

  describe '.show_duo_pro_discover?', :saas_subscriptions_trials do
    subject { described_class.show_duo_pro_discover?(namespace, user) }

    let_it_be(:user) { create(:user) }
    let_it_be_with_reload(:add_on_purchase) do
      create(:gitlab_subscription_add_on_purchase, :duo_pro, :trial, namespace: namespace)
    end

    context 'when all conditions are met' do
      before_all do
        namespace.add_owner(user)
      end

      it { is_expected.to be(true) }
    end

    context 'when on expired trial' do
      before_all do
        namespace.add_owner(user)
        add_on_purchase.update!(expires_on: 1.day.ago)
      end

      it { is_expected.to be(true) }
    end

    context 'when namespace is not present' do
      let(:namespace) { nil }

      it { is_expected.to be(false) }
    end

    context 'when user is not present' do
      let(:user) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the `subscriptions_trials` feature is not available' do
      before do
        stub_saas_features(subscriptions_trials: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when namespace does not have an active duo pro trial' do
      before_all do
        namespace.add_owner(user)
        add_on_purchase.update!(expires_on: 11.days.ago)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.show_duo_usage_settings?' do
    subject { described_class.show_duo_usage_settings?(namespace) }

    context 'when active add_on' do
      let_it_be(:add_on_purchase_on) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    context 'when on trial' do
      let_it_be(:add_on_purchase_on) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :trial, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    context 'when on expired trial' do
      let_it_be(:add_on_purchase_on) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired_trial, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    context 'when on trial expired 11 days ago' do
      let_it_be(:add_on_purchase_on) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :trial,
          namespace: namespace,
          expires_on: 11.days.ago
        )
      end

      it { is_expected.to be(false) }
    end

    context 'when namespace does not have an add_on' do
      it { is_expected.to be(false) }
    end
  end

  describe '.active_add_on_purchase_for_namespace?' do
    let_it_be(:namespace) { create(:group) }

    subject { described_class.active_add_on_purchase_for_namespace?(namespace) }

    context 'when there is an active trial add-on purchase for the namespace' do
      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :active_trial, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end

    context 'when there is an expired trial add-on purchase for the namespace' do
      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired_trial, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is an active non-trial add-on purchase for the namespace' do
      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :active, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is an expired non-trial add-on purchase for the namespace' do
      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :expired, namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there are no add-on purchases for the namespace' do
      it { is_expected.to be(false) }
    end

    context 'when namespace id is passed instead of namespace object' do
      subject { described_class.active_add_on_purchase_for_namespace?(namespace.id) }

      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :active_trial, namespace: namespace)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.any_add_on_purchase_for_namespace' do
    subject(:any_add_on_purchase_for_namespace) { described_class.any_add_on_purchase_for_namespace(namespace) }

    context 'when there is an add_on_purchase' do
      let_it_be_with_reload(:add_on_purchase) do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, :trial, namespace: namespace)
      end

      it 'returns the add_on_purchase' do
        expect(any_add_on_purchase_for_namespace).to eq(add_on_purchase)
      end
    end

    context 'when there is an add_on_purchase that is not a trial' do
      before_all do
        create(:gitlab_subscription_add_on_purchase, :duo_pro, namespace: namespace)
      end

      it 'returns nil' do
        expect(any_add_on_purchase_for_namespace).to be_nil
      end
    end

    context 'when there are no add_on_purchases' do
      it 'returns nil' do
        expect(any_add_on_purchase_for_namespace).to be_nil
      end
    end
  end
end
