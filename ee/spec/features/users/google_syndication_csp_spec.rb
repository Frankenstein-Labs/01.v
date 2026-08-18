# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Google Syndication content security policy', feature_category: :subscription_management do
  include ContentSecurityPolicyHelpers

  let(:gtm_enabled) { true }
  let(:gtm_id) { 'GTM-ID' }
  let(:connect_src) { ['*.google.com/pagead/landing', 'pagead2.googlesyndication.com/pagead/landing'] }
  let(:csp) { ActionDispatch::ContentSecurityPolicy.new { |p| p.default_src '' } }

  subject(:csp_header) { response_headers['Content-Security-Policy'] }

  before do
    stub_config(extra: { google_tag_manager_nonce_id: gtm_id })
    stub_saas_features(marketing_google_tag_manager: gtm_enabled)
    stub_csp_for_controller(RegistrationsController, csp)

    visit new_user_registration_path
  end

  it 'includes the relevant connect-src CSP' do
    expect(find_csp_directive('connect-src', header: csp_header)).to include(*connect_src)
  end

  context 'when disabled' do
    let(:gtm_enabled) { false }

    it 'does not include the relevant connect-src CSP headers' do
      expect(csp_header).not_to include(*connect_src)
    end
  end

  context 'when CSP is absent' do
    let(:csp) { ActionDispatch::ContentSecurityPolicy.new }

    it 'does not have Content Security Policy headers' do
      expect(csp_header).not_to include(*connect_src)
    end
  end
end
