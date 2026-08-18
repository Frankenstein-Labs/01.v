# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          module Services
            module Jira
              extend QA::Page::PageConcern
              def self.prepended(base)
                super

                base.class_eval do
                  view 'ee/app/assets/javascripts/integrations/edit/components/' \
                    'jira_issue_creation_vulnerabilities.vue' do
                    element 'jira-enable-vulnerabilities-checkbox'
                    element 'jira-project-key-field'
                    element 'jira-issue-types-fetch-retry-button'
                    element 'jira-select-issue-type-dropdown'
                    element 'jira-type'
                  end
                end
              end

              def enable_jira_vulnerabilities
                check_element('jira-enable-vulnerabilities-checkbox', true)
              end

              def set_jira_project_key(key)
                fill_element('jira-project-key-field', key)
              end

              def select_vulnerability_bug_type(bug_type)
                click_retry_vulnerabilities
                select_jira_bug_type(bug_type)
              end

              private

              def click_retry_vulnerabilities
                click_element('jira-issue-types-fetch-retry-button')
              end

              def select_jira_bug_type(option)
                click_element('jira-select-issue-type-dropdown')
                click_element('jira-type', service_type: option)
              end
            end
          end
        end
      end
    end
  end
end
