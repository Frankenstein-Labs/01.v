# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        module Settings
          class SamlSSO < ::QA::Page::Base
            include ::QA::Page::Component::Dropdown

            view 'ee/app/views/groups/saml_providers/_form.html.haml' do
              element 'identity-provider-sso-field'
              element 'certificate-fingerprint-field'
              element 'enforced-sso-checkbox'
              element 'save-changes-button'
            end

            view 'ee/app/assets/javascripts/saml_providers/saml_membership_role_selector/components/saml_membership_role_selector.vue' do
              element 'default-membership-role-dropdown'
            end

            view 'ee/app/views/groups/saml_providers/_test_button.html.haml' do
              element 'saml-settings-test-button'
            end

            view 'ee/app/views/groups/saml_providers/_info.html.haml' do
              element 'user-login-url-link'
            end

            def set_id_provider_sso_url(url)
              fill_element 'identity-provider-sso-field', url
            end

            def set_cert_fingerprint(fingerprint)
              fill_element 'certificate-fingerprint-field', fingerprint
            end

            def set_default_membership_role(role)
              click_element('default-membership-role-dropdown')
              within_element 'default-membership-role-dropdown' do
                select_item(role)
              end
            end

            def has_enforced_sso_checkbox?
              has_checkbox = has_element?('enforced-sso-checkbox', visible: false, wait: 5)
              QA::Runtime::Logger.debug "has_enforced_sso_checkbox?: #{has_checkbox}"
              has_checkbox
            end

            def enforce_sso_enabled?
              enabled = has_enforced_sso_checkbox? && find_element('enforced-sso-checkbox', visible: false).checked?
              QA::Runtime::Logger.debug "enforce_sso_enabled?: #{enabled}"
              enabled
            end

            def enforce_sso
              check_element('enforced-sso-checkbox', true) unless enforce_sso_enabled?
              QA::Support::Waiter.wait_until(raise_on_failure: true) { enforce_sso_enabled? }
            end

            def disable_enforced_sso
              uncheck_element('enforced-sso-checkbox', true) if enforce_sso_enabled?
              QA::Support::Waiter.wait_until(raise_on_failure: true) { !enforce_sso_enabled? }
            end

            def click_save_changes
              click_element 'save-changes-button'
            end

            def click_test_button
              click_element('saml-settings-test-button')
            end

            def click_user_login_url_link
              click_element 'user-login-url-link'
            end

            def user_login_url_link_text
              find_element('user-login-url-link').text
            end
          end
        end
      end
    end
  end
end
