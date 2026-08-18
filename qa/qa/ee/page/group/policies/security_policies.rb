# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Policies
          class SecurityPolicies < QA::Page::Base
            view 'ee/app/assets/javascripts/security_orchestration/components/policies/list_header.vue' do
              element 'new-policy-button'
            end

            view 'ee/app/assets/javascripts/security_orchestration/components/policy_editor/pipeline_execution/action' \
              '/code_block_file_path.vue' do
              element 'pipeline-execution-project-dropdown'
              element 'ci-file-path-text'
            end

            view 'ee/app/assets/javascripts/security_orchestration/components/policy_editor/editor_layout.vue' do
              element 'policy-name-text'
              element 'policy-description-text'
              element 'save-policy'
            end

            def click_new_policy
              click_element('new-policy-button')
              wait_for_requests
            end

            def click_pipeline_execution_policy
              click_element('select-policy-pipeline_execution_policy')
              wait_for_requests
              # Wait for the policy form to be fully rendered before interacting with it
              wait_until(max_duration: 10, reload: false, message: 'Waiting for policy form to load') do
                has_element?('policy-name-text', wait: 1)
              end
            end

            def set_policy_name(policy_name)
              fill_element('policy-name-text', policy_name)
            end

            def select_strategy(override = false)
              click_element('strategy-selector-dropdown')
              wait_for_requests

              if override
                click_element('listbox-item-override_project_ci')
              else
                click_element('listbox-item-inject_ci')
              end
            end

            def set_ci_file_path(file_path)
              within_element('ci-file-path-text') do
                find('[id="file-path"]').set(file_path)
              end
            end

            def set_policy_description(description)
              fill_element('policy-description-text', description)
            end

            def select_project(project_id)
              click_element('pipeline-execution-project-dropdown')
              # Wait for the GraphQL query to fetch projects to complete
              wait_for_requests
              # Wait for the specific project item to appear in the dropdown
              wait_until(max_duration: 15, reload: false, message: 'Waiting for project dropdown to populate') do
                has_element?(project_listbox_item(project_id), wait: 1)
              end
              find_element(project_listbox_item(project_id)).click
            end

            def save_policy
              click_element('save-policy')
              wait_for_requests
            end

            def project_listbox_item(project_id)
              "listbox-item-gid://gitlab/Project/#{project_id}"
            end
          end
        end
      end
    end
  end
end
