# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Subscription flow for self managed purchase', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method) do
    [
      ['with regular sign up', ->(params) { subscription_portal_referrer_sign_up(params) }],
      ['with sso sign up', ->(params) { sso_subscription_portal_referrer_sign_up(params) }]
    ]
  end

  with_them do
    it 'registers the user and redirects to the customers portal interstitial' do
      stub_subscription_plans
      sign_up_method.call(plan_id: premium_plan_id, deployment_type: 'self_managed')

      expect(page).to have_current_path(users_sign_up_customers_portal_redirect_path)
      expect(page).to have_content(s_('SubscriptionRegistration|Complete your purchase'))
      expect(page).not_to have_content('Welcome to GitLab, Registering!')

      click_link s_('SubscriptionRegistration|Continue to Customers Portal')

      expect(page).to have_current_path(
        help_path,
        ignore_query: true
      )
      expect(page).to have_current_path(/auto_submit_sso=true/, url: true)
      expect(page).to have_current_path(/plan_id=#{premium_plan_id}/, url: true)
      expect(page).to have_current_path(/deployment_type=self_managed/, url: true)
    end

    context 'when purchasing credits' do
      it 'registers the user and redirects to the customers portal interstitial' do
        stub_subscription_plans
        sign_up_method.call(plan_type: 'gitlab_credits', deployment_type: 'self_managed')

        expect(page).to have_current_path(users_sign_up_customers_portal_redirect_path)
        expect(page).to have_content(s_('SubscriptionRegistration|Complete your purchase'))

        click_link s_('SubscriptionRegistration|Continue to Customers Portal')

        expect(page).to have_current_path(help_path, ignore_query: true)
        expect(page).to have_current_path(/auto_submit_sso=true/, url: true)
      end
    end
  end

  def stub_subscription_portal_routing
    # Stub CDot redirects since they're not accessible in specs
    help_url = ::Gitlab::Routing.url_helpers.help_url
    allow(::Gitlab::Routing.url_helpers).to receive_messages(
      subscription_portal_new_subscription_url: help_url,
      subscription_portal_new_purchase_url: help_url,
      subscription_portal_self_managed_purchase_credits_url: help_url
    )
  end

  def subscription_portal_referrer_sign_up(params)
    stub_subscription_portal_routing
    stub_signing_key

    new_user = build(:user, name: 'Registering User', email: user_email)

    # Visiting /subscriptions/new with source=subscription_portal triggers
    # ensure_registered! which stores the fullpath (including the source param)
    # in the session and redirects to the registration page. This simulates
    # the same session state that store_subscription_portal_referrer creates
    # when a user arrives at /users/sign_up from customers.gitlab.com.
    visit new_user_registration_path(params)

    perform_enqueued_jobs do
      fill_in_sign_up_form(new_user)

      expect_to_see_account_confirmation_page
    end

    confirm_account
  end

  def sso_subscription_portal_referrer_sign_up(params)
    stub_subscription_portal_routing
    stub_signing_key
    stub_saas_features(identity_verification: true)

    with_omniauth_full_host do
      user_signs_up_with_sso({}, provider: 'google_oauth2') do
        visit new_user_registration_path(params)
      end

      expect_to_see_identity_verification_page

      verify_email
    end

    expect_verification_completed
  end
end
