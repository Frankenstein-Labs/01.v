# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Groups > Usage quotas', :saas, feature_category: :consumables_cost_management do
  include ContentSecurityPolicyHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }

  before_all do
    group.add_owner(user)
  end

  before do
    sign_in(user)
  end

  describe 'Pending members page', :js do
    context 'with pending members' do
      let!(:awaiting_member) { create(:group_member, :awaiting, group: group) }

      it 'lists awaiting members and approves them' do
        visit pending_members_group_usage_quotas_path(group)

        expect(find_by_testid('pending-members-content')).to have_text(awaiting_member.user.name)

        click_button 'Approve'
        click_button 'OK'
        wait_for_requests

        expect(awaiting_member.reload).to be_active
      end
    end
  end

  describe 'Google Tag Manager', :with_trial_types do
    let(:gtm_id) { 'GTM-ID' }
    let(:gtm_script_url) { 'www.googletagmanager.com' }
    let(:gtm_csp_url) { '*.googletagmanager.com' }
    let(:gtm_enabled) { true }
    let(:onetrust_id) { 'ONE_TRUST_ID' }
    let(:onetrust_script_url) { 'https://cdn.cookielaw.org/consent/ONE_TRUST_ID/OtAutoBlock.js' }
    let(:onetrust_csp_url) { 'https://*.onetrust.com' }
    let(:onetrust_enabled) { true }

    let(:csp_header) { response_headers['Content-Security-Policy'] }

    before do
      csp = ActionDispatch::ContentSecurityPolicy.new { |p| p.default_src '' }
      stub_csp_for_controller(Groups::UsageQuotasController, csp)

      stub_config(extra: { google_tag_manager_id: gtm_id,
                           google_tag_manager_nonce_id: gtm_id,
                           one_trust_id: onetrust_id })
      stub_saas_features(marketing_google_tag_manager: gtm_enabled)
      stub_feature_flags(ecomm_instrumentation: onetrust_enabled)

      visit group_usage_quotas_path(group)
    end

    context 'with OneTrust enabled' do
      it 'has the Google Tag Manager and OneTrust scripts and CSP records', :aggregate_failures do
        expect(page.html).to include(gtm_script_url)
        expect(csp_header).to include(gtm_csp_url)
        expect(page.html).to include(onetrust_script_url)
        expect(csp_header).to include(onetrust_csp_url)
      end
    end

    context 'with OneTrust disabled' do
      let(:onetrust_enabled) { false }

      it 'has the Google Tag Manager and no OneTrust scripts and CSP records', :aggregate_failures do
        expect(page.html).to include(gtm_script_url)
        expect(csp_header).to include(gtm_csp_url)
        expect(page.html).not_to include(onetrust_script_url)
        expect(csp_header).not_to include(onetrust_csp_url)
      end
    end

    context 'when disabled' do
      let(:gtm_enabled) { false }
      let(:onetrust_enabled) { false }

      it "doesn't include the related scripts and CSP", :aggregate_failures do
        expect(page.html).not_to include(gtm_script_url)
        expect(csp_header).not_to include(gtm_csp_url)
        expect(page.html).not_to include(onetrust_script_url)
        expect(csp_header).not_to include(onetrust_csp_url)
      end
    end
  end
end
