# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          module General
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                prepend ::QA::Page::Component::Dropdown
                prepend ::QA::Page::Settings::Common
                include Page::Component::SecretsManagerSettings
                include Page::Component::SecretsManagerPermissions

                view 'ee/app/views/groups/_custom_project_templates_setting.html.haml' do
                  element 'custom-project-templates-container'
                  element 'save-changes-button'
                end

                view 'ee/app/assets/javascripts/pages/groups/edit/index.js' do
                  element 'ip-restriction-field'
                end

                view 'ee/app/views/groups/_member_lock_setting.html.haml' do
                  element 'membership-lock-checkbox'
                end

                view 'ee/app/views/groups/settings/_prevent_forking.html.haml' do
                  element 'prevent-forking-outside-group-checkbox'
                end

                view 'ee/app/views/shared/_repository_size_limit_setting.html.haml' do
                  element 'repository-size-limit-field'
                end

                view 'ee/app/views/groups/_templates_setting.html.haml' do
                  element 'file-template-repositories-container'
                  element 'save-changes-button'
                end

                view 'ee/app/views/groups/_seat_control_setting.html.haml' do
                  element 'seat-control-user-cap-radio'
                  element 'user-cap-limit-field'
                end
              end
            end

            def current_custom_project_template
              expand_content('custom-project-templates-container')

              within_element('custom-project-templates-container') do
                current_selection
              end
            end

            def choose_custom_project_template(path)
              expand_content('custom-project-templates-container')

              within_element('custom-project-templates-container') do
                clear_current_selection_if_present
                expand_select_list
                search_and_select(path)
                click_element('save-changes-button')
              end
            end

            def set_ip_address_restriction(ip_address)
              QA::Runtime::Logger.debug(%(Setting ip address restriction to: #{ip_address}))
              expand_content('permissions-settings')

              # GitLab UI Token Selector (https://gitlab-org.gitlab.io/gitlab-ui/?path=/story/base-token-selector--default)
              # `data-qa-*` can only be added to the wrapper so custom selector used to find token close buttons and text input
              find_element('ip-restriction-field').all('[data-testid="close-icon"]', minimum: 0).each(&:click)

              ip_restriction_field_input = find_element('ip-restriction-field').find('input[type="text"]')
              ip_restriction_field_input.set ip_address
              ip_restriction_field_input.send_keys(:enter)
              click_element('save-permissions-changes-button')
            end

            def set_membership_lock_enabled
              expand_content('permissions-settings')
              check_element('membership-lock-checkbox', true)
              click_element('save-permissions-changes-button')
            end

            def set_membership_lock_disabled
              expand_content('permissions-settings')
              uncheck_element('membership-lock-checkbox', true)
              click_element('save-permissions-changes-button')
            end

            def set_prevent_forking_outside_group_enabled
              expand_content('permissions-settings')
              check_element('prevent-forking-outside-group-checkbox', true)
              click_element('save-permissions-changes-button')
              wait_for_requests
            end

            def set_prevent_forking_outside_group_disabled
              expand_content('permissions-settings')
              uncheck_element('prevent-forking-outside-group-checkbox', true)
              click_element('save-permissions-changes-button')
              wait_for_requests
            end

            def has_secrets_manager_section?
              expand_content('permissions-settings')
              super
            end

            def has_secrets_manager_enabled?
              expand_content('permissions-settings')
              super
            end

            def enable_secrets_manager
              expand_content('permissions-settings')
              super
            end

            def disable_secrets_manager
              expand_content('permissions-settings')
              super
            end

            def add_user_permission(username:, scopes:)
              expand_content('permissions-settings')
              super
            end

            def has_user_permission?(username:, scopes:)
              expand_content('permissions-settings')
              super
            end

            def delete_user_permission(username:)
              expand_content('permissions-settings')
              super
            end

            def add_role_permission(role_name:, scopes:)
              expand_content('permissions-settings')
              super
            end

            def has_role_permission?(role_name:, scopes:)
              expand_content('permissions-settings')
              super
            end

            def add_group_permission(group_path:, scopes:)
              expand_content('permissions-settings')
              super
            end

            def has_group_permission?(group_name:, scopes:)
              expand_content('permissions-settings')
              super
            end

            def delete_role_permission(role_name:)
              expand_content('permissions-settings')
              super
            end

            def delete_group_permission(group_name:)
              expand_content('permissions-settings')
              super
            end

            def alert_text
              expand_content('permissions-settings')
              super
            end

            def has_user_in_dropdown?(username:)
              expand_content('permissions-settings')
              super
            end

            def has_add_permission_button?
              expand_content('permissions-settings')
              super
            end

            def set_repository_size_limit(limit)
              find_element('repository-size-limit-field').set limit
            end

            # Set group's user cap limit if feature flag is enabled
            #
            # @param limit [Integer, String] integer >=1, empty string removes the limit
            def set_saas_user_cap_limit(limit)
              # Need to wait for the input field to appear after the toggle is enabled
              QA::Support::Retrier.retry_until(
                max_attempts: 10, retry_on_exception: true, reload_page: page, sleep_interval: 2
              ) do
                expand_content('permissions-settings')

                if has_element?('seat-control-user-cap-radio', visible: false, wait: 1)
                  choose_element('seat-control-user-cap-radio', true)
                end

                find_element('user-cap-limit-field', wait: 1).set limit
                click_element('save-permissions-changes-button')
                wait_for_requests

                page.text.match?(/was successfully updated/i)
              end
            end

            def current_file_template_repository
              expand_content('file-template-repositories-container')

              within_element('file-template-repositories-container') do
                current_selection
              end
            end

            def choose_file_template_repository(path)
              expand_content('file-template-repositories-container')

              within_element('file-template-repositories-container') do
                clear_current_selection_if_present
                expand_select_list

                search_and_select(path)
                click_element('save-changes-button')
              end
            end
          end
        end
      end
    end
  end
end
