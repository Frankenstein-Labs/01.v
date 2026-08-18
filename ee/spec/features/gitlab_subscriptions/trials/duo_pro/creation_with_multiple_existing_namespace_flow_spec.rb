# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Pro trial lead submission and creation with multiple eligible namespaces', :saas_trial, :js, feature_category: :acquisition do
  # rubocop:disable Gitlab/RSpec/AvoidSetup -- skip registration and group creation
  let_it_be(:user) { create(:user) }
  let_it_be(:group) do
    create(:group_with_plan, plan: :premium_plan, owners: user)
    create(:group_with_plan, plan: :premium_plan, name: 'gitlab', owners: user)
  end

  before_all do
    create(:gitlab_subscription_add_on, :duo_pro)
  end
  # rubocop:enable Gitlab/RSpec/AvoidSetup

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the group duo page' do
      sign_in(user)

      visit new_trials_duo_pro_path

      fill_in_company_information_single_step
      fill_in_trial_selection_form

      duo_pro_submit_trial_form

      expect_to_be_on_gitlab_duo_page
    end

    context 'when new trial is selected from within an existing namespace' do
      it 'fills out form, has the existing namespace preselected, submits and lands on the group duo page' do
        glm_params = { glm_source: '_glm_source_', glm_content: '_glm_content_' }

        sign_in(user)

        visit new_trials_duo_pro_path(namespace_id: group.id, **glm_params)

        fill_in_company_information_single_step
        fill_in_trial_selection_form(from: group.name)

        duo_pro_submit_trial_form(glm: glm_params)

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
      fill_in_trial_selection_form

      # lead failure
      duo_pro_submit_trial_form(lead_result: lead_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      duo_pro_resubmit_full_request

      expect_to_be_on_gitlab_duo_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent to select namespace with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trials_duo_pro_path

      fill_in_company_information_single_step
      fill_in_trial_selection_form

      # trial failure
      duo_pro_submit_trial_form(trial_result: trial_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      duo_pro_resubmit_trial_request

      expect_to_be_on_gitlab_duo_page
    end
  end
end
