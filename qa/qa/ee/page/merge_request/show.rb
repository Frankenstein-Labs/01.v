# frozen_string_literal: true

module QA
  module EE
    module Page
      module MergeRequest
        module Show
          extend QA::Page::PageConcern

          ApprovalConditionsError = Class.new(RuntimeError)

          def self.prepended(base)
            super

            base.class_eval do
              prepend Page::Component::LicenseManagement
              prepend Page::Component::DapEmptyState

              view 'ee/app/views/projects/merge_requests/_code_owner_approval_rules.html.haml' do
                element 'approver-content'
                element 'approver-list-content'
              end

              view 'ee/app/assets/javascripts/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue' do
                element 'vulnerability-report-grouped'
                element 'sast-scan-report'
                element 'dependency-scan-report'
                element 'container-scan-report'
                element 'dast-scan-report'
                element 'coverage-fuzzing-report'
                element 'api-fuzzing-report'
                element 'secret-detection-report'
              end

              view 'app/assets/javascripts/vue_merge_request_widget/components/widget/widget.vue' do
                element 'toggle-button'
              end

              view 'app/assets/javascripts/vue_merge_request_widget/components/approvals/approvals.vue' do
                element 'approve-button'
              end

              view 'app/assets/javascripts/vue_merge_request_widget/components/approvals/approvals_summary.vue' do
                element 'approvals-summary-content'
              end

              view 'ee/app/assets/javascripts/security_dashboard/components/pipeline/vulnerability_finding_modal.vue' do
                element 'vulnerability-modal-content'
                element 'dismiss-button'
                element 'save-editing-dismissal'
                element 'dismissal-comment'
                element 'cancel-button'
              end

              view 'ee/app/assets/javascripts/vue_shared/security_reports/components/split_button.vue' do
                element 'create-issue-button', "`${selectedButton.action}-button`" # rubocop:disable QA/ElementWithPattern -- create-issue is coming from selectedButton.action
              end

              view 'ee/app/assets/javascripts/security_dashboard/components/pipeline/vulnerability_dismissal_reason.vue' do
                element 'dismissal-reason'
              end

              view 'ee/app/assets/javascripts/vue_shared/security_reports/components/event_item.vue' do
                element 'event-item-content'
              end

              view 'ee/app/assets/javascripts/vue_merge_request_widget/components/ai_commit_message.vue' do
                element 'generate-commit-message'
                element 'insert-commit-message'
                element 'ai-commit-message-row'
              end
            end
          end

          def wait_for_license_compliance_report
            retry_until(reload: true, sleep_interval: 2, max_attempts: 30,
              message: 'Finding "License Compliance" widget') do
              has_text?('License compliance detected')
            end
          end

          def approvals_required_from
            match = approvals_content.match(/approvals? from (.*)/)
            raise(ApprovalConditionsError, 'The expected approval conditions were not found.') unless match

            match[1]
          end

          def approved?
            approvals_content.include?('Approved by') && !approvals_content.match(/Requires \d+ approvals? from/)
          end

          def approvers
            wait_until(reload: true, sleep_interval: 2, max_duration: 60,
              message: 'Waiting for code owner approver list to render') do
              has_element?('approver-list-content', wait: 5) && has_element?('approver-content', wait: 1)
            end

            within_element 'approver-list-content' do
              all_elements('approver-content', minimum: 1).map { |item| item.find('img')['title'] }
            end
          end

          def click_approve(verify: true)
            click_element 'approve-button'
            return unless verify

            retry_until(reload: true, sleep_interval: 2, max_attempts: 5,
              message: 'Finding Revoke approval button unsuccessful') do
              verify_approved
            end
          end

          def expand_license_report
            within_element('widget-extension') do
              click_element('toggle-button')
            end
          end

          def expand_vulnerability_report
            within_element('vulnerability-report-grouped') do
              click_element('toggle-button') if has_element?('toggle-button')
            end
          end

          def click_vulnerability(name)
            # To fix the flakiness, click on the MR title after widget is expanded
            click_element('title-content')
            within_element 'vulnerability-report-grouped' do
              click_on name
            end

            wait_until(reload: false) do
              find_element('vulnerability-modal-content')
            end
          end

          def click_resolve_with_ai
            click_element('resolve-with-ai')
            wait_for_requests
          end

          def click_finding_resolution_mr_link
            click_element('merge-request-link')
            wait_for_requests
          end

          def dismiss_vulnerability_with_comment(name, comment)
            expand_vulnerability_report
            click_vulnerability(name)
            add_comment_and_dismiss(comment)
          end

          def add_comment_and_dismiss(comment)
            click_element('dismiss-button')
            find(dismissal_reason_selector, wait: 5).click
            find(dismissal_reason_item_selector("not_applicable")).click
            find_element('dismissal-comment').fill_in with: comment, fill_options: { automatic_label_click: true }
            click_element('save-editing-dismissal')

            wait_until(reload: false) do
              has_no_element?('vulnerability-modal-content')
            end
          end

          def dismissal_reason_selector
            "[data-testid='dismissal-reason'] > button"
          end

          def dismissal_reason_item_selector(reason)
            "[data-testid='listbox-item-#{reason}']"
          end

          def create_vulnerability_issue(name)
            expand_vulnerability_report
            click_vulnerability(name)

            previous_page = page.current_url
            click_element('create-issue-button')

            wait_until(max_duration: 15, reload: false) do
              page.current_url != previous_page
            end
          end

          def cancel_vulnerability_modal
            click_element('cancel-button')
          end

          def has_vulnerability_report?(timeout: 60)
            # The widget renders immediately in a loading state, so both the presence and the
            # not-loading check must happen inside the wait loop for the timeout to be meaningful.
            wait_until(reload: true, max_duration: timeout, sleep_interval: 2, raise_on_failure: false) do
              has_element?('vulnerability-report-grouped', wait: 10) &&
                find_element('vulnerability-report-grouped').has_no_content?("is loading")
            end
          end

          def has_vulnerability_count?(expected_count = nil)
            # Match text cut off in order to find both "1 vulnerability" and "X vulnerabilities"
            click_element('title-content')

            unless expected_count
              return find_element('vulnerability-report-grouped').has_content?(/Security scanning detected/)
            end

            find_element('vulnerability-report-grouped').has_content?(/Security scanning detected #{expected_count}( new)?( potential)? vulnerabilit/)
          end

          def has_sast_vulnerability_count_of?(expected)
            find_element('sast-scan-report').has_content?(/SAST detected #{expected}( new)?( potential)? vulnerabilit/)
          end

          def has_secret_detection_vulnerability_count_of?(expected)
            find_element('secret-detection-report').has_content?(/Secret detection detected #{expected}( new)?( potential)? vulnerabilit/)
          end

          def has_dependency_vulnerability_count_of?(expected)
            find_element('dependency-scan-report').has_content?(/Dependency scanning detected #{expected}( new)?( potential)? vulnerabilit|Dependency scanning detected .* vulnerabilities out of #{expected}/)
          end

          def has_container_vulnerability_count_of?(expected)
            find_element('container-scan-report').has_content?(/Container scanning detected #{expected}( new)?( potential)? vulnerabilit|Container scanning detected .* vulnerabilities out of #{expected}/)
          end

          def has_dast_vulnerability_count?
            find_element('dast-scan-report').has_content?(/DAST detected \d*( new)?( potential)? vulnerabilit/)
          end

          def has_security_finding_dismissed_on_mr_widget?(comment)
            within_element('vulnerability-modal-content') do
              has_element?('event-item-content', text: /Dismissed.*/) &&
                has_element?('event-item-content', text: comment)
            end
          end

          def has_security_finding_dismissed?(reason, project_path)
            within_element('vulnerability-modal-content') do
              has_element?('event-item-content', text: /Dismissed.* at #{project_path.gsub('/', ' / ')}/) &&
                has_element?('event-item-content', text: reason)
            end
          end

          def num_approvals_required
            approvals_content.match(/Requires (\d+) approvals/)[1].to_i
          end

          def merge_via_merge_train
            try_to_merge!(wait_for_no_auto_merge: false)

            spinner_cleared?
          end

          def verify_approved
            find_element('approve-button', text: "Revoke approval")
          end

          def generate_commit
            click_element('generate-commit-message')
          end

          def insert_commit
            click_element('insert-commit-message')
          end

          def ai_commit_message
            find_element('ai-commit-message-row').text
          end

          private

          def approvals_content
            # The approvals widget displays "Checking approval status" briefly
            # while loading the widget, so before returning the text we wait
            # for it to include terms from content we expect. The kinds
            # of content we expect are:
            #
            # * Requires X approvals from Quality, UX, and frontend.
            # * Approved by you and others
            #
            # It can also briefly display cached data while loading so we
            # wait for it to update first
            sleep 1

            text = nil
            wait_until(reload: false, sleep_interval: 1) do
              text = find_element('approvals-summary-content').text
              text =~ /requires|approved/i
            end

            text
          end
        end
      end
    end
  end
end
