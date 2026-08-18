# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Iteration
          module Cadence
            class New < QA::Page::Base
              view 'ee/app/assets/javascripts/iterations/components/iteration_cadence_form.vue' do
                element 'automated-scheduling-checkbox'
                element 'iteration-cadence-description-field'
                element 'iteration-cadence-duration-field'
                element 'iteration-cadence-start-date-field'
                element 'iteration-cadence-title-field', required: true
                element 'iteration-cadence-upcoming-iterations-field'
                element 'save-cadence'
              end

              def uncheck_automated_scheduling_checkbox
                uncheck_element('automated-scheduling-checkbox', true)
              end

              def click_create_iteration_cadence_button
                click_element('save-cadence')
              end

              def fill_description(description)
                fill_editor_element('iteration-cadence-description-field', description)
              end

              def fill_duration(duration)
                select_element('iteration-cadence-duration-field', duration)
              end

              def fill_upcoming_iterations(upcoming_iterations)
                select_element('iteration-cadence-upcoming-iterations-field', upcoming_iterations)
              end

              def fill_start_date(start_date)
                fill_element('gl-datepicker-input', start_date)
                send_keys_to_element('gl-datepicker-input', :enter)
              end

              def fill_title(title)
                fill_element('iteration-cadence-title-field', title)
              end
            end
          end
        end
      end
    end
  end
end
