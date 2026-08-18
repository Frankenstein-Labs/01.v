# frozen_string_literal: true

require 'spec_helper'

# Sign-in flows for users whose identity is managed by an external
# SSO provider and who have password authentication disabled at the
# application level. Covers refusal of password sign-in when the
# `disable_password_authentication_for_users_with_sso_identities`
# setting is on.
#
# Add tests here when the precondition is "the user has an SSO
# identity and instance policy disables password authentication for
# such users".

RSpec.describe 'Login', feature_category: :system_access do
  include LdapHelpers
  include UserLoginHelper
  include DeviseHelpers

  before do
    stub_licensed_features(extended_audit_events: true)
  end

  describe 'when password authentication is disabled for SSO users' do
    let_it_be(:user) { create(:omniauth_user, password_automatically_set: false) }

    before do
      stub_application_setting(disable_password_authentication_for_users_with_sso_identities: true)
    end

    it 'does not allow password authentication', :js do
      submit_sign_in_form_for(user, password: user.password)

      expect(page).to have_content("Invalid login or password")
    end
  end
end
