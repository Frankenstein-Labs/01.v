# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Iteration
          class New < QA::Page::Base
            view 'ee/app/assets/javascripts/iterations/components/iteration_form.vue' do
              element 'due-date'
              element 'iteration-description-field'
              element 'iteration-title-field', required: true
              element 'save-iteration'
              element 'start-date'
            end

            def click_create_iteration_button
              click_element('save-iteration', EE::Page::Group::Iteration::Show)
            end

            def fill_description(description)
              fill_editor_element('iteration-description-field', description)
            end

            def fill_due_date(due_date)
              find_element('due-date').find('input').set(due_date)
            end

            def fill_start_date(start_date)
              find_element('start-date').find('input').set(start_date)
            end

            def fill_title(title)
              fill_element('iteration-title-field', title)
            end
          end
        end
      end
    end
  end
end
