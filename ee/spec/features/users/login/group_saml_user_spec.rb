# frozen_string_literal: true

require 'spec_helper'

# Sign-in flows for users authenticating via Group SAML on SaaS.
# Covers the terms disclaimer on the SSO landing page and the
# WebAuthn 2FA prompt that follows a successful SAML assertion.
#
# Add tests here when the precondition is "user is signing in via a
# group-level SAML SSO provider".

RSpec.describe 'Login', feature_category: :system_access do
  include LdapHelpers
  include UserLoginHelper
  include DeviseHelpers
  include Features::TwoFactorHelpers

  before do
    stub_licensed_features(extended_audit_events: true)
  end

  describe 'via Group SAML', :saas do
    let(:saml_provider) { create(:saml_provider) }
    let(:group) { saml_provider.group }
    let(:identity) { create(:group_saml_identity, user: user, saml_provider: saml_provider) }

    before do
      stub_licensed_features(group_saml: true)
      mock_group_saml(uid: identity.extern_uid)
    end

    around do |example|
      with_omniauth_full_host { example.run }
    end

    context 'with enforced terms' do
      include TermsHelper

      let(:user) { create(:user) }

      it 'shows the terms disclaimer' do
        enforce_terms

        visit sso_group_saml_providers_path(group)

        expect(page).to have_content(
          'By clicking Sign in or registering through a third party you accept the GitLab Terms of Use ' \
            'and acknowledge the Privacy Statement and Cookie Policy'
        )
      end
    end

    context 'with WebAuthn two factor', :js do
      let(:user) { create(:user, :two_factor_via_webauthn) }

      before do
        mock_group_saml(uid: identity.extern_uid)
      end

      # The WebAuthn challenge renders the Vue screen with two_factor_vue on and the legacy
      # HAML screen with it off; assert each UI's own retry and recovery affordances.
      with_and_without_ff(:two_factor_vue) do
        it 'shows WebAuthn prompt after SAML' do
          visit sso_group_saml_providers_path(group, token: group.saml_discovery_token)

          click_link 'Sign in'
          expect(page).to have_content('Failed to connect to your device')

          # Mock the webauthn procedure to neither reject or resolve, just do nothing
          # Using the built-in credentials.get functionality would result in an SecurityError
          # as these tests are executed using an IP-address as effective domain
          page.execute_script <<~JS
            navigator.credentials.get = function() {
              return new Promise((resolve) => {
                window.gl.resolveWebauthn = resolve;
              });
            }
          JS

          expect_webauthn_retry_prompt(user)

          fake_successful_webauthn_authentication

          expect(page).to have_current_path group_path(group), ignore_query: true
        end
      end
    end
  end
end
