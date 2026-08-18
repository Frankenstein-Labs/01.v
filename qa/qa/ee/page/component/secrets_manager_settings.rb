# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module SecretsManagerSettings
          extend QA::Page::PageConcern

          def self.included(base)
            super
            register_views(base)
          end

          def self.register_views(base)
            base.class_eval do
              view 'ee/app/assets/javascripts/pages/projects/shared/permissions/' \
                'secrets_manager/secrets_manager_settings.vue' do
                element 'secret-manager'
                element 'secret-manager-toggle'
              end
            end
          end

          def has_secrets_manager_section?
            has_element?('secret-manager')
          end

          def has_secrets_manager_enabled?
            return false unless has_element?('secret-manager-toggle')

            within_element('secret-manager-toggle') do
              find('[role="switch"]', wait: 5)['aria-checked'] == 'true'
            end
          rescue Capybara::ElementNotFound
            false
          end

          def enable_secrets_manager
            toggle_secrets_manager unless has_secrets_manager_enabled?
          end

          def disable_secrets_manager
            toggle_secrets_manager if has_secrets_manager_enabled?
          end

          def has_secrets_manager_permissions_section?
            has_text?('Secrets manager user permissions')
          end

          def has_owner_permissions_in_roles_tab?
            find('[role="tab"]', text: 'Roles').click
            within('tbody') do
              owner_row = find('tr', text: 'Owner')
              owner_row.has_text?('Read, Write, Delete')
            end
          end

          private

          def toggle_secrets_manager
            raise 'Secrets manager toggle not found' unless has_element?('secret-manager-toggle')

            within_element('secret-manager-toggle') do
              toggle = find('[role="switch"]', wait: 5)
              toggle.click unless toggle[:disabled] == 'true' || toggle[:class]&.include?('gl-toggle-disabled')
            end
          end
        end
      end
    end
  end
end
