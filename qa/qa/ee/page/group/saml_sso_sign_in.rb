# frozen_string_literal: true

module QA
  module EE
    module Page
      module Group
        class SamlSSOSignIn < QA::Page::Base
          view 'ee/app/views/groups/sso/saml.html.haml' do
            element 'saml-sso-signin-button'
          end

          view 'ee/app/assets/javascripts/saml_sso/components/saml_authorize.vue' do
            element 'saml-sso-signin-button'
          end

          def click_sign_in
            QA::Support::Retrier.retry_until do
              click_element 'saml-sso-signin-button'
              !has_element?('saml-sso-signin-button', wait: 0)
            end
          end
        end
      end
    end
  end
end
