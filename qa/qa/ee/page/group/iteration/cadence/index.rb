# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Iteration
          module Cadence
            class Index < QA::Page::Base
              view 'ee/app/assets/javascripts/iterations/components/iteration_cadences_list.vue' do
                element 'cadence-list-item-content'
                element 'create-new-cadence-button', required: true
              end

              view 'ee/app/assets/javascripts/iterations/components/iteration_cadence_list_item.vue' do
                element 'add-cadence'
                element 'cadence-options-button'
                element 'iteration-item'
              end

              def click_new_iteration_cadence_button
                click_element('create-new-cadence-button', EE::Page::Group::Iteration::Cadence::New)
              end

              def click_add_iteration_button_on_cadence(cadence_title)
                cadence = find_element('cadence-list-item-content', text: cadence_title)

                within cadence do
                  click_element('cadence-options-button')
                  click_element('add-cadence')
                end
              end

              def open_iteration(cadence_title, iteration_period)
                cadence = toggle_iteration_cadence_dropdown(cadence_title)
                within cadence do
                  click_iteration(iteration_period)
                end
              end

              private

              def click_iteration(iteration_period)
                click_element('iteration-item', title: iteration_period)
              end

              def toggle_iteration_cadence_dropdown(cadence_title)
                find_element('cadence-list-item-content', text: cadence_title).click
              end
            end
          end
        end
      end
    end
  end
end
