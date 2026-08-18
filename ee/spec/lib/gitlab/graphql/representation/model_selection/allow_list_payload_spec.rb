# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Representation::ModelSelection::AllowListPayload,
  :aggregate_failures, feature_category: :"self-hosted_models" do
  let(:feature) { ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name }

  let(:model_definitions) do
    {
      'models' => [
        { 'identifier' => 'model_a', 'name' => 'Model A', 'provider' => 'anthropic',
          'description' => 'Model A description', 'cost_indicator' => '$$$' },
        { 'identifier' => 'model_b', 'name' => 'Model B', 'provider' => 'openai',
          'description' => 'Model B description', 'cost_indicator' => '$$' },
        { 'identifier' => 'model_default', 'name' => 'Default Model', 'provider' => 'anthropic',
          'description' => 'Default description', 'cost_indicator' => '$$$' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => feature.to_s,
          'default_model' => 'model_default',
          'selectable_models' => %w[model_a model_b model_default]
        }
      ]
    }
  end

  let(:model_definition_parser) do
    ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(model_definitions)
  end

  let(:offered_models) do
    model_definition_parser
      .selectable_model_refs_for_feature(feature)
      .map { |ref| model_definition_parser.model_with_ref(ref) }
  end

  let(:feature_setting) do
    build(
      :ai_namespace_feature_setting,
      feature: feature,
      offered_model_ref: 'model_a',
      model_allowlist_enabled: true,
      model_allowlist_gitlab_model_refs: %w[model_b]
    )
  end

  subject(:payload) do
    described_class.build(
      feature_setting: feature_setting,
      model_definition_parser: model_definition_parser,
      offered_models: offered_models
    )
  end

  describe '.build' do
    it 'returns the allowlist enabled flag and one row per offered model' do
      expect(payload[:enabled]).to be(true)
      expect(payload[:models].map { |m| m[:ref] }).to match_array(%w[model_a model_b model_default])
    end

    it 'marks rows in the effective allowed set as allowed' do
      rows_by_ref = payload[:models].index_by { |m| m[:ref] }

      expect(rows_by_ref['model_a'][:allowed]).to be(true)
      expect(rows_by_ref['model_b'][:allowed]).to be(true)
      expect(rows_by_ref['model_default'][:allowed]).to be(false)
    end

    it 'marks the currently chosen ref' do
      rows_by_ref = payload[:models].index_by { |m| m[:ref] }

      expect(rows_by_ref['model_a'][:currently_chosen_model_for_feature]).to be(true)
      expect(rows_by_ref['model_b'][:currently_chosen_model_for_feature]).to be(false)
      expect(rows_by_ref['model_default'][:currently_chosen_model_for_feature]).to be(false)
    end

    it 'carries through offered model attributes' do
      row = payload[:models].find { |m| m[:ref] == 'model_a' }

      expect(row).to have_attributes(
        ref: 'model_a',
        name: 'Model A',
        model_provider: 'anthropic',
        model_description: 'Model A description',
        cost_indicator: '$$$'
      )
    end

    context 'when offered_model_ref is blank' do
      let(:feature_setting) do
        build(
          :ai_namespace_feature_setting,
          feature: feature,
          offered_model_ref: nil,
          model_allowlist_enabled: true,
          model_allowlist_gitlab_model_refs: %w[model_b]
        )
      end

      it 'treats the GitLab default model as currently chosen and implicitly allowed' do
        rows_by_ref = payload[:models].index_by { |m| m[:ref] }

        expect(rows_by_ref['model_default'][:currently_chosen_model_for_feature]).to be(true)
        expect(rows_by_ref['model_default'][:allowed]).to be(true)
        expect(rows_by_ref['model_b'][:allowed]).to be(true)
        expect(rows_by_ref['model_a'][:allowed]).to be(false)
      end
    end

    context 'when the allowlist is disabled' do
      let(:feature_setting) do
        build(
          :ai_namespace_feature_setting,
          feature: feature,
          offered_model_ref: 'model_a',
          model_allowlist_enabled: false,
          model_allowlist_gitlab_model_refs: %w[model_b]
        )
      end

      it 'reports enabled: false and marks every row allowed: false' do
        expect(payload[:enabled]).to be(false)
        expect(payload[:models].map { |m| m[:allowed] }).to all(be(false))
      end

      it 'still marks the currently chosen ref so the FE can decorate the row' do
        rows_by_ref = payload[:models].index_by { |m| m[:ref] }

        expect(rows_by_ref['model_a'][:currently_chosen_model_for_feature]).to be(true)
        expect(rows_by_ref['model_b'][:currently_chosen_model_for_feature]).to be(false)
      end
    end

    context 'when offered_models is empty' do
      let(:offered_models) { [] }

      it 'returns an empty models array' do
        expect(payload).to have_attributes(enabled: true, models: [])
      end
    end

    context 'when a group boundary is given' do
      let(:group) { build_stubbed(:group) }

      subject(:payload) do
        described_class.build(
          feature_setting: feature_setting,
          model_definition_parser: model_definition_parser,
          offered_models: offered_models,
          group: group
        )
      end

      it 'exposes the group on the payload and every row' do
        expect(payload.group).to eq(group)
        expect(payload[:models].map(&:group)).to all(eq(group))
      end
    end

    context 'when no group boundary is given' do
      it 'leaves the group nil on the payload and every row' do
        expect(payload.group).to be_nil
        expect(payload[:models].map(&:group)).to all(be_nil)
      end
    end
  end
end
