# frozen_string_literal: true

require 'spec_helper'

# Tests for the EE-specific behavior of the sign-in page itself
# (not the sign-in flow): query-parameter sanitization on the
# `login` / `remember_me` inputs (with the two_step_sign_in feature
# flag and SaaS variants) and the Explore/Help-link visibility
# under restricted-visibility application settings.
#
# Add tests here when the precondition is "we render the sign-in
# page in <some EE configuration>" and the test doesn't actually
# submit credentials.

RSpec.describe 'Login', feature_category: :system_access do
  include LdapHelpers
  include UserLoginHelper
  include DeviseHelpers

  before do
    stub_licensed_features(extended_audit_events: true)
  end

  context 'when login param is present' do
    let(:path) { new_user_session_path(login: "<script></script>foo@bar.com") }

    let(:visit_page) do
      visit path
    end

    context 'when two_step_sign_in feature flag is enabled' do
      before do
        stub_feature_flags(two_step_sign_in: true)
      end

      context 'when SaaS feature is available', :saas_redirect_sign_in_when_login_not_found do
        it 'sanitizes and sets value of login input' do
          visit_page

          expect(page.find('#user_login', visible: :all).value).to eq('foo@bar.com')
        end
      end

      context 'when SaaS feature is not available' do
        it 'does not set value of login input' do
          visit_page

          expect(page.find('#user_login', visible: :all).value).to be_nil
        end
      end
    end
  end

  context 'when remember_me param is present' do
    let(:path) { new_user_session_path(remember_me: "<script></script>1") }

    let(:visit_page) do
      visit path
    end

    context 'when two_step_sign_in feature flag is enabled' do
      before do
        stub_feature_flags(two_step_sign_in: true)
      end

      context 'when SaaS feature is available', :saas_redirect_sign_in_when_login_not_found do
        it 'sanitizes and sets value of remember me input' do
          visit_page

          expect(page.find('#user_remember_me', visible: :all).value).to eq('1')
        end
      end

      context 'when SaaS feature is not available' do
        it 'does not set value of remember me input' do
          visit_page

          expect(page.find('#user_remember_me', visible: :all).value).to be_nil
        end
      end
    end

    context 'when feature flag is not enabled' do
      before do
        stub_feature_flags(two_step_sign_in: false)
      end

      it 'does not set value of remember me input' do
        visit_page

        expect(page.find('#user_remember_me', visible: :all).value).to be_nil
      end
    end
  end

  describe 'restricted visibility levels' do
    context 'when restricted levels contain public level' do
      before do
        stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::PUBLIC])
      end

      it 'hides Explore link' do
        visit new_user_session_path

        expect(page).to have_no_link("Explore")
      end

      it 'hides help link' do
        visit new_user_session_path

        expect(page).to have_no_link("Help")
      end
    end

    context 'when restricted levels do not contain public level' do
      it 'displays Explore and Help links' do
        visit new_user_session_path

        href = find_link("Help")[:href]

        expect(href).to eq("/help")
        expect(page).to have_link("Explore")
      end
    end
  end
end
