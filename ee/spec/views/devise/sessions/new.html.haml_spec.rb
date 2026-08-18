# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/sessions/new', feature_category: :system_access do
  before do
    view.instance_variable_set(:@arkose_labs_public_key, "arkose-api-key")
    view.instance_variable_set(:@arkose_labs_domain, "gitlab-api.arkoselab.com")
  end

  describe 'broadcast messaging' do
    let(:onboarding_enabled) { true }

    before do
      stub_saas_features(onboarding: onboarding_enabled)
      stub_devise
      disable_captcha

      render
    end

    context 'when onboarding feature is not available' do
      let(:onboarding_enabled) { false }

      it { expect(rendered).to render_template('layouts/_broadcast') }
    end

    context 'when onboarding feature is available' do
      it { expect(rendered).not_to render_template('layouts/_broadcast') }
    end
  end

  describe 'Google Tag Manager' do
    let!(:gtm_id) { 'GTM-WWKMTWS' }

    subject { rendered }

    before do
      stub_devise
      disable_captcha
      stub_config(extra: { google_tag_manager_id: gtm_id, google_tag_manager_nonce_id: gtm_id })
    end

    describe 'when Google Tag Manager is enabled' do
      before do
        enable_gtm
        render
      end

      it { is_expected.to match(/www.googletagmanager.com/) }
    end

    describe 'when Google Tag Manager is disabled' do
      before do
        disable_gtm
        render
      end

      it { is_expected.not_to match(/www.googletagmanager.com/) }
    end
  end

  def stub_devise
    allow(view).to receive(:devise_mapping).and_return(Devise.mappings[:user])
    allow(view).to receive(:resource).and_return(spy)
    allow(view).to receive(:resource_name).and_return(:user)
    allow(view).to receive(:onboarding_status_tracking_label).and_return('free_registration')
  end

  def disable_captcha
    allow(view).to receive(:captcha_enabled?).and_return(false)
    allow(view).to receive(:captcha_on_login_required?).and_return(false)
  end

  def disable_gtm
    allow(view).to receive(:google_tag_manager_enabled?).and_return(false)
  end

  def enable_gtm
    allow(view).to receive(:google_tag_manager_enabled?).and_return(true)
  end
end
