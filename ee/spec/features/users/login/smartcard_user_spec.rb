# frozen_string_literal: true

require 'spec_helper'

# Sign-in flows for users authenticating via smartcard (direct, not
# via LDAP). Covers the smartcard tab/pane rendering with and
# without the smartcard_auth licensed feature, and the interaction
# between smartcard sessions and required-2FA.
#
# Add tests here when the precondition is "smartcard is configured
# at the application level and the user authenticates via
# smartcard". Smartcard-via-LDAP tests live in
# smartcard_via_ldap_user_spec.rb.

RSpec.describe 'Login', feature_category: :system_access do
  include LdapHelpers
  include UserLoginHelper
  include DeviseHelpers

  before do
    stub_licensed_features(extended_audit_events: true)
  end

  describe 'smartcard authentication' do
    before do
      allow(Gitlab.config.smartcard).to receive(:enabled).and_return(true)
    end

    subject(:visit_page) { visit new_user_session_path }

    context 'when smartcard is enabled' do
      context 'with smartcard_auth feature flag off' do
        before do
          stub_licensed_features(smartcard_auth: false)
        end

        it 'does not render any tabs' do
          visit_page

          expect_no_tabs
        end

        it 'renders link to sign up path' do
          visit new_user_session_path

          expect(page.body).to have_link('Register now', href: new_user_registration_path)
        end
      end

      context 'with smartcard_auth feature flag on' do
        before do
          stub_licensed_features(smartcard_auth: true)
        end

        it 'correctly renders tabs and panes' do
          visit_page

          expect_tab_pane_correctness(%w[Smartcard Standard])
        end

        it 'renders link to sign up path' do
          visit new_user_session_path

          expect(page.body).to have_link('Register now', href: new_user_registration_path)
        end

        describe 'with two-factor authentication required', :clean_gitlab_redis_sessions do
          let_it_be(:user) { create(:user, :with_namespace) }
          let_it_be(:smartcard_identity) { create(:smartcard_identity, user: user) }

          before do
            stub_application_setting(require_two_factor_authentication: true)
          end

          context 'with a smartcard session' do
            let(:openssl_certificate_store) { instance_double(OpenSSL::X509::Store) }
            let(:openssl_certificate) do
              instance_double(OpenSSL::X509::Certificate, subject: smartcard_identity.subject,
                issuer: smartcard_identity.issuer)
            end

            let(:encrypted_openssl_certificate) do
              encrypted_cert = Gitlab::CryptoHelper.aes256_gcm_encrypt(openssl_certificate.to_s)
              CGI.escape(encrypted_cert)
            end

            it 'does not ask for Two-Factor Authentication' do
              allow(Gitlab::Auth::Smartcard::Certificate).to receive(:store).and_return(openssl_certificate_store)
              allow(OpenSSL::X509::Certificate).to receive(:new).and_return(openssl_certificate)
              allow(openssl_certificate_store).to receive(:verify).and_return(true)

              # Loging using smartcard
              visit verify_certificate_smartcard_path(client_certificate: encrypted_openssl_certificate)

              visit user_settings_profile_path

              expect(page).not_to have_content(_('Enter verification code'))
            end
          end

          context 'without a smartcard session' do
            it 'asks for Two-Factor Authentication' do
              sign_in(user)

              visit user_settings_profile_path

              expect(page).to have_content(_('Enter verification code'))
            end
          end
        end
      end
    end
  end
end
