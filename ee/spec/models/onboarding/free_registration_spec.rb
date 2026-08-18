# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Onboarding::FreeRegistration, type: :undefined, feature_category: :onboarding do
  subject { described_class }

  describe '.tracking_label' do
    subject { described_class.tracking_label }

    it { is_expected.to eq('free_registration') }
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

    it { is_expected.to eq('Personal SaaS Registration') }
  end

  describe '.welcome_submit_button_text' do
    subject { described_class.welcome_submit_button_text }

    it { is_expected.to eq(_('Continue')) }
  end

  describe '.setup_for_company_label_text' do
    subject { described_class.setup_for_company_label_text }

    it { is_expected.to eq(_('Who will be using GitLab?')) }
  end

  describe '.setup_for_company_help_text' do
    subject { described_class.setup_for_company_help_text }

    it 'returns DAP copy' do
      is_expected.to eq(
        _(
          'Try GitLab Ultimate for free and automate tasks with GitLab Duo Agent Platform ' \
            'when you create a new project.'
        )
      )
    end
  end

  describe '.learn_gitlab_redesign?' do
    it { is_expected.not_to be_learn_gitlab_redesign }
  end

  describe '.redirect_to_company_form?' do
    it { is_expected.not_to be_redirect_to_company_form }
  end

  describe '.eligible_for_iterable_trigger?' do
    it { is_expected.to be_eligible_for_iterable_trigger }
  end

  describe '.continue_full_onboarding?' do
    it { is_expected.to be_continue_full_onboarding }
  end

  describe '.convert_to_automatic_trial?' do
    it { is_expected.to be_convert_to_automatic_trial }
  end

  describe '.show_joining_project?' do
    it { is_expected.to be_show_joining_project }
  end

  describe '.apply_trial?' do
    it { is_expected.not_to be_apply_trial }
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

  describe '.trigger_account_created_iterable?' do
    subject { described_class.trigger_account_created_iterable? }

    it { is_expected.to be(false) }
  end

  describe '.signup_page_image' do
    subject { described_class.signup_page_image }

    it { is_expected.to eq('subscription/pipeline') }
  end

  describe '.signup_page_heading' do
    subject { described_class.signup_page_heading }

    it { is_expected.to eq(s_('InProductMarketing|Ship software faster')) }
  end

  describe '.identity_verification_panel_image' do
    subject { described_class.identity_verification_panel_image }

    it { is_expected.to eq('subscription/collab') }
  end

  describe '.identity_verification_panel_heading' do
    subject { described_class.identity_verification_panel_heading }

    it { is_expected.to eq(s_('InProductMarketing|Collaborate and accelerate in one place')) }
  end
end
