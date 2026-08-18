# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Secure
          class SecretsManager < QA::Page::Base
            view 'ee/app/assets/javascripts/ci/secrets/components/secrets_empty_state.vue' do
              element 'empty-state-new-secret-button'
            end

            view 'ee/app/assets/javascripts/ci/secrets/components/secrets_table/secrets_table.vue' do
              element 'new-secret-button'
              element 'secret-details-link'
              element 'secret-created-at'
            end

            view 'ee/app/assets/javascripts/ci/secrets/components/secret_form/secret_form.vue' do
              element 'secret-name-field-group'
              element 'secret-value-field-group'
              element 'secret-description-field-group'
              element 'secret-rotation-field-group'
              element 'submit-form-button'
              element 'cancel-button'
            end

            view 'ee/app/assets/javascripts/ci/secrets/components/secret_delete_modal.vue' do
              element 'delete-secret-modal'
            end

            view 'ee/app/assets/javascripts/ci/secrets/components/secret_details/secret_details_wrapper.vue' do
              element 'secret-edit-button'
            end

            def click_new_secret
              if has_element?('empty-state-new-secret-button', wait: 1)
                click_element('empty-state-new-secret-button')
              else
                click_element('new-secret-button')
              end
            end

            def has_new_secret_button?
              has_element?('empty-state-new-secret-button') ||
                has_element?('new-secret-button')
            end

            def create_secret(
              name:, value:, description:, environment: '*', branch: 'main', expiration: nil,
              rotation_days: nil)
              fill_secret_name(name)
              fill_secret_value(value)
              fill_secret_description(description)
              select_environment(environment)
              select_branch(branch)
              set_expiration_date(expiration) if expiration
              set_rotation_period(rotation_days) if rotation_days

              click_element('submit-form-button')
            end

            def fill_secret_name(name)
              within_element('secret-name-field-group') do
                fill_in('secret-name', with: name)
              end
            end

            def fill_secret_value(value)
              within_element('secret-value-field-group') do
                fill_in('secret-value', with: value)
              end
            end

            def fill_secret_description(description)
              within_element('secret-description-field-group') do
                fill_in('secret-description', with: description)
              end
            end

            def select_environment(_environment)
              find('[data-testid="base-dropdown-toggle"]', text: 'Select environment or create wildcard').click
              wait_for_requests
              within('[data-testid="base-dropdown-menu"]') do
                find('li[role="option"]', text: '*').click
              end
            end

            def select_branch(branch)
              dropdowns = all('[data-testid="base-dropdown-toggle"]')
              branch_dropdown = dropdowns.find { |dropdown| dropdown.text.include?('Select branch or create wildcard') }
              branch_dropdown.click
              wait_for_requests
              within('[data-testid="base-dropdown-menu"]') do
                find('li[role="option"]', text: branch).click
              end
            end

            def set_expiration_date(date)
              find('[data-testid="gl-datepicker-input"]').set(date)
            end

            def set_rotation_period(days)
              within_element('secret-rotation-field-group') do
                find('input').set(days)
              end
            end

            def has_permissions_error?
              has_css?('[data-testid="alert-danger"]', wait: 15) ||
                has_css?('.gl-alert.gl-alert-danger', wait: 5) ||
                has_css?('[role="alert"]', wait: 5)
            end

            def has_secret_in_table?(name)
              wait_for_requests

              if has_text?('Stored secrets')
                has_element?('secret-details-link', text: name)
              else
                has_css?('h1.page-title', text: name)
              end
            end

            def click_secret_details(name)
              wait_for_requests
              click_element('secret-details-link', text: name)
            end

            def has_secret_details?(name, description)
              has_text?(name) && has_css?('[data-testid="secret-details-description"]', text: description)
            end

            def click_edit_secret_button
              page.execute_script(
                "document.querySelector(\"[data-testid='secret-edit-button']\").click()"
              )
            end

            def update_secret(
              name: nil, value: nil, description: nil, environment: nil, branch: nil, expiration: nil,
              rotation_days: nil)
              fill_secret_name(name) if name
              fill_secret_value(value) if value
              fill_secret_description(description) if description
              select_environment(environment) if environment
              select_branch(branch) if branch
              set_expiration_date(expiration) if expiration
              set_rotation_period(rotation_days) if rotation_days

              click_element('submit-form-button')
              page.execute_script("document.querySelector('.js-modal-action-primary').click();")
              wait_for_requests
            end

            def delete_secret(name: nil, expect_error: false)
              within('tr', text: name) do
                find('[data-testid="ellipsis_v-icon"]').ancestor('button').click
              end
              within('[data-testid="disclosure-content"]') do
                find('[data-testid="disclosure-dropdown-item"]', text: 'Delete').click
              end

              find('input.gl-form-input.form-control').set(name)
              page.execute_script("document.querySelector('.js-modal-action-primary').click();")
              wait_for_requests unless expect_error
            end

            def has_no_secret?(name)
              has_no_element?('secret-details-link', text: name)
            end

            def go_back_to_secrets_list
              return if has_text?('Stored secrets')

              uri = URI.parse(current_url)
              base_path = uri.path.split('/-/secrets/').first
              visit("#{uri.scheme}://#{uri.host}#{base_path}/-/secrets")
              wait_for_requests
            end

            def has_delete_button?(name)
              within('tr', text: name) do
                has_css?('[data-testid="base-dropdown-toggle"] svg[data-testid="ellipsis_v-icon"]', wait: 5)
              end
            end

            def has_edit_button?
              has_css?('[data-testid="secret-edit-button"]')
            end

            def not_to_have_delete_button
              has_no_css?('[data-testid="base-dropdown-toggle"] svg[data-testid="ellipsis_v-icon"]')
            end

            def not_to_have_edit_button
              has_no_element?('secret-edit-button')
            end

            def has_secret_metadata?(name, environment: nil, branch: nil, created_date: nil)
              row = find('tr', text: name)

              result = true
              result &&= row.has_text?(environment) if environment
              result &&= row.has_text?(branch) if branch
              result &&= row.has_element?('secret-created-at') if created_date

              result
            end
          end
        end
      end
    end
  end
end
