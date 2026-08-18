# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DiscoverDuoProComponent, :aggregate_failures, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:namespace) }
  let(:page_scope) { page }
  let(:duo_buy_now_url) do
    base_url = ::Gitlab::Routing.url_helpers.subscription_portal_add_saas_duo_pro_seats_url(namespace.id)
    uri = Addressable::URI.parse(base_url)
    uri.query_values = { 'ref_source' => 'group_discover_duo_pro_page' }
    uri.to_s
  end

  subject(:component) { render_inline(described_class.new(namespace: namespace)) && page_scope }

  context 'when rendering the hero section' do
    let(:page_scope) { find_by_testid('hero-section') }

    it { is_expected.to have_content(s_('DuoProDiscover|Ship software faster')) }
    it { is_expected.to have_link(_('Buy now'), href: duo_buy_now_url) }
    it { is_expected.to have_link(href: 'https://player.vimeo.com/video/855805049?title=0&byline=0&portrait=0&badge=0&autopause=0&player_id=0&app_id=58479') }
  end

  context 'when rendering the why section' do
    let(:page_scope) { find_by_testid('why-section') }

    it { is_expected.to have_content(s_('DuoProDiscover|Why GitLab Duo Pro?')) }

    it { expect(component).to have_selector("[data-testid='why-entry']", count: 4) }

    it { is_expected.to have_content(s_('DuoProDiscover|Privacy-first AI')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Boost team collaboration')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Improve developer experience')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Transparent AI')) }

    it { is_expected.to have_link(_('AI Transparency Center'), href: 'https://about.gitlab.com/ai-transparency-center/') }
  end

  context 'when rendering the first core feature section' do
    let(:page_scope) { find_by_testid('core-feature-1') }

    it { is_expected.to have_content(s_('DuoProDiscover|Boost productivity with smart code assistance')) }

    it { expect(component).to have_selector("[data-testid='core-1-entry']", count: 4) }

    it { is_expected.to have_content(s_('DuoProDiscover|Automate mundane tasks')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Catch bugs early in the workflow')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Real-time guidance')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Use Chat to get up to speed')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Modernize code faster')) }
    it { is_expected.to have_content(s_('DuoProDiscover|Refactor code into modern')) }
  end

  context 'when rendering the footer actions' do
    let(:page_scope) { find_by_testid('discover-footer-actions') }

    it { is_expected.to have_link(_('Buy now'), href: duo_buy_now_url) }
  end

  context 'with trial active and expired concerns' do
    let(:cta_tracking_label) { 'duo_pro_active_trial' }
    let(:trial_active?) { true }
    let(:expected_data_attributes) do
      {
        glm_content: 'discover-duo-pro',
        cta_tracking: {
          action: 'click_contact_sales',
          label: cta_tracking_label
        }.to_json,
        button_attributes: {
          category: 'secondary',
          variant: 'confirm',
          class: 'gl-w-full @sm/panel:gl-w-auto',
          'data-testid': 'trial-discover-hand-raise-lead-button'
        }.to_json
      }
    end

    before do
      allow(GitlabSubscriptions::Trials::DuoPro)
        .to receive(:active_add_on_purchase_for_namespace?).with(namespace).and_return(trial_active?)
    end

    context 'when trial is active' do
      it 'has expected hand raise lead data attributes' do
        expect_hand_raise_data_attribute(expected_data_attributes)
      end

      it 'has the correct track action for AI transparency link for the trial status' do
        is_expected.to have_selector('a[href="https://about.gitlab.com/ai-transparency-center/"]')
        attributes = {
          testid: 'ai-transparency-link',
          action: 'click_documentation_link_duo_pro_trial_active',
          label: 'ai_transparency_center_feature'
        }
        is_expected.to have_tracking(attributes)
      end

      it 'has correct track label for the buy now links for the trial status' do
        is_expected.to have_selector("a[href='#{duo_buy_now_url}']", count: 2)
        attributes = { action: 'click_buy_now', label: cta_tracking_label }
        is_expected.to have_tracking(attributes.merge(testid: 'buy-now-top'))
        is_expected.to have_tracking(attributes.merge(testid: 'buy-now-bottom'))
      end
    end

    context 'when trial is expired' do
      let(:cta_tracking_label) { 'duo_pro_expired_trial' }
      let(:trial_active?) { false }

      it 'has expected hand raise lead data attributes' do
        expect_hand_raise_data_attribute(expected_data_attributes)
      end

      it 'has the correct track action for AI transparency link for the trial status' do
        is_expected.to have_selector('a[href="https://about.gitlab.com/ai-transparency-center/"]')
        attributes = {
          testid: 'ai-transparency-link',
          action: 'click_documentation_link_duo_pro_trial_expired',
          label: 'ai_transparency_center_feature'
        }
        is_expected.to have_tracking(attributes)
      end

      it 'has correct track label for the buy now links for the trial status' do
        is_expected.to have_selector("a[href='#{duo_buy_now_url}']", count: 2)
        attributes = { action: 'click_buy_now', label: cta_tracking_label }
        is_expected.to have_tracking(attributes.merge(testid: 'buy-now-top'))
        is_expected.to have_tracking(attributes.merge(testid: 'buy-now-bottom'))
      end
    end

    def expect_hand_raise_data_attribute(data_attributes)
      data_attributes.each do |attribute, value|
        is_expected
          .to have_selector(".js-hand-raise-lead-trigger[data-#{attribute.to_s.dasherize}='#{value}']", count: 2)
      end
    end
  end
end
