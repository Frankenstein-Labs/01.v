# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Secure
          class NewOnDemandScan < QA::Page::Base
            view 'ee/app/assets/javascripts/on_demand_scans_form/components/on_demand_scans_form.vue' do
              element 'dast-scan-name-input'
              element 'on-demand-scan-submit-button'
              element 'on-demand-scan-save-button'
            end

            view 'ee/app/assets/javascripts/security_configuration/dast_profiles/dast_profiles_drawer' \
              '/dast_profiles_drawer_empty_state.vue' do
              element 'new-empty-profile-button'
            end

            view 'ee/app/assets/javascripts/security_configuration/dast_profiles/dast_scanner_profiles' \
              '/components/dast_scanner_profile_form.vue' do
              element 'profile-name-input'
              element 'scan-type-option'
            end

            view 'ee/app/assets/javascripts/security_configuration/dast_profiles/components' \
              '/base_dast_profile_form.vue' do
              element 'dast-profile-form-submit-button'
            end

            def enter_scan_name(scan_name)
              fill_element('dast-scan-name-input', scan_name)
            end

            def create_scanner_profile(name)
              click_select_scanner_profile
              click_new_empty_profile
              enter_profile_name(name)
              click_save_profile
            end

            def create_site_profile(name, url)
              click_select_site_profile
              click_new_empty_profile
              enter_profile_name(name)
              enter_url(url)
              click_save_profile
            end

            def save_and_run_scan
              click_element('on-demand-scan-submit-button')
            end

            def save_scan
              click_element('on-demand-scan-save-button')
            end

            private

            def click_select_scanner_profile
              click_button('Select scanner profile')
            end

            def click_select_site_profile
              click_button('Select site profile')
            end

            def click_new_empty_profile
              click_element('new-empty-profile-button')
            end

            def enter_profile_name(profile_name)
              fill_element('profile-name-input', profile_name)
            end

            def enter_url(url)
              fill_element('target-url-input', url)
            end

            def click_save_profile
              click_element('dast-profile-form-submit-button')
              wait_until do
                has_no_element?('dast-profile-form-submit-button')
              end
            end
          end
        end
      end
    end
  end
end
