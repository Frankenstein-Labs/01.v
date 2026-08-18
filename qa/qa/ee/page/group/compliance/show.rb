# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Compliance
          class Show < QA::Page::Base
            view 'ee/app/assets/javascripts/compliance_dashboard/components/projects_report/projects_table.vue' do
              element 'project-name-link'
              element 'project-path-content'
              element 'project-frameworks-row'
            end

            view 'ee/app/assets/javascripts/compliance_dashboard/components/main_layout.vue' do
              element 'standards-adherence-tab'
              element 'violations-tab'
              element 'frameworks-tab'
              element 'projects-tab'
            end

            view 'ee/app/assets/javascripts/compliance_dashboard/components/shared/framework_badge.vue' do
              element 'compliance-framework-default-label'
              element 'compliance-framework-label'
            end

            view 'ee/app/assets/javascripts/compliance_dashboard/components/violations_report/report.vue' do
              element 'violation-reason-content'
            end

            def switch_to_violations_tab
              click_violations_tab unless has_active_element?('violations-tab', wait: 1)
            end

            def click_violations_tab
              click_element('violations-tab')
              wait_for_requests
            end

            def click_projects_tab
              click_element('projects-tab')
              wait_for_requests
            end

            def bulk_apply_framework_to_all_projects(framework)
              check_element('select-all-projects-checkbox', true)
              click_element('choose-bulk-action')
              click_element('listbox-item-apply')
              find_button('Choose one framework').click
              wait_for_requests
              click_element("listbox-item-#{framework.gid}")
              click_element('apply-bulk-operation-button')
              wait_for_requests
            end

            def bulk_remove_framework_from_all_projects(excluded_projects: [])
              check_element('select-all-projects-checkbox', true)
              click_element('choose-bulk-action')
              click_element('listbox-item-remove')

              excluded_projects.each do |project|
                project_row(project, &:unselect_project_row)
              end

              click_element('apply-bulk-operation-button')
              wait_for_requests
            end

            RSpec::Matchers.define :have_violation do |reason, merge_request_title|
              match do |page|
                page.has_element?('violation-reason-content', text: reason, description: merge_request_title)
              end

              match_when_negated do |page|
                page.has_no_element?('violation-reason-content', text: reason, description: merge_request_title)
              end
            end

            def unselect_project_row
              verify_project_frameworks_row_scope!

              uncheck_element('select-project-checkbox', true)
            end

            def has_name?(name)
              verify_project_frameworks_row_scope!

              has_element?('project-name-link', text: name, wait: 0)
            end

            def has_path?(path)
              verify_project_frameworks_row_scope!

              has_element?('project-path-content', text: path, wait: 0)
            end

            def has_framework?(name, default: false)
              verify_project_frameworks_row_scope!

              framework_label = default ? 'compliance-framework-default-label' : 'compliance-framework-label'
              has_element?(framework_label, text: name, wait: 0)
            end

            def has_no_framework?
              verify_project_frameworks_row_scope!

              has_no_element?('compliance-framework-default-label', wait: 0) &&
                has_no_element?('compliance-framework-label', wait: 0)
            end

            def has_no_projects_tab?
              has_no_element?('projects-tab')
            end

            # Yields with the scope within the `project-frameworks-row` element associated with the specified project.
            def project_row(project)
              within_element('project-frameworks-row', project_name: project.name) do
                yield self
              end
            end

            private

            # Checks if the current scope is within the `project-frameworks-row` element. If not, an error is raised.
            #
            # @return [void]
            def verify_project_frameworks_row_scope!
              return if current_scope.is_a?(Capybara::Node::Element) &&
                current_scope['data-testid'].include?('project-frameworks-row')

              raise Capybara::ScopeError,
                "The calling method should be called within the `project-frameworks-row` element via `project_row`"
            end
          end
        end
      end
    end
  end
end
