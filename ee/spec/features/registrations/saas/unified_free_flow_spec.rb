# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Unified free flow for user picking just me and creating a project', :js, :saas_registration, :with_current_organization, feature_category: :onboarding do
  where(:case_name, :sign_up_method) do
    [
      ['with regular sign up', -> { regular_sign_up }],
      ['with sso sign up', -> { sso_sign_up }]
    ]
  end

  with_them do
    context 'when remove_onboarding_tutorial_pages is enabled' do
      it 'registers the user and creates a group and project reaching the new project page', :sidekiq_inline do
        sign_up_method.call

        ensure_onboarding { expect_to_see_unified_welcome_form }
        expect_to_send_iterable_request(comment: nil)

        fills_in_unified_welcome_form
        click_on 'Continue'

        expect(page).to have_current_path(new_project_path, ignore_query: true)
      end
    end

    context 'when remove_onboarding_tutorial_pages is disabled' do
      it 'registers the user and creates a group and project reaching onboarding', :sidekiq_inline do
        stub_feature_flags(remove_onboarding_tutorial_pages: false)

        sign_up_method.call

        ensure_onboarding { expect_to_see_unified_welcome_form }
        expect_to_send_iterable_request(comment: nil)

        fills_in_unified_welcome_form
        click_on 'Continue'

        expect_to_be_in_learn_gitlab
      end
    end
  end

  context 'when last name is missing from the SSO provider' do
    it 'shows the name fields on the welcome form and reaches the new project page', :sidekiq_inline do
      sso_sign_up(name: 'Registering')

      ensure_onboarding { expect_to_see_unified_welcome_form }

      expect(page).to have_field('first_name')
      expect(page).to have_field('last_name')

      fill_in 'last_name', with: 'User'

      fills_in_unified_welcome_form
      click_on 'Continue'

      expect(page).to have_current_path(new_project_path, ignore_query: true)
    end
  end

  context 'when project creation fails on the first submit' do
    it 're-renders the form, then resubmits without re-creating the group', :sidekiq_inline do
      regular_sign_up

      ensure_onboarding { expect_to_see_unified_welcome_form }

      fills_in_unified_welcome_form(project_name: '*Invalid project name')
      click_on 'Continue'

      expect(page).to have_field('group_name', disabled: true)

      fill_in 'project_name', with: 'Test Project'
      click_on 'Continue'

      expect(page).to have_current_path(new_project_path, ignore_query: true)
    end
  end
end
