# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'trial_registrations/new', feature_category: :acquisition do
  let(:resource) { Users::AuthorizedBuildService.new(nil, {}).execute }
  let(:social_signin_enabled) { false }
  let(:params) { controller.params }
  let(:onboarding_status_presenter) do
    ::Onboarding::StatusPresenter.new(params.to_unsafe_h.deep_symbolize_keys, nil, resource)
  end

  before do
    allow(view).to(
      receive_messages(
        onboarding_status_presenter: onboarding_status_presenter,
        arkose_labs_enabled?: false,
        resource: resource,
        resource_name: :user,
        preregistration_tracking_label: 'trial_registration',
        social_signin_enabled?: social_signin_enabled
      )
    )
    view.lookup_context.prefixes << 'devise/registrations'
    allow(view).to receive(:signup_submit_button_data).and_return({})
  end

  subject { render && rendered }

  it 'sets content_for hide_empty_navbar to true' do
    render

    expect(view.content_for(:hide_empty_navbar)).to be_truthy
  end

  it 'has start self-managed link with correct URL' do
    render

    href = promo_url(path: '/free-trial', query: { hosted: 'self-managed' })
    expect(rendered).to have_link(s_('InProductMarketing|Start a Self-Managed trial'), href: href)
  end

  it 'renders Duo Agent Platform copy' do
    render

    expect(rendered).to have_content('GitLab Duo Agent Platform')
  end

  describe 'trial subtext' do
    context 'when trial unification is enabled' do
      before do
        allow(::Onboarding::TrialRegistration).to receive(:unification_enabled?).and_return(true)
      end

      it 'renders the registration type subtext and not the legacy copy', :aggregate_failures do
        render

        expect(rendered).to have_content('no credit card required')
        expect(rendered).not_to have_content('automate development tasks with AI agents')
      end
    end

    context 'when trial unification is disabled' do
      before do
        allow(::Onboarding::TrialRegistration).to receive(:unification_enabled?).and_return(false)
      end

      it 'renders the legacy trial subtext', :aggregate_failures do
        render

        expect(rendered).to have_content('automate development tasks with AI agents')
        expect(rendered).not_to have_content('no credit card required')
      end
    end
  end

  describe 'registration layout' do
    it 'renders the two-panel layout without the card', :aggregate_failures do
      render

      expect(rendered).to have_css('[data-testid="registration-two-panel-layout"]')
      expect(rendered).to have_css('.registration-form-footer')
      expect(rendered).not_to have_css('.gl-rounded-t-lg')
    end
  end

  context 'when social signin is disabled' do
    it 'does not render social signin section' do
      render

      expect(rendered).not_to have_css('form[action*="/users/auth/"]')
    end
  end

  context 'when social signin is enabled' do
    let(:social_signin_enabled) { true }

    before do
      allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])
    end

    it 'renders social signin section' do
      render

      expect(rendered).to have_content(_('or'))
      expect(rendered).to have_content(format(_('Continue with %{provider}'), provider: 'GitHub'))
    end

    it 'renders full-width "Continue with" omniauth buttons without a separate label', :aggregate_failures do
      allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])

      render

      expect(rendered).to have_css('.gl-flex.gl-gap-3.gl-flex-col form[action*="/users/auth/"]')
      expect(rendered).to have_content(format(_('Continue with %{provider}'), provider: 'GitHub'))
      expect(rendered).to have_content(format(_('Continue with %{provider}'), provider: 'Google'))
    end
  end

  it { is_expected.to have_content(s_('InProductMarketing|Get Started with GitLab')) }

  it { is_expected.to have_content(_('First name')) }
  it { is_expected.to have_content(_('Last name')) }

  it { is_expected.to have_content(_('Company email')) }
  it { is_expected.to have_content(_('We recommend a work email address.')) }

  it { is_expected.not_to have_content(_('Must be between 8-128 characters')) }
  it { is_expected.not_to have_content(_('Cannot use common phrases (e.g. "password")')) }
  it { is_expected.not_to have_content(_('Cannot include your name, username, or email')) }

  it 'renders the Vue submit button mount point' do
    render

    expect(rendered).to have_css('#js-signup-submit-button')
  end

  it { is_expected.to have_content(s_('InProductMarketing|Want to host GitLab on your servers?')) }

  it 'has start self-managed link' do
    href = promo_url(path: '/free-trial', query: { hosted: 'self-managed' })
    is_expected.to have_link(s_('InProductMarketing|Start a Self-Managed trial'), href: href)
  end

  context 'for password form' do
    before do
      allow(view).to receive(:social_signin_enabled?).and_return(true)
      controller.params[:glm_content] = '_glm_content_'
      controller.params[:glm_source] = '_glm_source_'
      stub_saas_features(onboarding: true)
    end

    it do
      is_expected.to have_css('form[action="/-/trial_registrations?glm_content=_glm_content_&glm_source=_glm_source_"]')
    end
  end

  context 'for omniauth provider buttons' do
    let(:params) do
      controller.params.merge(glm_content: '_glm_content_', glm_source: '_glm_source_')
    end

    let(:action_params) do
      'glm_content=_glm_content_&glm_source=_glm_source_&onboarding_status_email_opt_in=true&trial=true'
    end

    before do
      allow(view).to receive(:social_signin_enabled?).and_return(true)
      allow(view).to receive(:popular_enabled_button_based_providers).and_return([:github, :google_oauth2])
      stub_saas_features(onboarding: true) # for trials this view it isn't reachable in the false case
    end

    it { is_expected.to have_css("form[action='/users/auth/github?#{action_params}']") }
    it { is_expected.to have_css("form[action='/users/auth/google_oauth2?#{action_params}']") }
  end
end
