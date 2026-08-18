# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/registrations/new', feature_category: :system_access do
  let(:arkose_labs_enabled) { true }
  let(:arkose_labs_api_key) { "api-key" }
  let(:arkose_labs_domain) { "domain" }
  let(:resource) { Users::RegistrationsBuildService.new(nil, {}).execute }
  let(:params) { controller.params }
  let(:onboarding_status_presenter) do
    ::Onboarding::StatusPresenter.new(params.to_unsafe_h.deep_symbolize_keys, nil, resource)
  end

  subject { render && rendered }

  before do
    allow(view).to receive(:onboarding_status_presenter) { onboarding_status_presenter }
    allow(view).to receive(:resource).and_return(resource)
    allow(view).to receive(:resource_name).and_return(:user)

    allow(view).to receive(:arkose_labs_enabled?).and_return(arkose_labs_enabled)
    allow(view).to receive(:preregistration_tracking_label).and_return('free_registration')
    allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_public_api_key)
      .and_return(arkose_labs_api_key)
    allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_labs_domain).and_return(arkose_labs_domain)
  end

  context 'for a trial sign-up', :saas_onboarding do
    let(:onboarding_status_presenter) do
      ::Onboarding::StatusPresenter.new({ trial: true }, nil, resource)
    end

    before do
      allow(view).to receive(:signup_button_based_providers_enabled?).and_return(false)
    end

    it 'renders the unified two-panel registration layout for trial sign-up' do
      render

      expect(rendered).to have_css('[data-testid="registration-two-panel-layout"]')
      expect(rendered).not_to have_css('.signup-page')
    end
  end

  context 'for free sign-up', :saas_onboarding do
    before do
      allow(view).to receive(:signup_button_based_providers_enabled?).and_return(false)
    end

    it 'renders the unified two-panel registration layout for free sign-up' do
      render

      expect(rendered).to have_css('[data-testid="registration-two-panel-layout"]')
      expect(rendered).not_to have_css('.signup-page')
    end

    it 'sets the marketing-panel image and heading for the pipeline illustration', :aggregate_failures do
      render

      expect(view.content_for(:registration_marketing_panel_image)).to eq('subscription/pipeline')
      expect(view.content_for(:registration_marketing_panel_heading))
        .to eq(s_('InProductMarketing|Ship software faster'))
    end

    context 'when social signin is enabled' do
      before do
        allow(view).to receive(:signup_button_based_providers_enabled?).and_return(true)
        allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])
      end

      it 'prefixes the omniauth provider button labels with "Continue with"', :aggregate_failures do
        render

        expect(rendered).to have_content(format(_('Continue with %{provider}'), provider: 'GitHub'))
        expect(rendered).to have_content(format(_('Continue with %{provider}'), provider: 'Google'))
      end
    end
  end

  it { is_expected.to have_selector('#js-arkose-labs-challenge') }
  it { is_expected.to have_selector("[data-api-key='#{arkose_labs_api_key}']") }
  it { is_expected.to have_selector("[data-domain='#{arkose_labs_domain}']") }

  context 'when the feature is disabled' do
    let(:arkose_labs_enabled) { false }

    it { is_expected.not_to have_selector('#js-arkose-labs-challenge') }
    it { is_expected.not_to have_selector("[data-api-key='#{arkose_labs_api_key}']") }
    it { is_expected.not_to have_selector("[data-domain='#{arkose_labs_domain}']") }
  end

  context 'for password form' do
    before do
      controller.params[:glm_content] = '_glm_content_'
      controller.params[:glm_source] = '_glm_source_'
      stub_saas_features(onboarding: true)
    end

    it { is_expected.to have_css('form[action="/users?glm_content=_glm_content_&glm_source=_glm_source_"]') }
  end

  context 'when arriving from a self-managed subscription purchase', :saas_onboarding do
    let(:onboarding_status_presenter) do
      ::Onboarding::StatusPresenter.new(
        params.to_unsafe_h.deep_symbolize_keys,
        ::Gitlab::Routing.url_helpers.new_subscriptions_path(
          plan_id: 'abc123', deployment_type: 'self_managed'
        ),
        resource
      )
    end

    before do
      allow(view).to receive(:signup_button_based_providers_enabled?).and_return(false)
    end

    it 'renders two panel layout' do
      render

      expect(rendered).to have_css('[data-testid="registration-two-panel-layout"]')
      expect(rendered).not_to have_css('.signup-page')
    end

    it 'renders the self-managed subtitle' do
      render

      expect(rendered).to include(
        s_('InProductMarketing|Create a GitLab account to purchase the Premium tier of GitLab Self-Managed.')
      )
    end

    it 'does not override the marketing-panel image and heading (uses default)' do
      render

      expect(view.content_for(:registration_marketing_panel_image)).to be_blank
      expect(view.content_for(:registration_marketing_panel_heading)).to be_blank
    end

    context 'when social signin is disabled' do
      it 'does not render omniauth provider buttons' do
        render

        expect(rendered).not_to have_css('form[action*="/users/auth/"]')
      end
    end

    context 'when social signin is enabled' do
      before do
        allow(view).to receive(:signup_button_based_providers_enabled?).and_return(true)
        allow(view).to receive(:enabled_button_based_providers_for_signup).and_return([:github, :google_oauth2])
      end

      it 'renders omniauth provider buttons' do
        render

        expect(rendered).to have_css('form[action*="/users/auth/"]')
      end
    end
  end

  context 'for omniauth provider buttons' do
    before do
      allow(view).to receive(:providers).and_return([:github, :google_oauth2])
    end

    it { is_expected.to have_css('form[action="/users/auth/github"]') }
    it { is_expected.to have_css('form[action="/users/auth/google_oauth2"]') }

    context 'when saas onboarding feature is available' do
      let(:params) do
        controller.params.merge(glm_content: '_glm_content_', glm_source: '_glm_source_')
      end

      let(:action_params) { 'glm_content=_glm_content_&glm_source=_glm_source_&onboarding_status_email_opt_in=true' }

      before do
        stub_saas_features(onboarding: true)
      end

      it { is_expected.to have_css("form[action='/users/auth/github?#{action_params}']") }
      it { is_expected.to have_css("form[action='/users/auth/google_oauth2?#{action_params}']") }
    end

    context 'for the get_started_subtext' do
      before do
        allow(onboarding_status_presenter).to receive(:get_started_subtext).and_return(
          Onboarding::SubscriptionRegistration.get_started_subtext
        )
      end

      it 'renders the get_started_subtext from the onboarding status presenter' do
        is_expected.to include('Create a GitLab account to purchase GitLab Premium.')
      end
    end
  end

  context 'for omniauth provider options in unification-enabled flows' do
    before do
      allow(view).to receive(:signup_button_based_providers_enabled?).and_return(true)
      allow(view).to receive(:unified_registration?).and_return(true)
      allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])
    end

    it 'renders only the popular providers', :aggregate_failures do
      render

      expect(rendered).to have_css('form[action^="/users/auth/github"]')
      expect(rendered).to have_css('form[action^="/users/auth/google_oauth2"]')
      expect(rendered).not_to have_css('form[action^="/users/auth/salesforce"]')
    end
  end

  context 'for unified registration internal events tracking' do
    before do
      allow(view).to receive(:signup_button_based_providers_enabled?).and_return(true)
      allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])
      allow(view).to receive(:unified_registration?).and_return(true)
    end

    context 'when the registration type is unification-enabled for .com' do
      before do
        allow(onboarding_status_presenter).to receive_messages(
          unification_enabled?: true,
          event_label: 'premium_subscription_com'
        )
      end

      it 'fires the render_registration_form event on the registration form with the label' do
        render

        expect(rendered).to have_css(
          '.registration-form[data-event-tracking-load="true"]' \
            '[data-event-tracking="render_registration_form"]' \
            '[data-event-label="premium_subscription_com"]'
        )
      end

      it 'tags the github oauth button with click_registration_cta tracking' do
        render

        expect(rendered).to have_css(
          '[data-event-tracking="click_registration_cta"]' \
            '[data-event-label="premium_subscription_com"]' \
            '[data-event-property="registration_form_github_sso"]'
        )
      end

      it 'tags the google oauth button with click_registration_cta tracking' do
        render

        expect(rendered).to have_css(
          '[data-event-tracking="click_registration_cta"]' \
            '[data-event-label="premium_subscription_com"]' \
            '[data-event-property="registration_form_google_oauth2_sso"]'
        )
      end
    end

    context 'when the registration type is unification-enabled for SM' do
      before do
        allow(onboarding_status_presenter).to receive_messages(
          unification_enabled?: true,
          event_label: 'premium_subscription_sm'
        )
      end

      it 'fires the render_registration_form event on the registration form with the label' do
        render

        expect(rendered).to have_css(
          '.registration-form[data-event-tracking-load="true"]' \
            '[data-event-tracking="render_registration_form"]' \
            '[data-event-label="premium_subscription_sm"]'
        )
      end

      it 'tags the github oauth button with click_registration_cta tracking' do
        render

        expect(rendered).to have_css(
          '[data-event-tracking="click_registration_cta"]' \
            '[data-event-label="premium_subscription_sm"]' \
            '[data-event-property="registration_form_github_sso"]'
        )
      end

      it 'tags the google oauth button with click_registration_cta tracking' do
        render

        expect(rendered).to have_css(
          '[data-event-tracking="click_registration_cta"]' \
            '[data-event-label="premium_subscription_sm"]' \
            '[data-event-property="registration_form_google_oauth2_sso"]'
        )
      end
    end
  end
end
