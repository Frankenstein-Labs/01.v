# frozen_string_literal: true

module QA
  module EE
    module Page
      module Component
        module IssueBoard
          module Show
            extend QA::Page::PageConcern

            def self.prepended(base)
              super
              base.class_eval do
                view 'ee/app/assets/javascripts/boards/components/board_scope.vue' do
                  element 'board-scope-modal'
                end

                view 'ee/app/assets/javascripts/boards/components/labels_select.vue' do
                  element 'labels-edit-button'
                end

                view 'app/assets/javascripts/vue_shared/components/dropdown/dropdown_widget/dropdown_widget.vue' do
                  element 'labels-dropdown-content'
                end

                view 'app/assets/javascripts/sidebar/components/labels/labels_select_widget/dropdown_header.vue' do
                  element 'close-labels-dropdown-button'
                end
              end
            end

            def board_scope_modal
              find_element('board-scope-modal')
            end

            def configure_by_label(label)
              click_boards_config_button

              QA::Support::Retrier.retry_on_exception do
                click_element('labels-edit-button')
                find_element('labels-dropdown-content', wait: 1).find('li', text: label).click
              end

              click_element('close-labels-dropdown-button') if has_element?('close-labels-dropdown-button', wait: 0.5)
              click_element('save-changes-button')
              wait_boards_list_finish_loading
            end
          end
        end
      end
    end
  end
end
