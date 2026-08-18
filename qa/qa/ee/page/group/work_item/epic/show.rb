# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module WorkItem
          module Epic
            class Show < QA::Page::Base
              include QA::Page::Component::WorkItem::Note

              view 'app/assets/javascripts/work_items/components/shared/work_item_link_child_contents.vue' do
                element 'links-child'
                element 'remove-work-item-link'
              end

              view 'app/assets/javascripts/work_items/components/shared/work_item_token_input.vue' do
                element 'work-item-token-select-input'
              end

              view 'app/assets/javascripts/work_items/components/work_item_actions.vue' do
                element 'work-item-actions-dropdown'
              end

              view 'app/assets/javascripts/work_items/components/work_item_links/work_item_links_form.vue' do
                element 'add-child-form-button'
              end

              view 'app/assets/javascripts/work_items/components/work_item_links/work_item_actions_split_button.vue' do
                element 'add-tree-child-button'
              end

              view 'app/assets/javascripts/work_items/components/work_item_links/work_item_tree.vue' do
                element 'work-item-tree'
              end

              def add_child_issue_to_epic(issue)
                within_element('work-item-tree') do
                  click_element('add-tree-child-button')
                  click_element('disclosure-dropdown-item', text: 'Existing Issue')
                  fill_element('work-item-token-select-input', issue.web_url)
                  wait_for_requests
                  # Capybara code is used below due to the dropdown being defined in the @gitlab/ui project
                  find('.gl-dropdown-item', text: issue.title).click
                end

                # Clicking the title blurs the input
                click_element('work-item-title')

                within_element('work-item-tree') do
                  click_element('add-child-form-button')
                end
              end

              def remove_child_issue_from_epic(issue)
                within_element('links-child', text: issue.title) do
                  click_element('remove-work-item-link')
                end
              end

              def close_epic
                toggle_actions_dropdown
                click_element("state-toggle-action", text: 'Close epic')
                toggle_actions_dropdown
              end

              def reopen_epic
                toggle_actions_dropdown
                click_element("state-toggle-action", text: 'Reopen epic')
                toggle_actions_dropdown
              end

              def has_child_issue_item?
                has_element?('links-child')
              end

              def has_no_child_issue_item?
                has_no_element?('links-child')
              end

              def toggle_actions_dropdown
                click_element('work-item-actions-dropdown')
              end
            end
          end
        end
      end
    end
  end
end
