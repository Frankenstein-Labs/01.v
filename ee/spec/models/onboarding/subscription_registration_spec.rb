# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::SubscriptionRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.tracking_label' do
    subject { described_class.tracking_label }

    it { is_expected.to eq('subscription_registration') }
  end

  describe '.event_label' do
    subject { described_class.event_label }

    it { is_expected.to eq('premium_subscription_com') }
  end

  describe '.account_created_product_interaction' do
    subject { described_class.account_created_product_interaction }

    it { is_expected.to eq('Direct Purchase Account Creation Premium Dotcom') }
  end

  describe '.read_from_stored_user_location?' do
    it { is_expected.to be_read_from_stored_user_location }
  end

  describe '.preserve_stored_location?' do
    it { is_expected.to be_preserve_stored_location }
  end

  describe '.get_started_subtext' do
    subject { described_class.get_started_subtext }

    it { is_expected.to eq(_('Create a GitLab account to purchase GitLab Premium.')) }
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
