# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Secure
          module ConfigurationForm
            extend QA::Page::PageConcern

            def self.prepended(base)
              super

              base.class_eval do
                view 'ee/app/assets/javascripts/security_configuration/' \
                  'components/scan_profiles/scan_profile_launch_modal.vue' do
                  element 'scanner-profile-launch-modal'
                end
              end
            end

            def enable_secret_detection
              # Dismiss scanner profile modal if present - increased wait time for modal to appear
              if has_element?('scanner-profile-launch-modal')
                within_element('scanner-profile-launch-modal') do
                  click_button('Got it!')
                end
                # Wait for modal to be fully dismissed before proceeding
                has_no_element?('scanner-profile-launch-modal')
              end

              super
            end
          end
        end
      end
    end
  end
end
