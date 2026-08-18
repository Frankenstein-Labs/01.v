# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'ArkoseLabs content security policy', feature_category: :system_access do
  include ContentSecurityPolicyHelpers

  shared_examples 'configures Content Security Policy headers correctly' do |controller_class|
    it 'adds Arkose host value to the correct Content Security Policy directives', :aggregate_failures do
      visit page_path

      arkose_url = 'https://*.arkoselabs.com'
      csp = response_headers['Content-Security-Policy']
      directives = csp.split(';').map(&:strip)
      script_src = directives.find { |d| /^script-src/.match d }
      frame_src = directives.find { |d| /^frame-src/.match d }
      connect_src = directives.find { |d| /^connect-src/.match d }
      style_src = directives.find { |d| /^style-src/.match d }

      expect(script_src).to include(arkose_url)
      expect(frame_src).to include(arkose_url)
      expect(connect_src).to include(arkose_url)
      expect(style_src).to include(%q(unsafe-inline))
    end

    context 'when there is no global CSP config' do
      before do
        csp = ActionDispatch::ContentSecurityPolicy.new
        stub_csp_for_controller(controller_class, csp)
      end

      it 'does not add ArkoseLabs URL to Content Security Policy headers' do
        visit page_path

        expect(response_headers['Content-Security-Policy']).to be_blank
      end
    end
  end

  context 'when in registration page' do
    let(:page_path) { new_user_registration_path }

    it_behaves_like 'configures Content Security Policy headers correctly', RegistrationsController
  end

  context 'when in identity verification page' do
    let(:page_path) { arkose_labs_challenge_signup_identity_verification_path }

    before do
      Warden.on_next_request do |proxy|
        proxy.raw_session[:verification_user_id] = create(:user, :unconfirmed).id
      end
    end

    it_behaves_like 'configures Content Security Policy headers correctly',
      Users::RegistrationsIdentityVerificationController
  end
end
