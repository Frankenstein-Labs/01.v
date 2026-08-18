# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial flow', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method) do
    [
      ['with regular trial sign up', ->(params) { trial_registration_sign_up(params) }],
      ['with sso trial sign up', ->(params) { sso_trial_registration_sign_up(params) }]
    ]
  end

  with_them do
    context 'when remove_onboarding_tutorial_pages is enabled' do
      it 'registers the user and creates a group and project reaching the new project page', :sidekiq_inline do
        sign_up_method.call(glm_params)

        ensure_onboarding { expect_to_see_trial_welcome_form }

        fills_in_trial_welcome_form

        click_button 'Continue'

        expect(page).to have_current_path(new_project_path, ignore_query: true)
      end
    end

    context 'when remove_onboarding_tutorial_pages is disabled' do
      it 'registers the user and creates a group and project reaching onboarding', :sidekiq_inline do
        stub_feature_flags(remove_onboarding_tutorial_pages: false)

        sign_up_method.call(glm_params)

        ensure_onboarding { expect_to_see_trial_welcome_form }

        fills_in_trial_welcome_form

        click_button 'Continue'

        expect_to_be_in_get_started
      end
    end
  end

  context 'when last name is missing from SSO provider' do
    context 'when remove_onboarding_tutorial_pages is enabled' do
      it 'shows name fields on welcome page and completes registration to the new project page', :sidekiq_inline do
        sso_trial_registration_sign_up(name: 'Registering')

        expect_to_see_trial_welcome_form

        expect(page).to have_field('first_name')
        expect(page).to have_field('last_name')

        fill_in 'last_name', with: 'User'

        fills_in_trial_welcome_form

        click_button 'Continue'

        expect(page).to have_current_path(new_project_path, ignore_query: true)
      end
    end

    context 'when remove_onboarding_tutorial_pages is disabled' do
      it 'shows name fields on welcome page and completes registration', :sidekiq_inline do
        stub_feature_flags(remove_onboarding_tutorial_pages: false)

        sso_trial_registration_sign_up(name: 'Registering')

        expect_to_see_trial_welcome_form

        expect(page).to have_field('first_name')
        expect(page).to have_field('last_name')

        fill_in 'last_name', with: 'User'

        fills_in_trial_welcome_form

        click_button 'Continue'

        expect_to_be_in_get_started
      end
    end
  end

  context 'with submission failures' do
    context 'when model errors occur on form submission' do
      context 'when remove_onboarding_tutorial_pages is enabled' do
        it 'allows form resubmission to the new project page', :sidekiq_inline do
          trial_registration_sign_up

          expect_to_see_trial_welcome_form

          fills_in_trial_welcome_form

          fill_in 'project_name', with: '*Invalid project name'

          click_button 'Continue'

          expect(find_by_testid("group-name-input").disabled?).to be(true)

          fill_in 'project_name', with: 'My Project'

          click_button 'Continue'

          expect(page).to have_current_path(new_project_path, ignore_query: true)
        end
      end

      context 'when remove_onboarding_tutorial_pages is disabled' do
        it 'allows form resubmission', :sidekiq_inline do
          stub_feature_flags(remove_onboarding_tutorial_pages: false)

          trial_registration_sign_up

          expect_to_see_trial_welcome_form

          fills_in_trial_welcome_form

          fill_in 'project_name', with: '*Invalid project name'

          click_button 'Continue'

          expect(find_by_testid("group-name-input").disabled?).to be(true)

          fill_in 'project_name', with: 'My Project'

          click_button 'Continue'

          expect_to_be_in_get_started
        end
      end
    end

    context 'when trial submission fails' do
      context 'when remove_onboarding_tutorial_pages is enabled' do
        it 'allows retry to the new project page', :sidekiq_inline do
          trial_registration_sign_up

          expect_to_see_trial_welcome_form

          fills_in_trial_welcome_form(trial_success: false)

          click_button 'Continue'

          expect(page).to have_content("Trial registration unsuccessful")

          stub_trial_success

          click_button _('Resubmit request')

          expect(page).to have_current_path(new_project_path, ignore_query: true)
        end
      end

      context 'when remove_onboarding_tutorial_pages is disabled' do
        it 'allows retry', :sidekiq_inline do
          stub_feature_flags(remove_onboarding_tutorial_pages: false)

          trial_registration_sign_up

          expect_to_see_trial_welcome_form

          fills_in_trial_welcome_form(trial_success: false)

          click_button 'Continue'

          expect(page).to have_content("Trial registration unsuccessful")

          stub_trial_success

          click_button _('Resubmit request')

          expect_to_be_in_get_started
        end
      end
    end
  end
end
