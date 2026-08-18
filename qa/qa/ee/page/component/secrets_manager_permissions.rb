# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module SecretsManagerPermissions
          extend QA::Page::PageConcern

          def add_user_permission(username:, scopes:)
            add_permission(name: username, scopes: scopes, type: 'USER')
          end

          def has_user_permission?(username:, scopes:)
            has_permission?(name: username, scopes: scopes)
          end

          def delete_user_permission(username:)
            delete_permission(name: username, tab: 'Users')
          end

          def add_role_permission(role_name:, scopes:)
            add_permission(name: role_name.upcase, scopes: scopes, type: 'ROLE')
          end

          def has_role_permission?(role_name:, scopes:)
            has_permission?(name: role_name, scopes: scopes, tab: 'Roles')
          end

          def delete_role_permission(role_name:)
            delete_permission(name: role_name, tab: 'Roles')
          end

          def add_group_permission(group_path:, scopes:)
            add_permission(name: group_path, scopes: scopes, type: 'GROUP')
          end

          def has_group_permission?(group_name:, scopes:)
            has_permission?(name: group_name, scopes: scopes, tab: 'Group')
          end

          def delete_group_permission(group_name:)
            delete_permission(name: group_name, tab: 'Group')
          end

          def has_user_in_dropdown?(username:)
            within_element('crud-actions') do
              click_button('Add')
            end
            execute_script("document.querySelector('[data-testid=\"listbox-item-USER\"]').click()")
            wait_for_requests
            execute_script("document.querySelector('#secret-permission-principal button').click()")
            escaped_username = username.to_s.gsub('\\', '\\\\').gsub("'", "\\'")
            result = has_css?("[data-testid='listbox-item-#{escaped_username}']", wait: 2)
            execute_script("document.querySelector('[aria-label=\"Close\"]').click()")
            result
          end

          def has_add_permission_button?
            has_button?('Add')
          end

          def alert_text
            find('.js-secrets-manager-permissions-alert-container', wait: 5).text
          end

          private

          def select_principal(name:, type:)
            if type == 'GROUP'
              execute_script("
                const input = document.querySelector('#secret-permission-group-path');
                if (input) {
                  input.value = '#{name}';
                  input.dispatchEvent(new Event('input', { bubbles: true }));
                  input.dispatchEvent(new Event('change', { bubbles: true }));
                }
              ")
            else
              execute_script("document.querySelector('#secret-permission-principal button').click()")
              wait_for_requests
              escaped_name = name.to_s.gsub('\\', '\\\\').gsub("'", "\\'")
              execute_script("document.querySelector(\"[data-testid='listbox-item-#{escaped_name}']\").click()")
            end

            wait_for_requests
          end

          def set_permission_scopes(scopes)
            # Temporarily enable Read so Write/Delete become interactive, then restore intended state.
            check_permission('read') unless scopes.include?('read')
            scopes.each { |scope| check_permission(scope) }
            uncheck_permission('read') unless scopes.include?('read')
          end

          def check_permission(scope_name)
            execute_script(<<~JS, scope_name.capitalize)
              const labels = document.querySelectorAll('label[class*="custom-control-label"]');
              const label = Array.from(labels).find(l => l.textContent.trim().startsWith(arguments[0]));
              const checkbox = label && document.getElementById(label.getAttribute('for'));
              if (checkbox && !checkbox.checked) label.click();
            JS
          end

          def uncheck_permission(scope_name)
            execute_script(<<~JS, scope_name.capitalize)
              const labels = document.querySelectorAll('label[class*="custom-control-label"]');
              const label = Array.from(labels).find(l => l.textContent.trim().startsWith(arguments[0]));
              const checkbox = label && document.getElementById(label.getAttribute('for'));
              if (checkbox && checkbox.checked) label.click();
            JS
          end

          def click_save_button
            execute_script("document.querySelector('.js-modal-action-primary').click()")
          end

          def add_permission(name:, scopes:, type:)
            within_element('crud-actions') { click_button('Add') }
            click_element("listbox-item-#{type}")
            select_principal(name: name, type: type)
            set_permission_scopes(scopes)
            click_save_button
            wait_for_requests
          end

          def has_permission?(name:, scopes:, tab: nil)
            find('[role="tab"]', text: tab).click if tab.present?
            begin
              row = find('tr', text: name)
            rescue StandardError
              return false
            end

            scopes.each do |scope|
              return false unless row.has_text?(scope.capitalize)
            end

            true
          end

          def delete_permission(name:, tab: nil)
            find('[role="tab"]', text: tab).click if tab.present?
            row = find('tr', text: name)
            within(row) do
              delete_button = find('[data-testid="remove-icon"]', wait: 2).ancestor('button')
              delete_button.click
              execute_script("document.querySelector('.js-modal-action-primary').click()")
            end
            wait_for_requests
          end
        end
      end
    end
  end
end
