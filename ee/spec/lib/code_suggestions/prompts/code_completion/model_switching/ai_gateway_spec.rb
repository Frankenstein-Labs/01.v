# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::ModelSwitching::AiGateway, feature_category: :"self-hosted_models" do
  let(:params) { { project: create(:project) } }
  let_it_be(:namespace_feature_setting) do
    create(:ai_namespace_feature_setting,
      feature: :code_completions,
      offered_model_ref: 'claude_sonnet_3_7_20250219',
      namespace: create(:group)
    )
  end

  let_it_be(:current_user) { create(:user) }

  let(:prompt) do
    described_class.new(
      params,
      current_user,
      namespace_feature_setting
    )
  end

  describe '#request_params' do
    subject(:request_params) { prompt.request_params }

    let(:expected_params) do
      {
        model_provider: 'gitlab',
        model_name: namespace_feature_setting&.offered_model_ref,
        prompt_version: 3,
        prompt: expected_prompt
      }
    end

    context 'when the model pinned is an Anthropic model' do
      let(:expected_prompt) do
        [
          { content: be_a(String), role: :system },
          { content: nil, role: :user }
        ]
      end

      it 'returns the correct request params, with prompt included' do
        expect(request_params).to include(expected_params)
      end
    end

    context 'when the model pinned is not an Anthropic model' do
      let_it_be(:namespace_feature_setting) do
        create(:ai_namespace_feature_setting,
          feature: :code_completions,
          offered_model_ref: 'codestral_2501_fireworks',
          namespace: create(:group)
        )
      end

      let(:expected_prompt) { nil }

      it 'returns the correct request params, with no prompt included' do
        expect(request_params).to include(expected_params)
      end
    end
  end
end
