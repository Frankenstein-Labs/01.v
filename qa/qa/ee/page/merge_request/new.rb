# frozen_string_literal: true

module QA
  module EE
    module Page
      module MergeRequest
        module New
          extend QA::Page::PageConcern

          def self.prepended(base)
            super

            base.class_eval do
              include ::QA::Page::Component::Dropdown

              view 'ee/app/assets/javascripts/approvals/components/approval_rules_app.vue' do
                element 'add-approval-rule'
              end

              view 'ee/app/assets/javascripts/approvals/components/rules/rule_form.vue' do
                element 'approvals-required'
                element 'approvers-group'
                element 'rule-name-field'
                element 'users-selector'
                element 'groups-selector'
              end

              view 'ee/app/assets/javascripts/approvals/components/rule_drawer/create_rule.vue' do
                element 'save-approval-rule-button'
              end

              def add_approval_rules(rules)
                # The Approval rules button/link is a gitlab-ui component that doesn't have a QA selector
                click_button('Approval rules')

                rules.each do |rule|
                  click_element('add-approval-rule')

                  wait_for_animated_element('rule-name-field')

                  fill_element('rule-name-field', rule[:name])
                  fill_element('approvals-required', rule[:approvals_required])

                  within_element('approvers-group') do
                    rule.key?(:users) && rule[:users].each do |user|
                      select_user(user.username)
                    end
                    rule.key?(:groups) && rule[:groups].each do |group|
                      select_group(group.name)
                    end
                  end

                  click_approvers_modal_ok_button
                end
              end

              # The Add/Update approvers modal is a gitlab-ui component built on
              # a bootstrap-vue component. It doesn't seem straightforward to
              # add a data attribute to the 'Ok' button without overriding it
              # So we break the rules and use a CSS selector instead of an element
              def click_approvers_modal_ok_button
                # Conditional to handle approval rule draw https://gitlab.com/gitlab-org/gitlab/-/issues/444628
                if has_element?('save-approval-rule-button')
                  click_element('save-approval-rule-button')
                else
                  find("#mr-edit-approvals-create-modal footer button.btn-confirm").click
                end
              end

              private

              def select_user(username)
                retry_until do
                  within_element('users-selector') do
                    search_and_select(username)
                  end
                end
              end

              def select_group(group_name)
                retry_until do
                  within_element('groups-selector') do
                    search_and_select(group_name)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
