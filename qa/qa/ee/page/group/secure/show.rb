# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Secure
          class Show < QA::Page::Base
            include Page::Component::SecureReport

            view 'ee/app/assets/javascripts/security_dashboard/components/shared/project_security_status_chart.vue' do
              element 'project-name-text', required: true
            end

            def filter_project(project_name:)
              click_element('filtered-search-term')
              click_button('Project')
              click_button(project_name)
              click_element('filtered-search-term')
              click_element('search-button')
            end

            def has_security_status_project_for_severity?(severity, project)
              within_element("severity-accordion-item-#{severity}") do
                click_on severity
              end
              has_element?('project-name-text', text: "#{project.group.sandbox.path} / #{project.group.path} / #{project.name}", wait: 5)
            end
          end
        end
      end
    end
  end
end
