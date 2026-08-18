# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::SelfHosted::Vendored, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }

  let(:params) do
    {
      current_file: {
        file_name: 'test.py',
        content_above_cursor: 'def hello():',
        content_below_cursor: '  pass'
      }
    }
  end

  let(:feature_setting) { nil }

  subject(:prompt) { described_class.new(params, current_user, feature_setting) }

  describe '#request_params' do
    context 'when code_completions is vendored' do
      it 'returns expected request params with GitLab default model configuration' do
        expected_params = {
          model_name: '',
          model_provider: 'gitlab',
          prompt_version: 1
        }

        expect(prompt.request_params).to eq(expected_params)
      end
    end

    context 'when gitlab model is pinned' do
      let(:feature_setting) { create(:instance_model_selection_feature_setting, :code_completions) }

      it 'returns the pinned model information' do
        expected_params = {
          model_name: "claude_sonnet_3_5",
          model_provider: "gitlab",
          prompt_version: 1
        }

        expect(prompt.request_params).to eq(expected_params)
      end
    end
  end
end
