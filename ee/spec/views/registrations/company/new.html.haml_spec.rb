# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'registrations/company/new', :with_trial_types, feature_category: :onboarding do
  let(:user) { build_stubbed(:user) }
  let(:show_company_form_side_column?) { false }
  let(:onboarding_status_presenter) do
    instance_double(
      ::Onboarding::StatusPresenter,
      show_company_form_footer?: true,
      show_company_form_side_column?: show_company_form_side_column?,
      tracking_label: 'free_registration'
    )
  end

  before do
    allow(view).to receive_messages(current_user: user, onboarding_status_presenter: onboarding_status_presenter)
  end

  describe 'Google Tag Manager' do
    let!(:gtm_id) { 'GTM-WWKMTWS' }
    let!(:google_url) { 'www.googletagmanager.com' }

    subject { rendered }

    before do
      stub_devise
      stub_config(extra: { google_tag_manager_id: gtm_id, google_tag_manager_nonce_id: gtm_id })
      allow(view).to receive(:google_tag_manager_enabled?).and_return(gtm_enabled)

      render
    end

    describe 'when Google Tag Manager is enabled' do
      let(:gtm_enabled) { true }

      it { is_expected.to match(/#{google_url}/) }
    end

    describe 'when Google Tag Manager is disabled' do
      let(:gtm_enabled) { false }

      it { is_expected.not_to match(/#{google_url}/) }
    end
  end

  describe 'when page is rendered' do
    context 'when a user is coming from a trial registration' do
      let(:show_company_form_side_column?) { false }

      it 'renders correctly' do
        render

        expect_to_see_trial_form
      end
    end

    context 'when a user is coming from a free registration' do
      let(:show_company_form_side_column?) { true }

      it 'renders correctly' do
        render

        expect_to_see_registration_form
      end
    end
  end

  describe 'page title' do
    before do
      allow(view).to receive(:page_title)
    end

    it 'renders the correct page title' do
      render

      expect(view).to have_received(:page_title).with(_('Tell us about your company'))
    end
  end

  def stub_devise
    allow(view).to receive_messages(devise_mapping: Devise.mappings[:user], resource: spy, resource_name: :user)
  end

  def expect_to_see_trial_form
    expect(rendered).to have_content(_('Tell us about your company'))
    expect(rendered).to have_content(s_('Trial|We need a few more details from you to activate your trial.'))
    expect(rendered).not_to have_selector('[data-testid="trial-reassurances-column"]')
  end

  def expect_to_see_registration_form
    expect(rendered).to have_content(_('Tell us about your company'))
    expect(rendered).to have_content(s_('Trial|We need a few more details from you to activate your trial.'))
    expect(rendered).to have_selector('[data-testid="trial-reassurances-column"]')
  end
end
