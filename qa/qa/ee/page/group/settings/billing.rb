# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          class Billing < QA::Page::Base
            view 'ee/app/views/groups/billings/_free_and_trial_plan_billing_index.html.haml' do
              element 'free-trial-plan-billing-content'
            end

            def free_trial_plan_billing_content
              find_element('free-trial-plan-billing-content').text
            end
          end
        end
      end
    end
  end
end
