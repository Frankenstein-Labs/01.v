# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DiscoverDuoEnterpriseComponent, :aggregate_failures, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:namespace) }
  let(:page_scope) { page }

  subject(:component) { render_inline(described_class.new(namespace: namespace)) && page_scope }

  context 'when rendering the hero section' do
    let(:page_scope) { find_by_testid('hero-section') }

    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Ship software faster')) }
    it { is_expected.not_to have_link(_('Buy now')) }
    it { is_expected.to have_link(href: 'https://player.vimeo.com/video/855805049?title=0&byline=0&portrait=0&badge=0&autopause=0&player_id=0&app_id=58479') }
  end

  context 'when rendering the why section' do
    let(:page_scope) { find_by_testid('why-section') }

    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Why GitLab Duo Enterprise?')) }

    it { has_testid?('why-entry', context: component, count: 4) } # rubocop:disable RSpec/NoExpectationExample -- Expectation in matcher

    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Privacy-first AI')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Boost team collaboration')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Improve developer experience')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Transparent AI')) }

    it { is_expected.to have_link(_('AI Transparency Center'), href: 'https://about.gitlab.com/ai-transparency-center/') }
  end

  context 'when rendering the first core feature section' do
    let(:page_scope) { find_by_testid('core-feature-1') }

    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Boost productivity with smart code assistance')) }

    it { has_testid?('core-1-entry', context: component, count: 3) } # rubocop:disable RSpec/NoExpectationExample -- Expectation in matcher

    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Fortify your code')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|GitLab Duo Vulnerability explanation')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Advanced troubleshooting')) }
  end

  context 'when rendering the second core feature section' do
    let(:page_scope) { find_by_testid('core-feature-2') }

    it { has_testid?('core-2-entry', context: component, count: 2) } # rubocop:disable RSpec/NoExpectationExample -- Expectation in matcher

    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Summarization and templating')) }
    it { is_expected.to have_content(s_('DuoEnterpriseDiscover|Measure the ROI of AI')) }
  end

  context 'when rendering the footer actions' do
    let(:page_scope) { find_by_testid('discover-footer-actions') }

    it { is_expected.not_to have_link(_('Buy now')) }
  end

  context 'with trial active and expired concerns' do
    let(:cta_tracking_label) { 'duo_enterprise_active_trial' }
    let(:trial_active?) { true }
    let(:expected_data_attributes) do
      {
        glm_content: 'discover-duo-enterprise',
        cta_tracking: {
          action: 'click_contact_sales',
          label: cta_tracking_label
        }.to_json,
        button_attributes: {
          category: 'primary',
          variant: 'confirm',
          class: 'gl-w-full @sm/panel:gl-w-auto',
          'data-testid': 'trial-discover-hand-raise-lead-button'
        }.to_json
      }
    end

    before do
      allow(GitlabSubscriptions::Trials::DuoEnterprise)
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
          action: 'click_documentation_link_duo_enterprise_trial_active',
          label: 'ai_transparency_center_feature'
        }
        is_expected.to have_tracking(attributes)
      end
    end

    context 'when trial is expired' do
      let(:cta_tracking_label) { 'duo_enterprise_expired_trial' }
      let(:trial_active?) { false }

      it 'has expected hand raise lead data attributes' do
        expect_hand_raise_data_attribute(expected_data_attributes)
      end

      it 'has the correct track action for AI transparency link for the trial status' do
        is_expected.to have_selector('a[href="https://about.gitlab.com/ai-transparency-center/"]')
        attributes = {
          testid: 'ai-transparency-link',
          action: 'click_documentation_link_duo_enterprise_trial_expired',
          label: 'ai_transparency_center_feature'
        }
        is_expected.to have_tracking(attributes)
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
