# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Subscription flow for user creating group and project for paid plan', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method) do
    [
      ['with regular sign up', -> { subscription_regular_sign_up }],
      ['with sso sign up', -> { sso_subscription_sign_up }]
    ]
  end

  with_them do
    it 'registers the user and redirects to interstitial page' do
      stub_subscription_plans
      sign_up_method.call

      expect_to_create_lead
      expect_to_see_subscription_welcome_form

      fills_in_welcome_form
      click_on 'Continue'

      expect_to_see_interstitial_page
    end
  end

  def fills_in_welcome_form
    fill_in 'company_name', with: 'Test'
    fill_in 'group_name', with: 'Test'
    fill_in 'project_name', with: 'Test'
  end

  def expect_to_see_subscription_welcome_form
    expect(page).to have_content('Welcome to GitLab')
    expect(page).to have_content('Set up your GitLab environment.')

    page.within(subscription_welcome_form_selector) do
      expect(page).to have_content('Company name')
      expect(page).to have_field('company_name')
      expect(page).to have_content('Group name')
      expect(page).to have_field('group_name')
      expect(page).to have_content('Project name')
      expect(page).to have_field('project_name')
    end
  end

  def expect_to_see_interstitial_page
    expect(page).to have_content('Complete your purchase')
    expect(page).to have_content("You'll use your GitLab.com account to access Customers Portal")
  end

  def expect_to_create_lead
    expect_create_hand_raise_lead_success(
      work_email: 'onboardinguser@example.com',
      opt_in: true,
      skip_country_validation: true,
      product_interaction: 'Direct Purchase Account Creation Premium Dotcom',
      plan_id: 'premium-plan-id',
      first_name: 'Registering',
      last_name: 'User',
      company_name: 'Test'
    )
  end

  def subscription_welcome_form_selector
    '[data-testid="subscription-welcome-form"]'
  end
end
