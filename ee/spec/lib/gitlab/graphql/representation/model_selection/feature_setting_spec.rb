# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Graphql::Representation::ModelSelection::FeatureSetting,
  :aggregate_failures, feature_category: :"self-hosted_models" do
  let_it_be(:group) { create(:group) }

  let(:feature) { :duo_chat } # arbitrary feature name used by unit_primitives below

  # Minimal model_definitions structure expected by the decorator
  let(:model_definitions) do
    {
      'models' => [
        { 'identifier' => 'm1', 'name' => 'Model One', 'provider' => 'anthropic',
          'description' => 'Model one description', 'cost_indicator' => '$' },
        { 'identifier' => 'm2', 'name' => 'Model Two', 'provider' => 'anthropic',
          'description' => 'Model two description', 'cost_indicator' => '$$' },
        { 'identifier' => 'm3', 'name' => 'Model Three', 'provider' => 'openai' }
      ],
      'unit_primitives' => [
        {
          'feature_setting' => feature.to_s,
          'default_model' => 'm1',
          'selectable_models' => ['m1', 'm2', '', nil, 'm2'], # duplicates and blanks should be ignored
          'dev' => {
            'selectable_models' => ['m3']
          }
        }
      ]
    }
  end

  let(:feature_setting_record) { create(:ai_feature_setting, feature: feature) }

  describe '.decorate' do
    context 'when feature_settings is nil or empty' do
      it 'returns [] for nil' do
        expect(described_class.decorate(nil, model_definitions: model_definitions)).to eq([])
      end

      it 'returns [] for empty array' do
        expect(described_class.decorate([], model_definitions: model_definitions)).to eq([])
      end
    end

    context 'when feature_settings contain a matching feature (happy path)' do
      it 'decorates with default_model and selectable_models (no dev overrides)' do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(false)
        current_user = build(:user)
        allow(current_user).to receive(:gitlab_team_member?).and_return(false) # non-employee => no dev overrides

        result = described_class.decorate(
          [feature_setting_record],
          model_definitions: model_definitions,
          current_user: current_user
        )

        expect(result.size).to eq(1)
        dec = result.first

        expect(dec.feature_setting).to eq(feature_setting_record)
        expect(dec.default_model).to eq(
          { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
            cost_indicator: '$' }
        )
        expect(dec.selectable_models).to match_array(
          [
            { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
              cost_indicator: '$' },
            { ref: 'm2', name: 'Model Two', model_provider: 'anthropic', model_description: 'Model two description',
              cost_indicator: '$$' }
          ]
        )
      end

      it 'does not apply dev overrides when user is not a GitLab team member' do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
        current_user = build(:user)
        allow(current_user).to receive(:gitlab_team_member?).and_return(false)

        dec = described_class.decorate(
          [feature_setting_record],
          model_definitions: model_definitions,
          current_user: current_user
        ).first

        expect(dec.default_model).to eq(
          { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
            cost_indicator: '$' }
        )
        expect(dec.selectable_models).to match_array(
          [
            { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
              cost_indicator: '$' },
            { ref: 'm2', name: 'Model Two', model_provider: 'anthropic', model_description: 'Model two description',
              cost_indicator: '$$' }
          ]
        )
      end

      it 'does not apply dev overrides when current_user is nil' do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)

        dec = described_class.decorate(
          [feature_setting_record],
          model_definitions: model_definitions,
          current_user: nil
        ).first

        expect(dec.default_model).to eq(
          { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
            cost_indicator: '$' }
        )
        expect(dec.selectable_models).to match_array(
          [
            { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
              cost_indicator: '$' },
            { ref: 'm2', name: 'Model Two', model_provider: 'anthropic', model_description: 'Model two description',
              cost_indicator: '$$' }
          ]
        )
      end

      it 'applies developer overrides when user is a GitLab team member' do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
        current_user = build(:user)
        allow(current_user).to receive(:gitlab_team_member?).and_return(true)

        result = described_class.decorate(
          [feature_setting_record],
          model_definitions: model_definitions,
          current_user: current_user
        )

        dec = result.first
        expect(dec.default_model).to eq(
          { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
            cost_indicator: '$' }
        )
        # selectable = base + dev (unique, blanks removed)
        expect(dec.selectable_models).to match_array(
          [
            { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
              cost_indicator: '$' },
            { ref: 'm2', name: 'Model Two', model_provider: 'anthropic', model_description: 'Model two description',
              cost_indicator: '$$' },
            { ref: 'm3', name: 'Model Three', model_provider: 'openai', model_description: nil, cost_indicator: nil }
          ]
        )
      end

      it 'does not apply dev overrides on self-managed instances even for employees' do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(false)
        current_user = build(:user)
        allow(current_user).to receive(:gitlab_team_member?).and_return(true)

        dec = described_class.decorate(
          [feature_setting_record],
          model_definitions: model_definitions,
          current_user: current_user
        ).first

        expect(dec.default_model).to eq(
          { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
            cost_indicator: '$' }
        )
        expect(dec.selectable_models).to match_array(
          [
            { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
              cost_indicator: '$' },
            { ref: 'm2', name: 'Model Two', model_provider: 'anthropic', model_description: 'Model two description',
              cost_indicator: '$$' }
          ]
        )
      end

      it 'does not apply dev overrides when dev config is not present' do
        allow(Gitlab::Saas).to receive(:feature_available?).with(:gitlab_com_subscriptions).and_return(true)
        current_user = build(:user)
        allow(current_user).to receive(:gitlab_team_member?).and_return(true)

        defs = model_definitions.deep_dup
        defs['unit_primitives'][0].delete('dev')

        dec = described_class.decorate(
          [feature_setting_record],
          model_definitions: defs,
          current_user: current_user
        ).first

        expect(dec.default_model).to eq(
          { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
            cost_indicator: '$' }
        )
        expect(dec.selectable_models).to match_array(
          [
            { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
              cost_indicator: '$' },
            { ref: 'm2', name: 'Model Two', model_provider: 'anthropic', model_description: 'Model two description',
              cost_indicator: '$$' }
          ]
        )
      end
    end

    context 'when no unit_primitives entry matches the feature' do
      it 'filters out the feature_setting (returns [])' do
        defs = {
          'models' => model_definitions['models'],
          'unit_primitives' => [
            { 'feature_setting' => 'some_other_feature', 'default_model' => 'm1', 'selectable_models' => ['m1'] }
          ]
        }

        result = described_class.decorate(
          [feature_setting_record],
          model_definitions: defs
        )

        expect(result).to eq([])
      end
    end

    context 'when a referenced model identifier is missing' do
      it 'raises ArgumentError (default_model missing)' do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(false)
        bad_defs = model_definitions.deep_dup
        bad_defs['unit_primitives'][0]['default_model'] = 'ghost'

        expect do
          described_class.decorate([feature_setting_record], model_definitions: bad_defs)
        end.to raise_error(ArgumentError, /Model reference was not found/)
      end

      it 'raises ArgumentError (selectable_models contains unknown id)' do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(false)
        bad_defs = model_definitions.deep_dup
        bad_defs['unit_primitives'][0]['selectable_models'] = %w[m1 ghost]

        expect do
          described_class.decorate([feature_setting_record], model_definitions: bad_defs)
        end.to raise_error(ArgumentError, /Model reference was not found/)
      end
    end

    context 'when model_definitions are not passed in but exist on the record' do
      it 'uses feature_setting.model_definitions from DB' do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(false)
        fs = build(:ai_feature_setting, feature: feature)
        allow(fs).to receive(:model_definitions).and_return(model_definitions)

        dec = described_class.decorate([fs]).first
        expect(dec.default_model).to eq(
          { ref: 'm1', name: 'Model One', model_provider: 'anthropic', model_description: 'Model one description',
            cost_indicator: '$' }
        )
      end
    end

    context 'when model_definitions arg is nil and feature_setting does not respond to model_definitions' do
      it 'returns an empty array without raising an error' do
        fs = build(:ai_feature_setting, feature: feature)

        result = described_class.decorate([fs], model_definitions: nil)

        expect(result).to eq([])
      end
    end

    context 'when the feature setting record supports the model allowlist' do
      let(:feature) { :duo_agent_platform_agentic_chat }

      let_it_be(:group) { create(:group) }
      let(:namespace_feature_setting) do
        build(
          :ai_namespace_feature_setting,
          namespace: group,
          feature: feature,
          offered_model_ref: 'm1',
          model_allowlist_enabled: true,
          model_allowlist_gitlab_model_refs: %w[m2]
        )
      end

      before do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(true)
      end

      it 'decorates the allow_list payload using the offered models' do
        dec = described_class.decorate(
          [namespace_feature_setting],
          model_definitions: model_definitions,
          current_user: nil
        ).first

        expect(dec.allow_list[:enabled]).to be(true)
        rows_by_ref = dec.allow_list[:models].index_by { |m| m[:ref] }
        expect(rows_by_ref['m1'])
          .to have_attributes(allowed: true, currently_chosen_model_for_feature: true)
        expect(rows_by_ref['m2'])
          .to have_attributes(allowed: true, currently_chosen_model_for_feature: false)
      end
    end

    context 'when the feature setting record is allowlist-capable but not Agentic Chat' do
      let(:feature) { :duo_chat }

      let_it_be(:group) { create(:group) }
      let(:namespace_feature_setting) do
        build(
          :ai_namespace_feature_setting,
          namespace: group,
          feature: feature,
          offered_model_ref: 'm1',
          model_allowlist_enabled: true,
          model_allowlist_gitlab_model_refs: %w[m2]
        )
      end

      before do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(true)
      end

      it 'leaves allow_list nil because allowlists are Agentic-Chat-only in v1' do
        dec = described_class.decorate(
          [namespace_feature_setting],
          model_definitions: model_definitions,
          current_user: nil
        ).first

        expect(dec.allow_list).to be_nil
      end
    end

    context 'when the feature setting record does not support the model allowlist' do
      it 'leaves allow_list nil' do
        allow(Gitlab::Saas).to receive(:feature_available?).and_return(false)
        current_user = build(:user)
        allow(current_user).to receive(:gitlab_team_member?).and_return(false)

        dec = described_class.decorate(
          [feature_setting_record],
          model_definitions: model_definitions,
          current_user: current_user
        ).first

        expect(dec.allow_list).to be_nil
      end
    end
  end
end
