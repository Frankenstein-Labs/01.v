# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Unified free flow for user picking my team and converting to a trial', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  include TrialHelpers

  where(:case_name, :sign_up_method) do
    [
      ['with regular sign up', -> { regular_sign_up }],
      ['with sso sign up', -> { sso_sign_up }],
      ['with sso sign up through sign in', -> { sso_signup_through_signin }]
    ]
  end

  with_them do
    context 'when remove_onboarding_tutorial_pages is enabled' do
      it 'registers the user, applies a trial, and reaches the new project page', :sidekiq_inline do
        sign_up_method.call

        ensure_onboarding { expect_to_see_unified_welcome_form }

        fills_in_trial_welcome_form(product_interaction: 'SaaS Trial - defaulted')

        click_on 'Continue'

        expect(page).to have_current_path(new_project_path, ignore_query: true)
      end
    end

    context 'when remove_onboarding_tutorial_pages is disabled' do
      it 'registers the user, applies a trial, and reaches onboarding', :sidekiq_inline do
        stub_feature_flags(remove_onboarding_tutorial_pages: false)

        sign_up_method.call

        ensure_onboarding { expect_to_see_unified_welcome_form }

        fills_in_trial_welcome_form(product_interaction: 'SaaS Trial - defaulted')

        click_on 'Continue'

        expect_to_be_in_get_started
      end
    end
  end

  context 'when last name is missing from the SSO provider' do
    context 'when remove_onboarding_tutorial_pages is enabled' do
      it 'shows the name fields on the welcome form, completes the trial, and reaches the new project page',
        :sidekiq_inline do
        sso_sign_up(name: 'Registering')

        ensure_onboarding { expect_to_see_unified_welcome_form }

        expect(page).to have_field('first_name')
        expect(page).to have_field('last_name')

        fill_in 'last_name', with: 'User'

        fills_in_trial_welcome_form(product_interaction: 'SaaS Trial - defaulted')

        click_on 'Continue'

        expect(page).to have_current_path(new_project_path, ignore_query: true)
      end
    end

    context 'when remove_onboarding_tutorial_pages is disabled' do
      it 'shows the name fields on the welcome form, completes the trial, and reaches onboarding',
        :sidekiq_inline do
        stub_feature_flags(remove_onboarding_tutorial_pages: false)

        sso_sign_up(name: 'Registering')

        ensure_onboarding { expect_to_see_unified_welcome_form }

        expect(page).to have_field('first_name')
        expect(page).to have_field('last_name')

        fill_in 'last_name', with: 'User'

        fills_in_trial_welcome_form(product_interaction: 'SaaS Trial - defaulted')

        click_on 'Continue'

        expect_to_be_in_get_started
      end
    end
  end

  context 'with submission failures' do
    context 'when the trial submission fails' do
      it 'allows retry on the trial welcome form and reaches the new project page', :sidekiq_inline do
        regular_sign_up

        ensure_onboarding { expect_to_see_unified_welcome_form }

        fills_in_trial_welcome_form(trial_success: false)

        click_on 'Continue'

        expect(page).to have_content('Trial registration unsuccessful')

        stub_trial_success(product_interaction: 'SaaS Trial - defaulted')

        click_button _('Resubmit request')

        expect(page).to have_current_path(new_project_path, ignore_query: true)
      end
    end

    context 'when project creation fails' do
      it 'allows resubmission on the trial welcome form and reaches the new project page', :sidekiq_inline do
        regular_sign_up

        ensure_onboarding { expect_to_see_unified_welcome_form }

        fills_in_trial_welcome_form(
          project_name: '*Invalid project name',
          product_interaction: 'SaaS Trial - defaulted'
        )

        click_on 'Continue'

        expect(page).to have_field('group_name', disabled: true)

        fill_in 'project_name', with: 'My Project'

        click_on 'Continue'

        expect(page).to have_current_path(new_project_path, ignore_query: true)
      end
    end
  end
end
