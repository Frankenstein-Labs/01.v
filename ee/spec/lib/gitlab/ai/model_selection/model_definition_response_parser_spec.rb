# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser, feature_category: :"self-hosted_models" do
  include_context 'with fetch_model_definitions_example'

  let(:model_definitions_response) { fetch_model_definitions_example }

  subject(:parser) { described_class.new(model_definitions_response) }

  describe '#model_with_ref' do
    context 'when the ref exists' do
      it 'returns the model with the given ref' do
        expect(parser.model_with_ref('claude-sonnet')).to eq(
          {
            'name' => 'Claude Sonnet',
            'ref' => 'claude-sonnet',
            'model_provider' => 'Anthropic',
            'model_description' => 'Fast, cost-effective responses.',
            'cost_indicator' => '$$$'
          }
        )
      end
    end

    context 'when the ref does not exist' do
      it 'returns nil' do
        expect(parser.model_with_ref('non-existent-model')).to be_nil
      end
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.model_with_ref(:duo_chat)).to be_nil
      end
    end
  end

  describe '#model_with_ref!' do
    context 'when the ref exists' do
      it 'returns the model with the given ref' do
        expect(parser.model_with_ref!('claude-sonnet')).to eq(
          {
            'name' => 'Claude Sonnet',
            'ref' => 'claude-sonnet',
            'model_provider' => 'Anthropic',
            'model_description' => 'Fast, cost-effective responses.',
            'cost_indicator' => '$$$'
          }
        )
      end
    end

    context 'when the ref does not exist' do
      it 'raises an error' do
        expect { parser.model_with_ref!('non-existent-model') }
          .to raise_error(ArgumentError, 'Model reference was not found in the model definition')
      end
    end

    context 'when definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'raises an error' do
        expect { parser.model_with_ref!('claude-sonnet') }
          .to raise_error(ArgumentError, 'Model reference was not found in the model definition')
      end
    end
  end

  describe '#definition_for_feature' do
    context 'when the feature exists' do
      it 'returns the definition for the given feature' do
        expect(parser.definition_for_feature(:duo_chat)).to eq({
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet gpt-4],
          'beta_models' => []
        })
      end
    end

    context 'when the feature does not exist' do
      it 'returns nil' do
        expect(parser.definition_for_feature(:non_existent_feature)).to be_nil
      end
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.definition_for_feature(:duo_chat)).to be_nil
      end
    end

    context 'when definitions has no unit_primitives key' do
      let(:model_definitions_response) { { 'models' => [] } }

      it 'returns nil' do
        expect(parser.definition_for_feature(:duo_chat)).to be_nil
      end
    end
  end

  describe '#default_model_ref_for_feature' do
    context 'when the feature exists' do
      it 'returns the default model ref' do
        expect(parser.default_model_ref_for_feature(:duo_chat)).to eq('claude-sonnet')
      end
    end

    context 'when the feature does not exist' do
      it 'returns nil' do
        expect(parser.default_model_ref_for_feature(:non_existent_feature)).to be_nil
      end
    end

    context 'when the feature definition has no default model' do
      let(:model_definitions_response) do
        fetch_model_definitions_example.deep_dup.tap do |definitions|
          definitions['unit_primitives'].first.delete('default_model')
        end
      end

      it 'returns nil' do
        expect(parser.default_model_ref_for_feature(:duo_chat)).to be_nil
      end
    end
  end

  describe '#selectable_model_refs_for_feature' do
    it 'returns selectable model refs for the given feature' do
      expect(parser.selectable_model_refs_for_feature(:duo_chat)).to eq(%w[claude-sonnet gpt-4])
    end

    context 'when selectable models contain blank and duplicate refs' do
      let(:model_definitions_response) do
        fetch_model_definitions_example.deep_dup.tap do |definitions|
          definitions['unit_primitives'].first['selectable_models'] = ['claude-sonnet', '', nil, 'gpt-4', 'gpt-4']
        end
      end

      it 'removes blank and duplicate refs' do
        expect(parser.selectable_model_refs_for_feature(:duo_chat)).to eq(%w[claude-sonnet gpt-4])
      end
    end

    context 'when dev selectable models are requested' do
      let(:model_definitions_response) do
        fetch_model_definitions_example.deep_dup.tap do |definitions|
          definitions['unit_primitives'].first['dev'] = {
            'selectable_models' => ['claude-sonnet-3-7', '', nil, 'gpt-4']
          }
        end
      end

      it 'includes dev refs and removes blank and duplicate refs' do
        expect(parser.selectable_model_refs_for_feature(:duo_chat, include_dev: true))
          .to eq(%w[claude-sonnet gpt-4 claude-sonnet-3-7])
      end
    end

    context 'when the feature does not exist' do
      it 'returns an empty array' do
        expect(parser.selectable_model_refs_for_feature(:non_existent_feature)).to eq([])
      end
    end

    context 'when the feature definition has no selectable models' do
      let(:model_definitions_response) do
        fetch_model_definitions_example.deep_dup.tap do |definitions|
          definitions['unit_primitives'].first.delete('selectable_models')
        end
      end

      it 'returns an empty array' do
        expect(parser.selectable_model_refs_for_feature(:duo_chat)).to eq([])
      end
    end

    context 'when definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'returns an empty array' do
        expect(parser.selectable_model_refs_for_feature(:duo_chat)).to eq([])
      end
    end
  end

  describe '#definitions_with_dev_selectable_models' do
    context 'when definitions are nil' do
      let(:model_definitions_response) { nil }

      it 'returns nil' do
        expect(parser.definitions_with_dev_selectable_models).to be_nil
      end
    end

    context 'when definitions are present' do
      let(:model_definitions_response) do
        fetch_model_definitions_example.deep_dup.tap do |definitions|
          definitions['unit_primitives'].first['selectable_models'] = %w[claude-sonnet gpt-4]
          definitions['unit_primitives'].first['dev'] = {
            'selectable_models' => ['claude-sonnet-3-7', 'gpt-4']
          }
          definitions['unit_primitives'].second['dev'] = {
            'selectable_models' => []
          }
        end
      end

      it 'returns merged definitions without mutating the original definitions', :aggregate_failures do
        merged_definitions = parser.definitions_with_dev_selectable_models

        expect(merged_definitions['unit_primitives'].first['selectable_models'])
          .to eq(%w[claude-sonnet gpt-4 claude-sonnet-3-7])
        expect(merged_definitions['unit_primitives'].second['selectable_models']).to eq(%w[gpt-4])
        expect(model_definitions_response['unit_primitives'].first['selectable_models'])
          .to eq(%w[claude-sonnet gpt-4])
      end
    end
  end

  describe '#gitlab_models_by_ref' do
    it 'returns a hash of models indexed by their ref' do
      expect(parser.gitlab_models_by_ref).to eq(
        {
          'claude-sonnet' => {
            'name' => 'Claude Sonnet',
            'ref' => 'claude-sonnet',
            'model_provider' => 'Anthropic',
            'model_description' => 'Fast, cost-effective responses.',
            'cost_indicator' => '$$$'
          },
          'gpt-4' => {
            'name' => 'GPT-4',
            'ref' => 'gpt-4',
            'model_provider' => 'OpenAI',
            'model_description' => 'For high-volume coding, reasoning, and routine workflows.',
            'cost_indicator' => '$'
          },
          'claude-sonnet-3-7' => {
            'name' => 'Claude Sonnet 3.7',
            'ref' => 'claude-sonnet-3-7',
            'model_provider' => 'Anthropic',
            'model_description' => 'Fast, cost-effective responses.',
            'cost_indicator' => '$$'
          }
        }
      )
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.gitlab_models_by_ref).to be_nil
      end
    end

    context 'if definitions is empty' do
      let(:model_definitions_response) { {} }

      it 'is nil' do
        expect(parser.gitlab_models_by_ref).to be_nil
      end
    end
  end

  describe '#model_definition_per_feature' do
    it 'returns a hash of unit primitives indexed by feature setting' do
      expect(parser.model_definition_per_feature).to eq({
        'duo_chat' => {
          'feature_setting' => 'duo_chat',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet gpt-4],
          'beta_models' => []
        },
        'code_completions' => {
          'feature_setting' => 'code_completions',
          'default_model' => 'gpt-4',
          'selectable_models' => %w[gpt-4],
          'beta_models' => []
        },
        'review_merge_request' => {
          'feature_setting' => 'review_merge_request',
          'default_model' => 'claude-sonnet',
          'selectable_models' => %w[claude-sonnet claude-sonnet-3-7],
          'beta_models' => []
        }
      })
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.model_definition_per_feature).to be_nil
      end
    end

    context 'if definitions is empty' do
      let(:model_definitions_response) { {} }

      it 'is nil' do
        expect(parser.model_definition_per_feature).to be_nil
      end
    end
  end

  describe '#deprecated_models' do
    it 'returns a list of deprecated models' do
      expect(parser.deprecated_models).to eq([
        {
          'name' => 'Claude Sonnet 3.7',
          'identifier' => 'claude-sonnet-3-7',
          'provider' => 'Anthropic',
          'description' => 'Fast, cost-effective responses.',
          'deprecation' => {
            'deprecation_date' => '2025-10-28',
            'removal_version' => '18.8'
          },
          'cost_indicator' => '$$'
        }
      ])
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'is nil' do
        expect(parser.deprecated_models).to be_nil
      end
    end

    context 'if definitions is empty' do
      let(:model_definitions_response) { {} }

      it 'is nil' do
        expect(parser.deprecated_models).to be_nil
      end
    end
  end

  describe '#feature_deprecated_models' do
    context 'when the feature has deprecated models' do
      let(:model_definitions_response) do
        fetch_model_definitions_example.deep_dup.tap do |definitions|
          definitions['unit_primitives'].first['deprecated_models'] = [
            { 'identifier' => 'gpt-4', 'deprecation_date' => '2026-08-05', 'removal_version' => '19.6' }
          ]
        end
      end

      it 'returns the deprecated models merged with their global model data' do
        expect(parser.feature_deprecated_models(:duo_chat)).to eq([
          {
            'name' => 'GPT-4',
            'identifier' => 'gpt-4',
            'provider' => 'OpenAI',
            'description' => 'For high-volume coding, reasoning, and routine workflows.',
            'cost_indicator' => '$',
            'deprecation' => { 'deprecation_date' => '2026-08-05', 'removal_version' => '19.6' }
          }
        ])
      end
    end

    context 'when the feature has no deprecated_models' do
      it 'returns an empty array' do
        expect(parser.feature_deprecated_models(:duo_chat)).to eq([])
      end
    end

    context 'when the feature does not exist' do
      it 'returns an empty array' do
        expect(parser.feature_deprecated_models(:non_existent_feature)).to eq([])
      end
    end

    context 'when a deprecated model identifier is not present in the models list' do
      let(:model_definitions_response) do
        fetch_model_definitions_example.deep_dup.tap do |definitions|
          definitions['unit_primitives'].first['deprecated_models'] = [
            { 'identifier' => 'non-existent-model', 'deprecation_date' => '2026-08-05', 'removal_version' => '19.6' }
          ]
        end
      end

      it 'skips it' do
        expect(parser.feature_deprecated_models(:duo_chat)).to eq([])
      end
    end

    context 'if definitions is nil' do
      let(:model_definitions_response) { nil }

      it 'returns an empty array' do
        expect(parser.feature_deprecated_models(:duo_chat)).to eq([])
      end
    end
  end
end
