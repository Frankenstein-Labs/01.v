# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::DiscoverPremiumComponent, feature_category: :onboarding do
  let(:license) { build_stubbed(:license, :ultimate_trial) }
  let(:page_scope) { page }

  subject(:component) { render_inline(described_class.new(license: license)) && page_scope }

  context 'when rendering the hero section' do
    let(:page_scope) { find_by_testid('hero-section') }

    it 'has the hero heading' do
      is_expected.to have_content(
        s_('DuoCoreTrialDiscover|GitLab Premium, now with native AI')
      )
    end

    it 'has the hero text', :aggregate_failures do
      is_expected.to have_content(s_('DuoCoreTrialDiscover|Now featuring GitLab Duo Agent Platform'))

      is_expected.to have_content(
        s_(
          'DuoCoreTrialDiscover|Enterprise-grade AI-native capabilities to help ' \
            'you move faster while maintaining security and IP protection'
        )
      )
    end

    it 'does not have hand raise lead' do
      is_expected.not_to have_selector('.js-hand-raise-lead-trigger')
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

    it 'does not have hand raise lead' do
      is_expected.not_to have_selector('.js-hand-raise-lead-trigger')
    end
  end
end
