# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::TermsHelper, feature_category: :system_access do
  describe '#terms_service_notice_link', :aggregate_failures do
    let(:button_text) { 'terms-text' }

    subject(:result) { helper.terms_service_notice_link(button_text) }

    context 'when onboarding is disabled' do
      it 'returns correct html' do
        expect(result).to have_content(_('By clicking'))
        expect(result).to have_content(button_text)
        expect(result).not_to have_content(_('you accept the GitLab'))
      end
    end

    context 'when onboarding is enabled' do
      before do
        stub_saas_features(gitlab_terms: true)
      end

      it 'returns correct html' do
        expect(result).to have_link('', href: terms_path)
        expect(result).to have_content(_('By clicking'))
        expect(result).to have_content(button_text)
        expect(result).to have_content(_('or registering through a third party you accept the GitLab'))
      end
    end
  end

  describe '#sm_welcome_onboarding_terms_service_notice_link', :aggregate_failures do
    let(:button_text) { 'terms-text' }

    subject(:result) { helper.sm_welcome_onboarding_terms_service_notice_link(button_text) }

    it 'returns correct html' do
      expect(result).to have_link('', href: 'https://about.gitlab.com/terms')
      expect(result).to have_content(_('By clicking'))
      expect(result).to have_content(button_text)
      expect(result).to have_content(_('you accept the'))
    end
  end
end
