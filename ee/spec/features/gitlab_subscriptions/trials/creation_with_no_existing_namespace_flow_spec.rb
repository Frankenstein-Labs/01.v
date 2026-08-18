# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial lead submission, group and trial creation', :with_current_organization, :saas_trial, :js, :use_clean_rails_memory_store_caching, feature_category: :acquisition do
  let_it_be_with_reload(:user) { create(:user, organizations: [current_organization]) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- We need to ensure user is member of current organization

  before_all do
    create(:gitlab_subscription_add_on, :duo_enterprise)
  end

  context 'when creating group, lead and applying trial is successful' do
    it 'fills out form, testing validations, submits and lands on the duo page' do
      sign_in(user)

      visit new_trial_path

      fill_in_company_information_single_step

      click_button 'Activate my trial'

      within_testid('trial-form') do
        expect(page).to have_content('You must enter a new group name.')
      end

      # namespace invalid check
      fill_in_trial_form_for_new_group(name: '_invalid group name_')

      click_button 'Activate my trial'

      expect_to_be_on_group_creation
      expect_to_have_group_creation_errors

      # namespace filled out with blank spaces
      fill_in_trial_form_for_new_group(name: '  ')

      click_button 'Activate my trial'

      expect_to_be_on_group_creation
      expect_to_have_group_creation_errors(group_name: '  ', error_message: "Name can't be blank")

      # success
      fill_in_trial_form_for_new_group

      submit_new_group_trial_form(extra_params: new_group_attrs)

      expect_to_be_on_group_page
    end

    context 'when part of the discover security flow' do
      it 'fills out form, submits and lands on the group security dashboard page' do
        sign_in(user)

        visit new_trial_path(glm_content: 'discover-group-security')

        fill_in_company_information_single_step
        fill_in_trial_form_for_new_group

        submit_new_group_trial_form(
          glm: { glm_content: 'discover-group-security' },
          extra_params: new_group_attrs,
          licensed_features: { security_dashboard: true }
        )

        expect_to_be_on_group_security_dashboard(group_for_path: Group.last)
      end
    end
  end

  context 'when applying lead fails' do
    it 'fills out form, submits and sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      visit new_trial_path

      fill_in_company_information_single_step
      fill_in_trial_form_for_new_group

      # lead failure
      submit_new_group_trial_form(lead_result: lead_failure, extra_params: new_group_attrs)

      expect_to_be_on_form_with_trial_submission_error

      # success
      stub_cdot_namespace_eligible_trials
      resubmit_full_request

      expect_to_be_on_group_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent to select namespace with errors and is then resolved' do
      sign_in(user)

      visit new_trial_path

      fill_in_company_information_single_step
      fill_in_trial_form_for_new_group

      # trial failure
      stub_cdot_namespace_eligible_trials

      submit_new_group_trial_form(trial_result: trial_failure, extra_params: new_group_attrs)

      expect_to_be_on_form_with_trial_submission_error # TODO: clean this up
      # Fail again here to ensure form stays same and also readonly

      # success
      resubmit_trial_request(extra_params: new_group_attrs)

      expect_to_be_on_group_page
    end
  end

  context 'when user cannot create groups' do
    it 'fails and redirects to not found' do
      user.update_attribute(:can_create_group, false)

      sign_in(user)

      visit new_trial_path

      fill_in_company_information_single_step
      fill_in_trial_form_for_new_group

      click_button 'Activate my trial'

      expect(page).to have_content('Page not found')
    end
  end

  def expect_to_be_on_group_creation
    within_testid('trial-form') do
      expect(page).to have_content('New group name')
      expect(page).not_to have_content('Your trial will be applied to this group')
    end
  end

  def expect_to_have_group_creation_errors(group_name: '_invalid group name_', error_message: 'Group URL can')
    wait_for_all_requests

    within_testid('trial-form') do
      expect(page).not_to have_content('Your trial will be applied to this group')
      expect(page.find_field('new_group_name').value).to eq(group_name)
      expect(page).to have_content(error_message)
    end
  end

  def resubmit_full_request(
    lead_result: ServiceResponse.success,
    trial_result: ServiceResponse.success,
    glm: {}
  )
    # lead
    expect_lead_submission(lead_result, glm: glm)

    # trial
    if lead_result.success? # rubocop:disable RSpec/AvoidConditionalStatements -- Not a concern for the cop's reasons
      stub_apply_trial(result: trial_result, extra_params: new_group_attrs)
      stub_duo_landing_page_data
    end

    click_button 'Resubmit request'

    wait_for_requests
  end

  def resubmit_trial_request(result: ServiceResponse.success, extra_params: {})
    stub_apply_trial(result: result, extra_params: extra_params)
    stub_duo_landing_page_data

    click_button 'Resubmit request'
  end
end
