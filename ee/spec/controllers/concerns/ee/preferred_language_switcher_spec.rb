# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PreferredLanguageSwitcher, feature_category: :acquisition do
  include StubLanguagesTranslationPercentage

  controller(ActionController::Base) do
    include PreferredLanguageSwitcher

    before_action :init_preferred_language, only: :new

    def new
      render html: 'new page'
    end
  end

  subject { cookies[:preferred_language] }

  before do
    stub_feature_flags(disable_preferred_language_cookie: false)
    stub_languages_translation_percentage(fr: 99, de: 7)
  end

  context 'when the marketing_site_language SaaS feature is available' do
    before do
      stub_saas_features(marketing_site_language: true)
    end

    context 'when first visit' do
      let(:glm_source) { 'about.gitlab.com' }
      let(:accept_language_header) { nil }

      before do
        request.env['HTTP_ACCEPT_LANGUAGE'] = accept_language_header

        get :new, params: { glm_source: glm_source }
      end

      it { is_expected.to eq Gitlab::CurrentSettings.default_preferred_language }

      context 'when language param is valid' do
        let(:glm_source) { 'about.gitlab.com/fr-fr/' }

        it { is_expected.to eq 'fr' }

        context 'for case insensitivity on language' do
          let(:glm_source) { 'about.gitlab.com/fr-FR/' }

          it { is_expected.to eq 'fr' }
        end

        context 'for case insensitivity on marketing site URL' do
          let(:glm_source) { 'ABOUT.gitlab.com/fr-fr/' }

          it { is_expected.to eq 'fr' }
        end
      end

      context 'when language param is invalid' do
        context 'when language is non-sense' do
          # QA is a language code preserved for testing
          let(:glm_source) { 'about.gitlab.com/qa-qa/' }

          it { is_expected.to eq Gitlab::CurrentSettings.default_preferred_language }
        end

        context 'when the language has not high levels of translation' do
          let(:glm_source) { 'about.gitlab.com/de-de/' }

          it { is_expected.to eq Gitlab::CurrentSettings.default_preferred_language }
        end

        context 'when the glm_source is not the marketing site' do
          let(:glm_source) { 'some.othersite.com/fr-fr/' }

          it { is_expected.to eq Gitlab::CurrentSettings.default_preferred_language }
        end
      end

      context 'when language params and language header are both valid' do
        let(:accept_language_header) { 'zh-CN,zh;q=0.8,zh-TW;q=0.7' }
        let(:glm_source) { 'about.gitlab.com/fr-fr/' }

        it { is_expected.to eq 'fr' }
      end
    end
  end

  context 'when the marketing_site_language SaaS feature is not available' do
    let(:glm_source) { 'about.gitlab.com/fr-fr/' }
    let(:accept_language_header) { nil }

    before do
      stub_saas_features(marketing_site_language: false)
      request.env['HTTP_ACCEPT_LANGUAGE'] = accept_language_header

      get :new, params: { glm_source: glm_source }
    end

    it { is_expected.to eq Gitlab::CurrentSettings.default_preferred_language }
  end
end
