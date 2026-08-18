# frozen_string_literal: true

module QA
  module EE
    module Page
      module Trials
        class New < QA::Page::Base
          include QA::Page::Component::Dropdown

          view 'ee/app/assets/javascripts/trials/components/create_trial_form.vue' do
            element 'trial-form'
            element 'first-name-field'
            element 'last-name-field'
            element 'company-name-field'
            element 'country-dropdown'
            element 'state-dropdown'
            element 'phone-number-field'
            element 'submit-button'
          end

          def self.path
            '/-/trials/new'
          end

          # Fill in the customer trial information
          # @param [Hash] customer The customer trial information
          # @option customer [String] :company_name The name of the company
          # @option customer [String] :phone_number The phone number of the company
          # @option customer [String] :country The country of the company
          # @option customer [String] :state The state of the company
          def fill_in_customer_trial_info(customer)
            fill_element('company-name-field', customer[:company_name])

            within_element('country-dropdown-container') do
              expand_select_list
              select_item(customer[:country])
            end

            fill_element('phone-number-field', customer[:phone_number])

            within_element('state-dropdown-container') do
              expand_select_list
              select_item(customer[:state])
            end
          end

          def trial_for=(group)
            within_element('group-dropdown-container') do
              expand_select_list
              select_item(group)
            end
          end

          def click_submit_trial_button
            click_element('submit-button')
          end
        end
      end
    end
  end
end
