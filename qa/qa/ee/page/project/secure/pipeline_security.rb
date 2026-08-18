# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Secure
          class PipelineSecurity < QA::Page::Base
            view 'ee/app/assets/javascripts/security_dashboard/components/shared/vulnerability_report/' \
              'vulnerability_list.vue' do
              element 'vulnerability'
              element 'vulnerability-status-content'
            end

            view 'ee/app/assets/javascripts/security_dashboard/components/shared/vulnerability_report/' \
              'selection_summary.vue' do
              element 'select-action-listbox'
            end

            view 'ee/app/assets/javascripts/security_dashboard/components/shared/vulnerability_report/' \
              'bulk_change_status.vue' do
              element 'status-listbox'
              element 'change-status-button'
              element 'dismissal-reason-listbox'
              element 'change-status-comment-textbox'
            end

            def dismiss_finding_with_reason(finding_name, reason = "not_applicable")
              select_finding(finding_name)
              select_state('dismissed')
              select_dismissal_reason(reason)
              fill_element('change-status-comment-textbox', "E2E Test")
              click_element('change-status-button')
            end

            def has_vulnerability?(vulnerability_name)
              has_element?('vulnerability', vulnerability_description: vulnerability_name)
            end

            def select_vulnerability(vulnerability_name)
              click_element('vulnerability', vulnerability_description: vulnerability_name)
            end

            def has_modal_scanner_type?(scanner_type)
              within_element('vulnerability-modal-content') do
                within_element('scanner-list-item') do
                  has_text?(scanner_type)
                end
              end
            end

            def has_modal_vulnerability_filepath?(filepath)
              within_element('vulnerability-modal-content') do
                within_element('location-file-list-item') do
                  has_text?(filepath)
                end
              end
            end

            def close_modal
              within_element('vulnerability-modal-content') do
                click_element('close-icon')
              end
            end

            def select_finding(finding_name)
              click_element('vulnerability-status-content', status_description: finding_name)
            end

            def select_state(state)
              retry_until(max_attempts: 3, sleep_interval: 2, message: "Setting status and comment") do
                if has_element?('select-action-listbox')
                  click_element('select-action-listbox', wait: 2)
                  click_element('listbox-item-status')
                end

                has_element?('change-status-comment-textbox', wait: 2)

                click_element('status-listbox', wait: 5)
                click_element(:"listbox-item-#{state}", wait: 5)
                has_element?('change-status-comment-textbox', wait: 2)
              end
            end

            def select_dismissal_reason(reason)
              click_element('dismissal-reason-listbox')
              click_element(:"listbox-item-#{reason}")
            end

            def select_status(status)
              click_element('filtered-search-term')
              click_button('Status')
              click_element(:"suggestion-#{status}")
              click_element('filtered-search-term')
              click_element('search-button')
            end

            def create_issue(finding_name)
              click_finding(finding_name)
              click_element('create-issue-button')
            end

            def click_finding(finding_name)
              click_element('vulnerability', vulnerability_description: finding_name)
              wait_for_requests
            end
          end
        end
      end
    end
  end
end
