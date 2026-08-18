# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        module Settings
          class Templates < QA::Page::Base
            include ::QA::Page::Settings::Common
            include ::QA::Page::Component::Dropdown

            view 'ee/app/views/admin/application_settings/_custom_templates_form.html.haml' do
              element 'custom-project-template-container'
              element 'save-changes-button'
            end

            def current_custom_project_template
              expand_content('custom-project-template-container')

              within_element('custom-project-template-container') do
                wait_for_requests
                current_selection
              end
            end

            def choose_custom_project_template(path)
              expand_content('custom-project-template-container')

              within_element('custom-project-template-container') do
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
