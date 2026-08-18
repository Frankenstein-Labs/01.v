# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          class PushRules < QA::Page::Base
            view 'ee/app/views/shared/push_rules/_form.html.haml' do
              element 'deny-delete-tag-checkbox'
              element 'restrict-author-checkbox'
              element 'prevent-secrets-checkbox'
              element 'commit-message-field'
              element 'deny-commit-message-field'
              element 'branch-name-field'
              element 'author-email-field'
              element 'file-name-field'
              element 'file-size-field'
              element 'submit-settings-button'
            end

            view 'ee/app/views/shared/push_rules/_reject_unsigned_commits_setting.html.haml' do
              element 'reject-unsigned-commits-checkbox'
            end

            view 'ee/app/views/shared/push_rules/_commit_committer_check_setting.html.haml' do
              element 'committer-restriction-checkbox'
            end

            def check_reject_unsigned_commits
              check_element('reject-unsigned-commits-checkbox', true)
            end

            def check_committer_restriction
              check_element('committer-restriction-checkbox', true)
            end

            def check_deny_delete_tag
              check_element('deny-delete-tag-checkbox', true)
            end

            def check_restrict_author
              check_element('restrict-author-checkbox', true)
            end

            def check_prevent_secrets
              check_element('prevent-secrets-checkbox', true)
            end

            def fill_commit_message_rule(message)
              fill_element 'commit-message-field', message
            end

            def fill_deny_commit_message_rule(message)
              fill_element 'deny-commit-message-field', message
            end

            def fill_branch_name(name)
              fill_element 'branch-name-field', name
            end

            def fill_author_email(email)
              fill_element 'author-email-field', email
            end

            def fill_file_name(file_name)
              fill_element 'file-name-field', file_name
            end

            def fill_file_size(file_size)
              fill_element 'file-size-field', file_size
            end

            def click_submit
              click_element 'submit-settings-button'
            end
          end
        end
      end
    end
  end
end
