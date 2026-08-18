# frozen_string_literal: true

module QA
  module EE
    module Flow
      module Trial
        extend self

        CUSTOMER_TRIAL_INFO = {
          company_name: 'QA Test Company',
          phone_number: '555-555-5555',
          country: 'United States of America',
          state: 'California'
        }.freeze

        def register_for_trial(group: nil)
          EE::Page::Trials::New.perform do |new|
            new.trial_for = group.path if group.present?
            new.fill_in_customer_trial_info(CUSTOMER_TRIAL_INFO)

            new.click_submit_trial_button
          end
        end
      end
    end
  end
end
