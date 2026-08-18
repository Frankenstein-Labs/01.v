# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::NamespaceFeatureSetting, feature_category: :"self-hosted_models" do
  let(:group) { create(:group) }
  let(:is_saas) { true }

  before do
    stub_saas_features(gitlab_com_subscriptions: is_saas)
  end

  subject(:ai_feature_setting) do
    build(:ai_namespace_feature_setting, namespace: group)
  end

  describe 'associations' do
    it 'belongs to groups' do
      is_expected.to belong_to(:namespace)
         .class_name('::Group')
         .inverse_of(:ai_feature_settings)
    end

    it { is_expected.to validate_uniqueness_of(:feature).scoped_to(:namespace_id).ignoring_case_sensitivity }
  end

  describe '#build_with_offered_model_ref' do
    subject(:record) { ai_feature_setting.build_with_offered_model_ref('selected_ref') }

    it 'builds a new unpersisted record for the same namespace and feature with the given offered model ref',
      :aggregate_failures do
      expect(record).to be_a(described_class)
      expect(record).not_to be_persisted
      expect(record.namespace).to eq(group)
      expect(record.feature).to eq(ai_feature_setting.feature)
      expect(record.offered_model_ref).to eq('selected_ref')
    end
  end

  describe 'when ::Ai::FeatureConfigurable is included' do
    context 'with request model info' do
      let(:feature_setting) { create(:ai_namespace_feature_setting) }

      # results for #model_metadata_params and #model_request_params
      # are expected to be the same
      let(:expected_params_for_request) { expected_params_for_metadata }

      context 'when model info should be resolved' do
        it_behaves_like 'configurable AI features resolves model info correctly' do
          let(:expected_params_for_metadata) do
            {
              feature_setting: "code_completions",
              identifier: "claude_sonnet_3_7",
              provider: "gitlab"
            }
          end
        end
      end

      context 'when the feature setting is default' do
        it_behaves_like 'configurable AI features resolves model info correctly' do
          let(:feature_setting) { create(:ai_namespace_feature_setting, offered_model_ref: nil) }
          let(:expected_params_for_metadata) do
            {
              feature_setting: "code_completions",
              identifier: nil,
              provider: "gitlab"
            }
          end
        end
      end
    end
  end

  describe '.find_or_initialize_by_feature' do
    let(:existing_feature) { ai_feature_setting.feature.to_sym }
    let(:new_feature_enum) { :code_completions }

    context 'when namespace is nil' do
      it 'returns nil' do
        result = described_class.find_or_initialize_by_feature(nil, existing_feature)
        expect(result).to be_nil
      end
    end

    context 'when namespace is not root' do
      let(:child_group) { create(:group, parent: group) }

      it 'returns nil' do
        result = described_class.find_or_initialize_by_feature(child_group, existing_feature)
        expect(result).to be_nil
      end
    end

    context 'when the instance is not SAAS' do
      let(:is_saas) { false }

      it 'returns nil' do
        result = described_class.find_or_initialize_by_feature(group, existing_feature)
        expect(result).to be_nil
      end
    end

    context 'when duo_features_enabled is false on root namespace' do
      before do
        group.namespace_settings.update!(duo_features_enabled: false)
      end

      it 'returns the feature setting' do
        ai_feature_setting.save!
        result = described_class.find_or_initialize_by_feature(group, existing_feature)
        expect(result).to eq(ai_feature_setting)
      end
    end

    it 'returns existing setting when one exists for the feature' do
      ai_feature_setting.save!
      result = described_class.find_or_initialize_by_feature(group, existing_feature)
      expect(result).to eq(ai_feature_setting)
    end

    context 'for duo chat tools' do
      let!(:duo_chat_feature_setting) do
        create(:ai_namespace_feature_setting, feature: :duo_chat, offered_model_ref: nil, namespace: group)
      end

      it 'returns the duo chat feature setting for all duo chat tools' do
        described_class::DUO_CHAT_TOOLS.each do |feature_sym|
          result = described_class.find_or_initialize_by_feature(group, feature_sym)
          expect(result).to eq(duo_chat_feature_setting)
          expect(result.feature).to eq('duo_chat')
        end
      end
    end

    it 'initializes a new setting when none exists for the feature' do
      new_feature = :code_completions
      result = described_class.find_or_initialize_by_feature(group, new_feature_enum)
      expect(result).to be_a(described_class)
      expect(result).to be_new_record
      expect(result.namespace).to eq(group)
      expect(result.feature).to eq(new_feature.to_s)
    end
  end

  it_behaves_like 'model selection feature setting'

  describe ".non_default" do
    subject { described_class.non_default }

    context 'without default settings' do
      let!(:feature_settings) do
        [
          create(:ai_namespace_feature_setting, namespace: group),
          create(:ai_namespace_feature_setting, feature: :duo_chat, offered_model_ref: nil, namespace: group),
          create(:ai_namespace_feature_setting, feature: :duo_chat_explain_code, offered_model_ref: "",
            namespace: group)
        ]
      end

      it 'returns only features settings with non-default models' do
        expect(described_class.non_default).to contain_exactly(feature_settings[0])
      end
    end

    context 'with default settings' do
      it { is_expected.to be_empty }
    end
  end

  describe '.any_non_default_for_duo_chat?' do
    let(:namespace) { create(:group) }

    subject { described_class.any_non_default_for_duo_chat?(namespace.id) }

    context 'when there are no duo chat feature settings' do
      it { is_expected.to be(false) }
    end

    context 'when there are duo chat feature settings but all are default or non-duochat settings' do
      before do
        create(:ai_namespace_feature_setting, feature: :duo_chat, offered_model_ref: nil, namespace: namespace)
        create(:ai_namespace_feature_setting, feature: :duo_chat_explain_code, offered_model_ref: "",
          namespace: namespace)
        create(:ai_namespace_feature_setting, feature: :code_completions, offered_model_ref: 'claude_sonnet_3_7',
          namespace: namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when there are non-default duo chat feature settings' do
      before do
        create(
          :ai_namespace_feature_setting,
          feature: :duo_chat,
          offered_model_ref: 'claude-3-7-sonnet-20250219',
          namespace: namespace
        )
      end

      it { is_expected.to be(true) }
    end

    context 'when there are non-default settings for both duo chat and other features' do
      before do
        create(
          :ai_namespace_feature_setting,
          feature: :duo_chat,
          offered_model_ref: 'claude-3-7-sonnet-20250219',
          namespace: namespace
        )

        create(
          :ai_namespace_feature_setting,
          feature: :code_completions,
          offered_model_ref: 'claude_sonnet_3_7',
          namespace: namespace
        )
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.with_non_default_code_completions' do
    let_it_be(:namespaces) { create_list(:group, 3) }
    let_it_be(:namespace1_id) { namespaces[1].id }
    let_it_be(:namespace2_id) { namespaces[2].id }

    let_it_be(:feature_setting2) do
      create(
        :ai_namespace_feature_setting,
        feature: :code_completions,
        offered_model_ref: 'claude_sonnet_3_7',
        namespace_id: namespace1_id
      )
    end

    subject(:result) do
      described_class.with_non_default_code_completions(namespace_ids)
    end

    describe '.enabled_features_for with duo_agent_platform feature flag' do
      let(:namespace) { create(:group) }

      before do
        namespace.namespace_settings.update!(experiment_features_enabled: true)
      end

      it 'includes duo_agent_platform in enabled features' do
        enabled_features = described_class.enabled_features_for(namespace)
        expect(enabled_features.keys).to include(:duo_agent_platform)
      end
    end

    describe '.enabled_features_for excludes LEVEL_EXCLUDED_FEATURES' do
      let(:namespace) { create(:group) }

      it 'excludes glab_ask_command in enabled features' do
        enabled_features = described_class.enabled_features_for(namespace)
        expect(enabled_features.keys).not_to include(:glab_ask_command)
      end
    end

    context 'with feature_discovery_search' do
      describe '.enabled_features_for' do
        let(:namespace) { create(:group) }

        context 'when experiment features are not enabled for the namespace' do
          it 'excludes feature_discovery_search' do
            enabled_features = described_class.enabled_features_for(namespace)
            expect(enabled_features.keys).not_to include(:feature_discovery_search)
          end
        end

        context 'when experiment features are enabled for the namespace' do
          before do
            namespace.namespace_settings.update!(experiment_features_enabled: true)
          end

          it 'excludes feature_discovery_search when the feature flag is disabled for the namespace' do
            stub_feature_flags(feature_discovery_gemini_search: false)

            enabled_features = described_class.enabled_features_for(namespace)
            expect(enabled_features.keys).not_to include(:feature_discovery_search)
          end

          it 'includes feature_discovery_search when the feature flag is enabled for the namespace' do
            stub_feature_flags(feature_discovery_gemini_search: namespace)

            enabled_features = described_class.enabled_features_for(namespace)
            expect(enabled_features.keys).to include(:feature_discovery_search)
          end
        end
      end
    end

    context 'when a namespace has the default model selected' do
      let(:namespace_ids) { [namespace2_id] }

      it 'returns an empty array' do
        expect(result).to be_empty
      end
    end

    context 'when mixing default and non-default model selections' do
      let(:namespace_ids) { [namespace1_id, namespace2_id] }

      it 'returns only the records with non-default code completion settings' do
        expect(result).to contain_exactly(feature_setting2)
      end
    end
  end

  describe '#set_to_gitlab_default?' do
    context 'when offered_model_ref is nil' do
      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting, offered_model_ref: nil, namespace: group)
      end

      it 'returns true' do
        expect(ai_feature_setting.set_to_gitlab_default?).to be(true)
      end
    end

    context 'when offered_model_ref is an empty string' do
      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting, offered_model_ref: '', namespace: group)
      end

      it 'returns true' do
        expect(ai_feature_setting.set_to_gitlab_default?).to be(true)
      end
    end

    context 'when offered_model_ref has a value' do
      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting, offered_model_ref: 'claude_sonnet_3_7', namespace: group)
      end

      it 'returns false' do
        expect(ai_feature_setting.set_to_gitlab_default?).to be(false)
      end
    end
  end

  describe '#pinned_model?' do
    context 'when offered_model_ref is nil' do
      subject(:pinned_model?) do
        build(:ai_namespace_feature_setting, offered_model_ref: nil, namespace: group).pinned_model?
      end

      it 'returns false' do
        expect(pinned_model?).to be(false)
      end
    end

    context 'when offered_model_ref is an empty string' do
      subject(:pinned_model?) do
        build(:ai_namespace_feature_setting, offered_model_ref: '', namespace: group).pinned_model?
      end

      it 'returns false' do
        expect(pinned_model?).to be(false)
      end
    end

    context 'when offered_model_ref has a value' do
      subject(:pinned_model?) do
        build(:ai_namespace_feature_setting, offered_model_ref: 'claude_sonnet_3_7', namespace: group).pinned_model?
      end

      it 'returns true' do
        expect(pinned_model?).to be(true)
      end
    end
  end

  describe 'validations' do
    let(:parent_group) { create(:group) }
    let(:group) { create(:group, parent: parent_group) }

    include_context 'with model selection definitions'

    describe '#validate_root_namespace' do
      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting,
          namespace: group,
          feature: valid_feature)
      end

      it 'adds an error about top-level namespaces' do
        expect(ai_feature_setting.valid?).to be false

        expect(ai_feature_setting.errors[:namespace])
          .to include('Model selection is only available for top-level namespaces.')
      end
    end

    describe '#validate_model_ref_with_definition' do
      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting,
          feature: valid_feature,
          offered_model_ref: model_ref,
          model_definitions: model_definitions,
          namespace: parent_group
        )
      end

      it_behaves_like '#validate_model_ref_with_definition is called'
    end

    describe '#set_model_name' do
      subject(:ai_feature_setting) do
        build(:ai_namespace_feature_setting,
          feature: valid_feature,
          offered_model_ref: model_ref,
          model_definitions: model_definitions,
          namespace: parent_group
        )
      end

      it_behaves_like '#set_model_name is called'
    end

    it_behaves_like 'with model allowlist' do
      let(:feature_setting) { build(:ai_namespace_feature_setting, namespace: parent_group) }
    end
  end
end
