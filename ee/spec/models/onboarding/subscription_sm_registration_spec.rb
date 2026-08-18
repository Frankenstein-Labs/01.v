# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::SubscriptionSmRegistration, feature_category: :onboarding do
  subject { described_class }

  describe '.tracking_label' do
    subject { described_class.tracking_label }

    it { is_expected.to eq('subscription_sm_registration') }
  end

  describe '.event_label' do
    subject { described_class.event_label }

    it { is_expected.to eq('premium_subscription_sm') }
  end

  describe '.account_created_product_interaction' do
    subject { described_class.account_created_product_interaction }

    it { is_expected.to eq('Direct Purchase Account Creation Premium SM') }
  end

  describe '.get_started_subtext' do
    subject { described_class.get_started_subtext }

    let(:expected_subtitle) do
      s_('InProductMarketing|Create a GitLab account to purchase the Premium tier of GitLab Self-Managed.')
    end

    it { is_expected.to eq(expected_subtitle) }
  end

  describe '.read_from_stored_user_location?', :saas_onboarding do
    subject { described_class.read_from_stored_user_location? }

    it { is_expected.to be(false) }

    context 'when onboarding is disabled' do
      before do
        stub_saas_features(onboarding: false)
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.preserve_stored_location?' do
    it { is_expected.to be_preserve_stored_location }
  end

  describe '.redirect_to_customers_portal?', :saas_onboarding do
    subject { described_class.redirect_to_customers_portal? }

    it { is_expected.to be(true) }

    context 'when onboarding is disabled' do
      before do
        stub_saas_features(onboarding: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.unification_enabled?', :saas_onboarding do
    subject { described_class.unification_enabled? }

    it { is_expected.to be(true) }

    context 'when onboarding is disabled' do
      before do
        stub_saas_features(onboarding: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.trigger_account_created_iterable?', :saas_onboarding do
    subject { described_class.trigger_account_created_iterable? }

    it { is_expected.to be(true) }

    context 'when onboarding is disabled' do
      before do
        stub_saas_features(onboarding: false)
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.identity_verification_panel_image' do
    subject { described_class.identity_verification_panel_image }

    it { is_expected.to eq('subscription/pipeline') }
  end

  describe '.identity_verification_panel_heading' do
    subject { described_class.identity_verification_panel_heading }

    it { is_expected.to eq(s_('InProductMarketing|Ship software faster')) }
  end
end
