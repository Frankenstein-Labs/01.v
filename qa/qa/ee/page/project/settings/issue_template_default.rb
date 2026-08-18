# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          class IssueTemplateDefault < QA::Page::Base
            view 'ee/app/views/projects/settings/_default_issue_template.html.haml' do
              element 'issue-template-field'
              element 'save-issue-template-button'
            end

            def set_default_issue_template(template)
              fill_element('issue-template-field', template)
              click_element('save-issue-template-button')

              wait_for_requests
            end

            def default_issue_template_text_project_settings
              find_element('issue-template-field').text
            end
          end
        end
      end
    end
  end
end
