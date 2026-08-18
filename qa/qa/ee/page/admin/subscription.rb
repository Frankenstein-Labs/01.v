# frozen_string_literal: true

module QA
  module EE
    module Page
      module Admin
        class Subscription < QA::Page::Base
          view 'ee/app/assets/javascripts/admin/subscriptions/show/components/subscription_breakdown.vue' do
            element 'subscription-details-card'
            element 'remove-license-button'
            element 'confirm-remove-license-button'
          end

          view 'ee/app/assets/javascripts/admin/subscriptions/show/components/subscription_activation_form.vue' do
            element 'activation-code-field'
            element 'activate-button'
            element 'subscription-terms-checkbox'
          end

          view 'ee/app/assets/javascripts/admin/subscriptions/show/components/subscription_details_table.vue' do
            # rubocop:disable QA/ElementWithPattern -- required for qa:selectors job to pass
            element 'plan', 'itemDetailTestId'
            element 'name', 'itemDetailTestId'
            element 'company', 'itemDetailTestId'
            # rubocop:enable QA/ElementWithPattern
          end

          view 'ee/app/assets/javascripts/admin/subscriptions/show/components/subscription_details_user_info.vue' do
            element 'users-in-subscription-content'
          end

          view 'ee/app/assets/javascripts/admin/subscriptions/show/components/subscription_details_history.vue' do
            element 'subscription-history-row'

            # rubocop:disable QA/ElementWithPattern -- required for qa:selectors job to pass
            element 'subscription-cell-plan', 'tdAttr'
            element 'subscription-cell-users-in-license-count', 'tdAttr'
            element 'subscription-cell-type', 'tdAttr'
            # rubocop:enable QA/ElementWithPattern
          end

          def self.path
            '/admin/subscription'
          end

          def activate_license(activation_code)
            fill_element('activation-code-field', activation_code)
            check_element('subscription-terms-checkbox', true)
            click_element('activate-button')
          end

          def license?
            has_element?('remove-license-button')
          end

          def remove_license_file
            click_element('remove-license-button')
            click_element('confirm-remove-license-button')
          end

          def subscription_details?
            has_element?('subscription-details-card')
          end

          def name
            find_element('name').text
          end

          def plan
            find_element('plan').text
          end

          def company
            find_element('company').text
          end

          def users_in_subscription
            find_element('users-in-subscription-content').text
          end

          def has_no_valid_license_alert?
            page.has_content?(/no longer has a valid license/)
          end

          def has_activation_card?
            has_element?('activation-code-field')
          end

          def has_ultimate_subscription_plan?
            has_element?('plan', text: 'Ultimate')
          end

          # Checks if a subscription record exists in subscription history table
          #
          # @param plan [Hash] Name of the plan
          # @option plan [Hash] Support::Helpers::FREE
          # @option plan [Hash] Support::Helpers::PREMIUM_SELF_MANAGED
          # @option plan [Hash] Support::Helpers::ULTIMATE_SELF_MANAGED
          # @param users_in_license [Integer] Number of users in license
          # @param license_type [Hash] Type of the license
          # @option license_type [String] 'legacy license'
          # @option license_type [String] 'online license'
          # @option license_type [String] 'offline license'
          # @return [Boolean] True if record exists, false if not
          def has_subscription_record?(plan, users_in_license, license_type)
            all_elements('subscription-history-row', minimum: 1).any? do |record|
              record.find('[data-testid="subscription-cell-plan"]').text == plan[:name].capitalize &&
                record.find('[data-testid="subscription-cell-users-in-license-count"]').text == users_in_license.to_s &&
                record.find('[data-testid="subscription-cell-type"]').text.strip.downcase == license_type
            end
          end
        end
      end
    end
  end
end
