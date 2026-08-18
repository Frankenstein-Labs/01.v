# frozen_string_literal: true

require 'support/helpers/listbox_helpers'
require_relative '../subscription_portal_helpers'

module Features
  module TrialHelpers
    include ListboxHelpers
    include SubscriptionPortalHelpers
    include AgenticChatHelpers

    def expect_to_be_on_group_security_dashboard(group_for_path: group)
      expect(page).to have_current_path(group_security_dashboard_path(group_for_path))
      expect(page).to have_testid('group-security-dashboard')
      within_testid('super-sidebar') do
        expect(page).to have_link(group_for_path.name)
      end
    end

    def expect_to_be_on_gitlab_duo_page(path: 'gitlab', name: 'gitlab')
      expect(page).to have_current_path("/groups/#{path}/-/settings/gitlab_duo")
      within_testid('super-sidebar') do
        expect(page).to have_link(name)
      end
    end

    def expect_to_be_on_group_page(path: 'gitlab', name: 'gitlab')
      expect(page).to have_current_path("/#{path}")
      within_testid('super-sidebar') do
        expect(page).to have_link(name)
      end
    end

    def expect_to_be_on_trial_form_with_name_fields
      within_testid('trial-form') do
        expect(find_by_testid('first-name-field').value).to have_content(user.first_name)
        expect(find_by_testid('last-name-field').value).to have_content(user.last_name)
      end
    end

    def fill_in_trial_selection_form(from: 'Select a group', group_select: true)
      select_from_listbox group.name, from: from if group_select
    end

    def fill_in_trial_form_for_new_group(name: 'gitlab')
      fill_in 'new_group_name', with: name
    end

    def form_data
      {
        phone_number: '+1 23 456-78-90',
        company_name: 'GitLab',
        country: { id: 'US', name: 'United States of America' },
        state: { id: 'CA', name: 'California' }
      }
    end

    def fill_in_company_information_single_step
      fill_in 'company_name', with: form_data[:company_name]
      fill_in 'phone_number', with: form_data[:phone_number]
      select_from_listbox form_data.dig(:country, :name), from: 'Select a country or region'
      select_from_listbox form_data.dig(:state, :name), from: 'Select state or province'
    end

    def fill_in_company_information_single_step_with_last_name(last_name)
      fill_in 'last_name', with: last_name
      fill_in_company_information_single_step
    end

    def resubmit_full_request(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      glm: {}
    )
      # lead
      expect_lead_submission(lead_result, last_name: user.last_name, glm: glm)

      # trial
      if lead_result.success?
        stub_apply_trial(namespace_id: group.id, result: trial_result, extra_params: existing_group_attrs)
        stub_duo_landing_page_data
      end

      click_button 'Resubmit request'

      wait_for_requests
    end

    def duo_enterprise_submit_trial_form(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      glm: {},
      last_name: user.last_name
    )
      stub_ai_cloud_connector

      # lead
      expect_duo_enterprise_lead_submission(lead_result, last_name: last_name, glm: glm)

      # trial
      if lead_result.success?
        stub_apply_duo_enterprise_trial(result: trial_result, extra_params: glm)
        stub_duo_landing_page_data
      end

      click_button 'Activate my trial'

      wait_for_requests
    end

    def duo_enterprise_resubmit_full_request(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      glm: {}
    )
      # lead
      expect_duo_enterprise_lead_submission(lead_result, last_name: user.last_name, glm: glm)

      # trial
      if lead_result.success?
        stub_apply_duo_enterprise_trial(result: trial_result, extra_params: existing_group_attrs)
        stub_duo_landing_page_data
      end

      click_button 'Resubmit request'

      wait_for_requests
    end

    def duo_enterprise_resubmit_trial_request(result: ServiceResponse.success)
      stub_apply_duo_enterprise_trial(result: result, extra_params: existing_group_attrs)
      stub_duo_landing_page_data

      click_button 'Resubmit request'

      wait_for_requests
    end

    def resubmit_trial_request(result: ServiceResponse.success)
      stub_apply_trial(namespace_id: group.id, result: result, extra_params: existing_group_attrs)
      stub_duo_landing_page_data

      click_button 'Resubmit request'

      wait_for_requests
    end

    def duo_pro_submit_trial_form(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      glm: {},
      last_name: user.last_name
    )
      stub_ai_cloud_connector

      # lead
      expect_duo_pro_lead_submission(lead_result, last_name: last_name, glm: glm)

      # trial
      if lead_result.success?
        stub_apply_duo_pro_trial(result: trial_result, extra_params: glm)
        stub_duo_landing_page_data
      end

      click_button 'Activate my trial'

      wait_for_requests
    end

    def duo_pro_resubmit_full_request(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      glm: {}
    )
      # lead
      expect_duo_pro_lead_submission(lead_result, last_name: user.last_name, glm: glm)

      # trial
      if lead_result.success?
        stub_apply_duo_pro_trial(result: trial_result)
        stub_duo_landing_page_data
      end

      click_button 'Resubmit request'

      wait_for_requests
    end

    def duo_pro_resubmit_trial_request(result: ServiceResponse.success)
      stub_apply_duo_pro_trial(result: result)
      stub_duo_landing_page_data

      click_button 'Resubmit request'

      wait_for_requests
    end

    def expect_to_be_on_form_with_trial_submission_error
      expect(page).to have_content('your trial could not be created')
      expect(page).to have_button('Resubmit request')
    end

    def expect_lead_submission(lead_result, glm:, last_name: user.last_name)
      premium = defined?(group) && group.premium_plan?

      trial_user_params = {
        company_name: form_data[:company_name],
        first_name: user.first_name,
        last_name: last_name,
        phone_number: form_data[:phone_number],
        country: form_data.dig(:country, :id),
        work_email: user.email,
        uid: user.id,
        namespace_id: kind_of(Integer),
        trial_type: premium ? GitlabSubscriptions::Trials::PREMIUM_TRIAL_TYPE_V2 : GitlabSubscriptions::Trials::FREE_TRIAL_TYPE_V2,
        setup_for_company: user.onboarding_status_setup_for_company,
        skip_email_confirmation: true,
        existing_plan: defined?(group) ? group.actual_plan_name : 'free',
        gitlab_com_trial: true,
        provider: 'gitlab',
        state: form_data.dig(:state, :id)
      }.merge(glm)

      expect_next_instance_of(GitlabSubscriptions::CreateLeadService) do |service|
        expect(service).to receive(:execute).with({ trial_user: trial_user_params }).and_return(lead_result)
      end
    end

    def expect_duo_enterprise_lead_submission(lead_result, glm:, last_name: user.last_name)
      trial_user_params = {
        company_name: form_data[:company_name],
        first_name: user.first_name,
        last_name: last_name,
        phone_number: form_data[:phone_number],
        country: form_data.dig(:country, :id),
        work_email: user.email,
        uid: user.id,
        namespace_id: kind_of(Integer),
        setup_for_company: user.onboarding_status_setup_for_company,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        state: form_data.dig(:state, :id),
        product_interaction: 'duo_enterprise_trial',
        preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
        opt_in: user.onboarding_status_email_opt_in,
        add_on_name: 'duo_enterprise',
        existing_plan: 'ultimate'
      }.merge(glm)

      expect_next_instance_of(GitlabSubscriptions::Trials::CreateAddOnLeadService) do |service|
        expect(service).to receive(:execute).with({ trial_user: trial_user_params }).and_return(lead_result)
      end
    end

    def expect_duo_pro_lead_submission(lead_result, glm:, last_name: user.last_name)
      trial_user_params = {
        company_name: form_data[:company_name],
        first_name: user.first_name,
        last_name: last_name,
        phone_number: form_data[:phone_number],
        country: form_data.dig(:country, :id),
        work_email: user.email,
        uid: user.id,
        namespace_id: kind_of(Integer),
        setup_for_company: user.onboarding_status_setup_for_company,
        skip_email_confirmation: true,
        gitlab_com_trial: true,
        provider: 'gitlab',
        state: form_data.dig(:state, :id),
        product_interaction: 'duo_pro_trial',
        preferred_language: ::Gitlab::I18n.trimmed_language_name(user.preferred_language),
        opt_in: user.onboarding_status_email_opt_in,
        add_on_name: 'code_suggestions',
        existing_plan: 'premium'
      }.merge(glm)

      expect_next_instance_of(GitlabSubscriptions::Trials::CreateAddOnLeadService) do |service|
        expect(service).to receive(:execute).with({ trial_user: trial_user_params }).and_return(lead_result)
      end
    end

    def submit_new_group_trial_form(
      lead_result: ServiceResponse.success,
      trial_result: ServiceResponse.success,
      glm: {},
      extra_params: {},
      licensed_features: {}
    )
      stub_ai_cloud_connector

      # lead
      expect_lead_submission(lead_result, glm: glm)

      # trial
      if lead_result.success?
        stub_apply_trial(result: trial_result, extra_params: extra_params.merge(glm))
        stub_duo_landing_page_data(extra_features: licensed_features)
      end

      click_button 'Activate my trial'

      wait_for_requests
    end

    def update_with_applied_trials
      group = Group.last
      plan = create(:ultimate_trial_plan)
      group.gitlab_subscription.update!(
        hosted_plan: plan, trial: true, end_date: Time.current + 60.days, trial_starts_on: Time.current,
        trial_ends_on: Time.current + 60.days
      )
    end

    def stub_duo_landing_page_data(extra_features: {})
      stub_licensed_features({ code_suggestions: true }.merge(extra_features))
      stub_signing_key
    end

    def stub_ai_cloud_connector
      allow_next_instance_of(Ai::ModelSelection::FetchModelDefinitionsService) do |instance|
        allow(instance).to receive(:execute).and_return(ServiceResponse.error(message: '_fail_'))
      end
    end

    def existing_group_attrs
      { namespace: group.slice(:id, :name, :path, :kind, :trial_ends_on).merge(plan: group.actual_plan.name) }
    end

    def new_group_attrs(path: 'gitlab', name: 'gitlab')
      {
        namespace: {
          id: anything,
          path: path,
          name: name,
          kind: 'group',
          trial_ends_on: nil,
          plan: 'free'
        }
      }
    end

    def stub_apply_trial(namespace_id: anything, result: ServiceResponse.success, extra_params: {})
      trial_user_params = {
        namespace_id: namespace_id,
        gitlab_com_trial: true,
        sync_to_gl: true
      }.merge(extra_params)

      service_params = {
        trial_user_information: trial_user_params,
        uid: user.id
      }

      expect_next_instance_of(GitlabSubscriptions::Trials::ApplyTrialService, service_params) do |instance|
        expect(instance).to receive(:execute) do
          if result.success?
            update_with_applied_trials
            result = ServiceResponse.success
          end

          result
        end
      end
    end

    def stub_apply_duo_pro_trial(result: ServiceResponse.success, extra_params: {})
      trial_user_params = {
        namespace_id: group.id,
        gitlab_com_trial: true,
        sync_to_gl: true
      }.merge(existing_group_attrs).merge(extra_params)

      service_params = {
        trial_user_information: trial_user_params,
        uid: user.id
      }

      expect_next_instance_of(GitlabSubscriptions::Trials::ApplyDuoProService, service_params) do |instance|
        expect(instance).to receive(:execute) do
          if result.success?
            add_on_purchase = update_with_duo_pro_trial
            result = ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
          end

          result
        end
      end
    end

    def update_with_duo_pro_trial
      group = Group.last
      add_on = GitlabSubscriptions::AddOn.find_by_name('code_suggestions')
      add_on_purchase = create(:gitlab_subscription_add_on_purchase, :trial, add_on: add_on, namespace: group)

      # stub needed for landing on the duo page
      stub_subscription_permissions_data(group.id)

      add_on_purchase
    end

    def stub_apply_duo_enterprise_trial(result: ServiceResponse.success, extra_params: {})
      trial_user_params = {
        namespace_id: group.id,
        gitlab_com_trial: true,
        sync_to_gl: true
      }.merge(existing_group_attrs).merge(extra_params)

      service_params = {
        trial_user_information: trial_user_params,
        uid: user.id
      }

      expect_next_instance_of(GitlabSubscriptions::Trials::ApplyDuoEnterpriseService, service_params) do |instance|
        expect(instance).to receive(:execute) do
          if result.success?
            add_on_purchase = update_with_duo_enterprise_trial
            result = ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
          end

          result
        end
      end
    end

    def update_with_duo_enterprise_trial
      group = Group.last
      add_on = GitlabSubscriptions::AddOn.find_by_name('duo_enterprise')
      add_on_purchase = create(:gitlab_subscription_add_on_purchase, :trial, add_on: add_on, namespace: group)

      # stub needed for landing on the duo page
      stub_subscription_permissions_data(group.id)

      add_on_purchase
    end

    def trial_failure
      ServiceResponse
        .error(message: '_trial_fail_', reason: GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR)
    end

    def lead_failure
      ServiceResponse.error(message: '_lead_fail_', reason: :lead_failed)
    end

    def expect_dap_panel_to_be_visible
      open_current_thread

      within_testid('chat-component') do
        expect(page).to have_content('GitLab Duo Agent Platform')
      end

      clear_browser_logs
    end
  end
end
