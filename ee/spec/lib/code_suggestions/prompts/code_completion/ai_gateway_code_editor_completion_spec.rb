# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::AiGatewayCodeEditorCompletion, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }

  let(:file_name) { 'test.py' }
  let(:content_above_cursor) { 'some content_above_cursor' }
  let(:content_below_cursor) { 'some content_below_cursor' }
  let(:stream) { false }
  let(:feature_setting) { nil }

  let(:params) do
    {
      current_file: {
        file_name: file_name,
        content_above_cursor: content_above_cursor,
        content_below_cursor: content_below_cursor
      },
      stream: stream
    }
  end

  subject(:builder) { described_class.new(params, current_user, feature_setting) }

  before do
    allow(::Ai::AmazonQ).to receive(:connected?).and_return(false)
  end

  describe '#request_params' do
    let(:expected_component) do
      {
        type: 'code_editor_completion',
        payload: {
          file_name: 'test.py',
          content_above_cursor: 'some content_above_cursor',
          content_below_cursor: 'some content_below_cursor',
          language_identifier: 'Python',
          stream: false
        }
      }
    end

    context 'with the GitLab-default model (no feature setting)' do
      it 'builds the completion component without model_metadata' do
        expect(builder.request_params).to eq(prompt_components: [expected_component])
      end
    end

    context 'when streaming is requested' do
      let(:stream) { true }

      it 'passes the stream flag through to the payload' do
        expect(builder.request_params.dig(:prompt_components, 0, :payload, :stream)).to be(true)
      end
    end

    context 'when the content exceeds the max size' do
      before do
        stub_const("#{described_class}::MAX_CONTENT_CHARS", 5)
      end

      it 'trims content_above_cursor from the end and content_below_cursor from the start', :aggregate_failures do
        payload = builder.request_params.dig(:prompt_components, 0, :payload)

        expect(payload[:content_above_cursor]).to eq('ursor')
        expect(payload[:content_below_cursor]).to eq('some ')
      end
    end

    context 'with a self-hosted model' do
      let_it_be(:self_hosted_model) { create(:ai_self_hosted_model, model: :codellama) }

      let(:feature_setting) do
        create(
          :ai_feature_setting,
          feature: :code_completions,
          self_hosted_model: self_hosted_model,
          provider: :self_hosted
        )
      end

      it 'includes self-hosted model_metadata' do
        expect(builder.request_params).to eq(
          prompt_components: [expected_component],
          model_metadata: {
            provider: :openai,
            name: 'codellama',
            endpoint: self_hosted_model.endpoint,
            api_key: self_hosted_model.api_token,
            identifier: self_hosted_model.identifier
          }
        )
      end
    end

    context 'with a model pinned via namespace model selection' do
      let(:feature_setting) do
        create(
          :ai_namespace_feature_setting,
          feature: :code_completions,
          offered_model_ref: 'claude_sonnet_3_7_20250219'
        )
      end

      it 'includes gitlab model_metadata with the pinned identifier' do
        expect(builder.request_params).to eq(
          prompt_components: [expected_component],
          model_metadata: {
            provider: 'gitlab',
            feature_setting: feature_setting.feature,
            identifier: 'claude_sonnet_3_7_20250219'
          }
        )
      end
    end

    context 'when Amazon Q is connected' do
      before do
        allow(::Ai::AmazonQ).to receive(:connected?).and_return(true)
        stub_current_organization(current_user.organization)
        ::Ai::Setting.for_organization(current_user.organization).update!(amazon_q_role_arn: 'role::arn')
      end

      it 'includes Amazon Q model_metadata' do
        expect(builder.request_params).to eq(
          prompt_components: [expected_component],
          model_metadata: {
            provider: :amazon_q,
            name: :amazon_q,
            role_arn: 'role::arn'
          }
        )
      end
    end
  end
end
