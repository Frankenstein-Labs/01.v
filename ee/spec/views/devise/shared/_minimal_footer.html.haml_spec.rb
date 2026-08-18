# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/shared/_minimal_footer', feature_category: :acquisition do
  subject { render && rendered }

  it { is_expected.to have_link(_('Terms'), href: terms_path) }
  it { is_expected.to have_link(_('Privacy'), href: 'https://about.gitlab.com/privacy') }

  context 'when one trust is enabled' do
    before do
      allow(view).to receive(:one_trust_enabled?).and_return(true)
    end

    it { is_expected.to have_button(_('Cookie Preferences'), class: 'ot-sdk-show-settings') }
  end

  context 'when one trust is disabled' do
    before do
      allow(view).to receive(:one_trust_enabled?).and_return(false)
    end

    it { is_expected.not_to have_button(_('Cookie Preferences'), class: 'ot-sdk-show-settings') }
  end

  context 'with disable_preferred_language_cookie feature flag disabled (default)' do
    before do
      stub_feature_flags(disable_preferred_language_cookie: false)
    end

    it { is_expected.to have_css('.js-language-switcher') }
  end

  context 'with disable_preferred_language_cookie feature flag enabled' do
    it { is_expected.not_to have_css('.js-language-switcher') }
  end
end
