# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::Namespaces::FeatureSettingFinder, feature_category: :"self-hosted_models" do
  let_it_be(:root_group) { create(:group) }

  let_it_be(:feature_settings) do
    [
      create(:ai_namespace_feature_setting, feature: :code_completions, namespace: root_group),
      create(:ai_namespace_feature_setting, feature: :code_generations, namespace: root_group)
    ]
  end

  let_it_be(:test_ai_feature_enum) do
    {
      code_generations: 0,
      code_completions: 1,
      duo_chat: 2
    }
  end

  let(:group) { root_group }

  subject(:execute_finder) { described_class.new(group: group).execute }

  before do
    stub_const('::Ai::ModelSelection::FeaturesConfigurable::FEATURES', test_ai_feature_enum)
  end

  describe '#execute' do
    it 'calls ::Ai::ModelSelection::NamespaceFeatureSetting.enabled_features_for' do
      expect(::Ai::ModelSelection::NamespaceFeatureSetting).to(
        receive(:enabled_features_for)
          .with(group)
          .and_call_original
      )

      execute_finder
    end

    context 'when group is nil' do
      let(:group) { nil }

      it 'returns an empty array' do
        expect(execute_finder.to_a).to be_empty
      end
    end

    context 'when group is not a root group' do
      let(:group) { create(:group, parent: root_group) }

      it 'returns an empty array' do
        expect(execute_finder.to_a).to be_empty
      end
    end

    context 'when group is a root group' do
      context 'when feature settings exist for the group' do
        let(:existing_features) { %w[code_completions code_generations] }

        it 'returns the existing feature settings' do
          expect(execute_finder).to include(*feature_settings)
        end

        it 'returns all feature settings defined in FEATURES' do
          expect(execute_finder.size).to eq(3)
          expect(execute_finder.map(&:feature)).to match_array(%w[code_completions code_generations duo_chat])
        end

        it 'builds new feature settings for features without existing settings' do
          result = execute_finder
          new_setting = result.find { |s| s.feature == 'duo_chat' }

          expect(new_setting).to be_a(Ai::ModelSelection::NamespaceFeatureSetting)
          expect(new_setting).to be_new_record
          expect(new_setting.namespace).to eq(root_group)
        end

        it 'finds existing feature settings' do
          result = execute_finder
          existing_settings = result.select { |s| existing_features.include?(s.feature) }

          expect(existing_settings.map(&:id)).to match_array(feature_settings.map(&:id))
        end
      end
    end
  end
end
