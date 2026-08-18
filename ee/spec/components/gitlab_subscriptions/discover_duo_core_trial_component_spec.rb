# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DiscoverDuoCoreTrialComponent, :aggregate_failures, feature_category: :onboarding do
  let(:namespace) { build_stubbed(:namespace) }
  let(:page_scope) { page }

  subject(:component) { render_inline(described_class.new(namespace: namespace)) && page_scope }

  context 'when rendering the hero section' do
    let(:page_scope) { find_by_testid('hero-section') }

    it 'has the hero heading' do
      is_expected.to have_content(
        s_('DuoCoreTrialDiscover|GitLab Premium, now with native AI')
      )
    end

    it 'has the hero text' do
      is_expected.to have_content(s_('DuoCoreTrialDiscover|Now featuring GitLab Duo'))

      is_expected.to have_content(
        s_(
          'DuoCoreTrialDiscover|Enterprise-grade AI-native capabilities to help ' \
            'you move faster while maintaining security and IP protection'
        )
      )
    end

    it { is_expected.to have_link(_('Upgrade')) }
    it { is_expected.to have_link(href: 'https://player.vimeo.com/video/855805049?title=0&byline=0&portrait=0&badge=0&autopause=0&player_id=0&app_id=58479') }
  end

  context 'when rendering the why section' do
    let(:page_scope) { find_by_testid('why-section') }

    it { is_expected.to have_content(s_('DuoCoreTrialDiscover|Why GitLab Premium with Duo?')) }

    it { has_testid?('why-entry', context: component, count: 4) } # rubocop:disable RSpec/NoExpectationExample -- Expectation in matcher

    it { is_expected.to have_content(s_('DuoCoreTrialDiscover|Unified, secure, and collaborative code management')) }
    it { is_expected.to have_content(s_('DuoCoreTrialDiscover|Advanced CI/CD')) }

    it 'has the correct card headings' do
      is_expected.to have_content(
        s_('DuoCoreTrialDiscover|Greater developer productivity, collaboration, and quality')
      )
    end

    it { is_expected.to have_content(s_('DuoCoreTrialDiscover|Automated compliance')) }
  end

  context 'when rendering the core feature section' do
    let(:page_scope) { find_by_testid('core-feature-1') }

    it { has_testid?('core-1-entry', context: component, count: 4) } # rubocop:disable RSpec/NoExpectationExample -- Expectation in matcher

    it { is_expected.to have_content(s_('DuoCoreTrialDiscover|Native AI Benefits in Premium')) }
    it { is_expected.to have_content(s_('DuoCoreTrialDiscover|Boost productivity with smart code assistance')) }

    it 'has AI companion text' do
      is_expected.to have_content(
        s_('DuoCoreTrialDiscover|Get help from your AI companion throughout development')
      )
    end

    it { is_expected.to have_content(s_('DuoCoreTrialDiscover|Automate coding and delivery')) }

    it 'has accelerate text' do
      is_expected.to have_content(
        s_('DuoCoreTrialDiscover|Accelerate learning and collaboration through AI interaction')
      )
    end
  end

  context 'when rendering the footer actions' do
    let(:page_scope) { find_by_testid('discover-footer-actions') }

    it { is_expected.to have_link(_('Upgrade')) }
  end

  context 'with trial active and expired concerns' do
    let(:cta_tracking_label) { 'ultimate_active_trial' }
    let(:trial_active?) { true }
    let(:expected_data_attributes) do
      {
        product_interaction: 'SMB Promo',
        glm_content: 'trial_discover_page',
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
      allow(namespace).to receive(:ultimate_trial_plan?).and_return(trial_active?)
    end

    context 'when trial is active' do
      it 'has expected hand raise lead data attributes' do
        expect_hand_raise_data_attribute(expected_data_attributes)
      end
    end

    context 'when trial is expired' do
      let(:cta_tracking_label) { 'ultimate_expired_trial' }
      let(:trial_active?) { false }

      it 'has expected hand raise lead data attributes' do
        expect_hand_raise_data_attribute(expected_data_attributes)
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
