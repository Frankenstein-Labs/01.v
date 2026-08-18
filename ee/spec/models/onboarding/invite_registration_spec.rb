# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::InviteRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.tracking_label' do
    subject { described_class.tracking_label }

    it { is_expected.to eq('invite_registration') }
  end

  describe '.event_label' do
    subject { described_class.event_label }

    it { is_expected.to be_nil }
  end

  describe '.account_created_product_interaction' do
    subject { described_class.account_created_product_interaction }

    it { is_expected.to be_nil }
  end

  describe '.product_interaction' do
    subject { described_class.product_interaction }

    it { is_expected.to eq('Invited User') }
  end

  describe '.read_from_stored_user_location?' do
    it { is_expected.not_to be_read_from_stored_user_location }
  end

  describe '.preserve_stored_location?' do
    it { is_expected.not_to be_preserve_stored_location }
  end

  describe '.get_started_subtext' do
    subject { described_class.get_started_subtext }

    it { is_expected.to be_nil }
  end

  describe '.unification_enabled?' do
    it { is_expected.not_to be_unification_enabled }
  end

  describe '.trigger_account_created_iterable?' do
    it { is_expected.not_to be_trigger_account_created_iterable }
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
