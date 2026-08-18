# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::FlagChecker, feature_category: :ai_abstraction_layer do
  let(:feature) { :feature_name }

  subject(:response) { described_class.flag_enabled_for_feature?(feature) }

  describe '#flag_enabled_for_feature?' do
    context 'for SM feature' do
      before do
        stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", feature => { self_managed: true })
      end

      context 'for self-managed features' do
        it 'returns true' do
          expect(response).to be(true)
        end
      end

      context 'for feature that is not available on self-managed' do
        before do
          stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", feature => { self_managed: false })
          stub_feature_flags(ai_global_switch: false)
        end

        it 'returns false' do
          expect(response).to be(false)
        end
      end
    end

    context 'for SAAS feature' do
      before do
        stub_const("::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST", feature => { self_managed: false })
      end

      context 'when global switch feature flag is disabled' do
        before do
          stub_feature_flags(ai_global_switch: false)
        end

        it 'returns false' do
          expect(response).to be(false)
        end
      end

      context 'when global switch feature flag is enabled' do
        before do
          stub_feature_flags(ai_global_switch: true)
        end

        it 'returns true' do
          expect(response).to be(true)
        end
      end
    end
  end
end
