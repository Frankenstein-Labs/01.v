# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Pro trial lead submission and creation with one eligible namespace', :saas_trial, :js, feature_category: :acquisition do
  # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :premium_plan, name: 'gitlab', owners: user) }

  before_all do
    create(:gitlab_subscription_add_on, :duo_pro)
  end
  # rubocop:enable Gitlab/RSpec/AvoidSetup

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the group duo page' do
      sign_in(user)

      visit new_trials_duo_pro_path

      fill_in_company_information_single_step

      duo_pro_submit_trial_form

      expect_to_be_on_gitlab_duo_page
    end

    context 'when last name is blank' do
      it 'fills out form, submits and lands on the duo page' do
        user.update!(name: 'Bob')

        sign_in(user)

        visit new_trials_duo_pro_path

        expect_to_be_on_trial_form_with_name_fields

        fill_in_company_information_single_step_with_last_name('Smith')

        duo_pro_submit_trial_form(last_name: 'Smith')

        expect_to_be_on_gitlab_duo_page
      end
    end
  end

  context 'when applying lead fails' do
    it 'fills out form, submits and sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trials_duo_pro_path

      fill_in_company_information_single_step

      # lead failure
      duo_pro_submit_trial_form(lead_result: lead_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      duo_pro_resubmit_full_request

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trials_duo_pro_path

      fill_in_company_information_single_step

      # trial failure
      duo_pro_submit_trial_form(trial_result: trial_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      duo_pro_resubmit_trial_request

      expect_to_be_on_gitlab_duo_page
    end
  end
end
