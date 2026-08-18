# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module MergeRequest
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                include Page::Component::SecureReport

                view 'ee/app/views/projects/settings/merge_requests/_merge_pipelines_settings.html.haml' do
                  element 'merged-results-pipeline-checkbox'
                end

                view 'ee/app/views/projects/settings/merge_requests/_merge_request_settings.html.haml' do
                  element 'default-merge-request-template-field'
                end

                view 'ee/app/views/projects/settings/merge_requests/_merge_trains_settings.html.haml' do
                  element 'merge-trains-checkbox'
                end
              end
            end

            def click_pipelines_for_merged_results_checkbox
              check_element('merged-results-pipeline-checkbox', true)
            end

            def click_merge_trains_checkbox
              check_element('merge-trains-checkbox', true)
            end

            def enable_merge_trains
              click_pipelines_for_merged_results_checkbox
              click_merge_trains_checkbox
              click_save_changes
            end

            def enable_merged_results
              click_pipelines_for_merged_results_checkbox
              click_save_changes
            end

            def set_default_merge_request_template(template)
              fill_element('default-merge-request-template-field', template)
              click_save_changes

              wait_for_requests
            end
          end
        end
      end
    end
  end
end

QA::Page::Project::Settings::MergeRequest.prepend_mod_with( # rubocop:disable Cop/InjectEnterpriseEditionModule
  "Page::Project::Settings::MergeRequestApprovals",
  namespace: QA)
