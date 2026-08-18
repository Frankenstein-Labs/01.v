# frozen_string_literal: true

require 'spec_helper'

# Sign-in flows for users authenticating via smartcard against an
# LDAP server. Covers tab/pane rendering and form visibility for
# both `smartcard_auth: 'optional'` and `'required'` configurations.
#
# Add tests here when the precondition is "smartcard is configured
# on an LDAP server and we are rendering or submitting the LDAP
# smartcard sign-in form".

RSpec.describe 'Login', feature_category: :system_access do
  include LdapHelpers
  include UserLoginHelper
  include DeviseHelpers

  before do
    stub_licensed_features(extended_audit_events: true)
  end

  describe 'smartcard authentication against LDAP server' do
    let(:ldap_server_config) do
      {
        'provider_name' => 'ldapmain',
        'attributes' => {},
        'encryption' => 'plain',
        'smartcard_auth' => smartcard_auth_status,
        'uid' => 'uid',
        'base' => 'dc=example,dc=com'
      }
    end

    subject(:visit_page) { visit new_user_session_path }

    before do
      stub_licensed_features(smartcard_auth: true)
      stub_ldap_setting(enabled: true)
      allow(Gitlab.config.smartcard).to receive(:enabled).and_return(true)
      allow(::Gitlab::Auth::Ldap::Config).to receive_messages(enabled: true, servers: [ldap_server_config])
      allow_next_instance_of(ActionDispatch::Routing::RoutesProxy) do |instance|
        allow(instance).to receive(:user_ldapmain_omniauth_callback_path)
                    .and_return('/users/auth/ldapmain/callback')
      end
    end

    context 'when smartcard auth is optional' do
      let(:smartcard_auth_status) { 'optional' }

      it 'correctly renders tabs and panes' do # rubocop:disable RSpec/NoExpectationExample -- ensure_one_active_tab / ensure_one_active_pane contain the expectations
        visit_page

        ensure_one_active_tab
        ensure_one_active_pane
      end

      it 'shows LDAP login form' do
        visit_page

        expect(page).to have_selector('#ldapmain.tab-pane form[data-testid=new_ldap_user]')
      end

      it 'shows LDAP smartcard login form' do
        visit_page

        expect(page).to have_button(_('Sign in with smart card'))
      end
    end

    context 'when smartcard auth is required' do
      let(:smartcard_auth_status) { 'required' }

      it 'correctly renders tabs and panes' do # rubocop:disable RSpec/NoExpectationExample -- ensure_one_active_tab / ensure_one_active_pane contain the expectations
        visit_page

        ensure_one_active_tab
        ensure_one_active_pane
      end

      it 'does not show LDAP login form' do
        visit_page

        expect(page).not_to have_selector('#ldapmain.tab-pane form[data-testid=new_ldap_user]')
      end

      it 'shows LDAP smartcard login form' do
        visit_page

        expect(page).to have_button(_('Sign in with smart card'))
      end
    end
  end
end
