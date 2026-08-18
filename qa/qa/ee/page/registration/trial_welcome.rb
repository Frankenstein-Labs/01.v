# frozen_string_literal: true

module QA
  module EE
    module Page
      module Registration
        class TrialWelcome < QA::Page::Base
          view 'ee/app/assets/javascripts/registrations/components/trial_welcome_form.vue' do
            element 'continue-button'
          end

          def has_continue_button?(wait: Capybara.default_max_wait_time)
            has_element?('continue-button', wait: wait)
          end
        end
      end
    end
  end
end
