# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Trial lead submission and creation with multiple eligible namespaces', :saas_trial, :js, :use_clean_rails_memory_store_caching, feature_category: :acquisition do
  let_it_be(:user) { create(:user) } # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
  let_it_be(:group) do # rubocop:disable Gitlab/RSpec/AvoidSetup -- to skip registration and creating group
    create(:group, owners: user)
    create(:group, name: 'gitlab', owners: user)
  end

  before_all do
    create(:gitlab_subscription_add_on, :duo_enterprise)
  end

  context 'when creating lead and applying trial is successful' do
    it 'fills out form, submits and lands on the duo page' do
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information_single_step
      fill_in_trial_selection_form

      submit_trial_form

      expect_to_be_on_group_page
    end

    context 'when new trial is selected from within an existing namespace' do
      it 'fills out form, has the existing namespace preselected, submits and lands on the duo page' do
        glm_params = { glm_source: '_glm_source_', glm_content: '_glm_content_' }

        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path(namespace_id: group.id, **glm_params)

        fill_in_company_information_single_step
        fill_in_trial_selection_form(from: group.name)

        submit_trial_form(glm: glm_params)

        expect_to_be_on_group_page
      end

      it 'fills out form, has the existing namespace preselected, and creates a new group instead' do
        glm_params = { glm_source: '_glm_source_', glm_content: '_glm_content_' }

        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path(namespace_id: group.id, **glm_params)

        fill_in_company_information_single_step

        group_path = 'gitlab1'

        select_create_from_listbox 'Create group', from: group.name
        fill_in_trial_form_for_new_group name: group.name

        submit_new_group_trial_form(glm: glm_params, extra_params: new_group_attrs(path: group_path))

        expect_to_be_on_group_page(path: group_path)
      end
    end

    context 'when part of the discover security flow' do
      it 'fills out form, submits and lands on the group security dashboard page' do
        sign_in(user)

        stub_cdot_namespace_eligible_trials
        visit new_trial_path(glm_content: 'discover-group-security')

        fill_in_company_information_single_step
        fill_in_trial_selection_form

        submit_trial_form(
          glm: { glm_content: 'discover-group-security' },
          licensed_features: { security_dashboard: true }
        )

        expect_to_be_on_group_security_dashboard
      end
    end
  end

  context 'when selecting to create a new group with an existing group name' do
    it 'fills out form, submits and lands on the duo page with a unique path' do
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information_single_step
      select_create_from_listbox 'Create group', from: 'Select a group'
      wait_for_requests

      # success
      group_name = 'gitlab1'
      fill_in_trial_selection_form_for_new_group

      submit_new_group_trial_form(extra_params: new_group_attrs(path: group_name))

      expect_to_be_on_group_page(path: group_name)
    end
  end

  context 'when selecting to create a new group with an invalid group name' do
    it 'fills out form, submits and is presented with error then fills out valid name' do
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information_single_step
      select_create_from_listbox 'Create group', from: 'Select a group'
      wait_for_requests

      # namespace invalid check
      fill_in_trial_selection_form_for_new_group(name: '_invalid group name_')

      click_button 'Activate my trial'

      expect_to_be_on_group_creation_with_selection
      expect_to_have_group_creation_errors

      # success when choosing a valid name instead
      group_name = 'valid'
      fill_in_trial_selection_form_for_new_group(name: group_name)

      submit_new_group_trial_form(extra_params: new_group_attrs(path: group_name, name: group_name))

      expect_to_be_on_group_page(path: group_name, name: group_name)
    end
  end

  context 'when applying lead fails' do
    it 'fills out form, submits and sent back to information form with errors and is then resolved' do
      # setup
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information_single_step
      fill_in_trial_selection_form

      # lead failure
      submit_trial_form(lead_result: lead_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      resubmit_full_request

      expect_to_be_on_group_page
    end
  end

  context 'when applying trial fails' do
    it 'fills out form, submits and is sent to select namespace with errors and is then resolved' do
      # setup
      sign_in(user)

      stub_cdot_namespace_eligible_trials
      visit new_trial_path

      fill_in_company_information_single_step
      fill_in_trial_selection_form

      # trial failure
      submit_trial_form(trial_result: trial_failure)

      expect_to_be_on_form_with_trial_submission_error

      # success
      resubmit_trial_request

      expect_to_be_on_group_page
    end
  end

  def expect_to_be_on_group_creation_with_selection
    within_testid('trial-form') do
      expect(page).to have_content('Your trial will be applied to this group')
      expect(page).to have_content('New group name')
    end
  end

  def expect_to_have_group_creation_errors(group_name: '_invalid group name_', error_message: 'Group URL can')
    wait_for_all_requests

    within_testid('trial-form') do
      expect(page.find_field('new_group_name').value).to eq(group_name)
      expect(page).to have_content(error_message)
    end
  end

  def submit_trial_form(
    lead_result: ServiceResponse.success,
    trial_result: ServiceResponse.success,
    extra_params: {},
    glm: {},
    licensed_features: {}
  )
    stub_ai_cloud_connector

    # lead
    expect_lead_submission(lead_result, glm: glm)

    # trial
    if lead_result.success? # rubocop:disable RSpec/AvoidConditionalStatements -- Not a concern for the cop's reasons
      stub_apply_trial(
        namespace_id: group.id,
        result: trial_result,
        extra_params: extra_params.merge(existing_group_attrs).merge(glm)
      )
      stub_duo_landing_page_data(extra_features: licensed_features)
    end

    click_button 'Activate my trial'

    wait_for_requests
  end

  def fill_in_trial_selection_form_for_new_group(name: 'gitlab')
    within_testid('trial-form') do
      expect(page).to have_text('New group name')
    end

    fill_in_trial_form_for_new_group(name: name)
  end
end
