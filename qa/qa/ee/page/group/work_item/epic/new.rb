# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module WorkItem
          module Epic
            class New < QA::Page::Base
              view 'app/assets/javascripts/work_items/components/create_work_item.vue' do
                element 'confidential-checkbox'
                element 'create-button'
              end

              view 'app/assets/javascripts/work_items/components/work_item_title.vue' do
                element 'work-item-title-input', required: true
              end

              def create_new_epic
                click_element('create-button')
              end

              def enable_confidential_epic
                check_element('confidential-checkbox', true)
              end

              def set_title(title)
                fill_element('work-item-title-input', title)
              end

              def select_epic_type
                return unless has_element?('work-item-types-select')

                select 'Epic', from: 'Type'
              end
            end
          end
        end
      end
    end
  end
end
