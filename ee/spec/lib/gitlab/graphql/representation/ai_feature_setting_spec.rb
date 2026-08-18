# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Representation::AiFeatureSetting, feature_category: :"self-hosted_models" do
  include_context 'with fetch_model_definitions_example'

  let_it_be(:self_hosted_model, freeze: false) do
    create(:ai_self_hosted_model, name: 'GPT Model', model: :gpt)
  end

  let_it_be(:code_completion_feature_setting, freeze: false) do
    create(:ai_feature_setting, { feature: :code_completions,
                                  provider: :self_hosted,
                                  self_hosted_model: self_hosted_model })
  end

  let_it_be(:duo_chat_feature_setting, freeze: false) do
    create(:ai_feature_setting, { feature: :duo_chat, provider: :vendored, self_hosted_model: nil })
  end

  let_it_be(:code_generations_feature_setting, freeze: false) do
    create(:ai_feature_setting, { feature: :code_generations, provider: :vendored, self_hosted_model: nil })
  end

  let_it_be(:feature_settings, freeze: false) do
    [
      code_completion_feature_setting,
      duo_chat_feature_setting,
      code_generations_feature_setting
    ]
  end

  let_it_be(:model_definitions_response, freeze: false) { fetch_model_definitions_example }

  let_it_be(:model_definitions, freeze: false) do
    ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(
      model_definitions_response
    )
  end

  let(:with_self_hosted_models) { true }
  let(:with_gitlab_models) { true }

  subject(:decorate) do
    described_class.decorate(
      feature_settings,
      with_self_hosted_models: with_self_hosted_models,
      with_gitlab_models: with_gitlab_models,
      model_definitions: model_definitions
    )
  end

  describe '.decorate' do
    context 'when feature_settings is empty' do
      let(:feature_settings) { [] }

      it { is_expected.to be_empty }
    end

    context 'when feature_settings is nil' do
      let(:feature_settings) { nil }

      it { is_expected.to be_empty }
    end

    context 'when feature_settings is present' do
      context "without self-hosted models" do
        let(:with_self_hosted_models) { false }

        it 'does not include valid_models' do
          decorate.each do |setting|
            expect(setting.valid_models).to be_empty
          end
        end

        it 'includes gitlab models' do
          duo_chat_setting = decorate.find { |s| s.feature == 'duo_chat' }
          expect(duo_chat_setting.default_gitlab_model).to eq({
            'name' => 'Claude Sonnet',
            'ref' => 'claude-sonnet',
            'model_provider' => 'Anthropic',
            'model_description' => 'Fast, cost-effective responses.',
            'cost_indicator' => '$$$'
          })
          expect(duo_chat_setting.valid_gitlab_models).to be_present
        end
      end

      context "without gitlab models" do
        let(:with_gitlab_models) { false }

        before do
          allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
        end

        it 'includes self-hosted models for compatible features' do
          code_completions_setting = decorate.find { |s| s.feature == 'code_completions' }
          expect(code_completions_setting.valid_models).to be_present
        end
      end

      context 'with self-hosted and gitlab models' do
        before do
          allow(::Ai::TestingTermsAcceptance).to receive(:has_accepted?).and_return(true)
        end

        it 'includes valid_models for compatible features' do
          code_completions_setting = decorate.find { |s| s.feature == 'code_completions' }
          expect(code_completions_setting.valid_models).to be_present
        end

        it 'includes valid gitlab models' do
          duo_chat_setting = decorate.find { |s| s.feature == 'duo_chat' }
          expect(duo_chat_setting.valid_gitlab_models).to contain_exactly(
            {
              'name' => 'Claude Sonnet',
              'ref' => 'claude-sonnet',
              'model_provider' => 'Anthropic',
              'model_description' => 'Fast, cost-effective responses.',
              'cost_indicator' => '$$$'
            },
            {
              'name' => 'GPT-4',
              'ref' => 'gpt-4',
              'model_provider' => 'OpenAI',
              'model_description' => 'For high-volume coding, reasoning, and routine workflows.',
              'cost_indicator' => '$'
            }
          )
        end
      end

      context 'with self-hosted feature setting' do
        subject(:decorated_self_hosted_setting) do
          decorate.find { |s| s.feature == 'code_completions' }
        end

        it 'does not include gitlab_model' do
          expect(decorated_self_hosted_setting.gitlab_model).to be_nil
        end

        it 'includes default_gitlab_model' do
          expect(decorated_self_hosted_setting.default_gitlab_model).to eq({
            "ref" => 'gpt-4',
            "name" => 'GPT-4',
            "model_provider" => 'OpenAI',
            'model_description' => 'For high-volume coding, reasoning, and routine workflows.',
            'cost_indicator' => '$'
          })
        end

        it 'includes valid gitlab models' do
          expect(decorated_self_hosted_setting.valid_gitlab_models).to match_array([
            {
              "ref" => 'gpt-4',
              "name" => 'GPT-4',
              "model_provider" => 'OpenAI',
              'model_description' => 'For high-volume coding, reasoning, and routine workflows.',
              'cost_indicator' => '$'
            }
          ])
        end

        it 'fetches the proper feature_setting' do
          expect(decorated_self_hosted_setting.feature_setting).to eq(code_completion_feature_setting)
        end
      end

      context 'with vendored feature setting' do
        let_it_be(:instance_setting, freeze: false) do
          create(:instance_model_selection_feature_setting,
            feature: :duo_chat,
            offered_model_ref: 'claude-sonnet',
            model_definitions: model_definitions_response)
        end

        it 'includes gitlab_model from offered_model_ref' do
          duo_chat_setting = decorate.find { |s| s.feature == 'duo_chat' }
          expect(duo_chat_setting.gitlab_model).to eq({
            'name' => 'Claude Sonnet',
            'ref' => 'claude-sonnet',
            'model_provider' => 'Anthropic',
            'model_description' => 'Fast, cost-effective responses.',
            'cost_indicator' => '$$$'
          })
        end
      end

      context 'when model definitions for feature does not exist' do
        it 'does not include gitlab data' do
          decorated_setting = decorate.find { |s| s.feature == 'code_generations' }
          expect(decorated_setting.gitlab_model).to be_nil
          expect(decorated_setting.default_gitlab_model).to be_nil
          expect(decorated_setting.valid_gitlab_models).to be_empty
        end
      end

      context 'with model allowlist on a vendored Agentic Chat feature setting' do
        let_it_be(:agentic_chat_definitions) do
          fetch_model_definitions_example.deep_dup.tap do |defs|
            defs['unit_primitives'] << {
              'feature_setting' => 'duo_agent_platform_agentic_chat',
              'default_model' => 'claude-sonnet',
              'selectable_models' => %w[claude-sonnet gpt-4],
              'beta_models' => []
            }
          end
        end

        let_it_be(:agentic_chat_ai_feature_setting) do
          create(:ai_feature_setting,
            feature: :duo_agent_platform_agentic_chat,
            provider: :vendored,
            self_hosted_model: nil)
        end

        let_it_be(:agentic_chat_instance_setting) do
          create(:instance_model_selection_feature_setting,
            feature: :duo_agent_platform_agentic_chat,
            offered_model_ref: 'claude-sonnet',
            model_definitions: agentic_chat_definitions,
            model_allowlist_enabled: true,
            model_allowlist_gitlab_model_refs: %w[gpt-4])
        end

        let_it_be(:feature_settings) { [agentic_chat_ai_feature_setting] }

        let_it_be(:model_definitions, freeze: false) do
          ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(agentic_chat_definitions)
        end

        it 'exposes allow_list with allowed flags and the currently chosen ref' do
          agentic_chat_setting = decorate.find { |s| s.feature == 'duo_agent_platform_agentic_chat' }

          expect(agentic_chat_setting.allow_list[:enabled]).to be(true)
          rows_by_ref = agentic_chat_setting.allow_list[:models].index_by { |m| m[:ref] }
          expect(rows_by_ref['claude-sonnet'])
            .to have_attributes(allowed: true, currently_chosen_model_for_feature: true)
          expect(rows_by_ref['gpt-4'])
            .to have_attributes(allowed: true, currently_chosen_model_for_feature: false)
        end
      end

      context 'with a vendored feature setting that does not support allowlists' do
        let_it_be(:duo_chat_instance_setting) do
          create(:instance_model_selection_feature_setting,
            feature: :duo_chat,
            offered_model_ref: 'claude-sonnet',
            model_definitions: model_definitions_response,
            model_allowlist_enabled: true,
            model_allowlist_gitlab_model_refs: %w[gpt-4])
        end

        it 'leaves allow_list nil because allowlists are Agentic-Chat-only in v1' do
          duo_chat_setting = decorate.find { |s| s.feature == 'duo_chat' }

          expect(duo_chat_setting.allow_list).to be_nil
        end
      end

      context 'with a non-vendored feature setting' do
        it 'leaves allow_list nil' do
          decorated_self_hosted_setting = decorate.find { |s| s.feature == 'code_completions' }

          expect(decorated_self_hosted_setting.allow_list).to be_nil
        end
      end
    end
  end
end
