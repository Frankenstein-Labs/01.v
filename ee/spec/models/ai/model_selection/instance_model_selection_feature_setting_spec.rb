# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ModelSelection::InstanceModelSelectionFeatureSetting, feature_category: :ai_abstraction_layer do
  subject(:instance_feature_setting) do
    build(:instance_model_selection_feature_setting)
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:feature) }

    it 'validates uniqueness of feature' do
      create(:instance_model_selection_feature_setting, feature: :code_generations)
      duplicate_setting = build(:instance_model_selection_feature_setting, feature: :code_generations)

      expect(duplicate_setting).not_to be_valid
      expect(duplicate_setting.errors[:feature]).to include('has already been taken')
    end

    it_behaves_like 'with model allowlist' do
      let(:feature_setting) { instance_feature_setting }
    end
  end

  describe 'table_name' do
    it 'uses the correct table name' do
      expect(described_class.table_name).to eq('instance_model_selection_feature_settings')
    end
  end

  describe 'scopes' do
    describe '.non_default' do
      let!(:default_setting) { create(:instance_model_selection_feature_setting, :gitlab_default) }
      let!(:custom_setting) do
        create(:instance_model_selection_feature_setting, :with_custom_model, feature: :code_completions)
      end

      let!(:empty_ref_setting) { create(:instance_model_selection_feature_setting, :empty_ref, feature: :duo_chat) }

      it 'returns only settings with non-blank offered_model_ref' do
        expect(described_class.non_default).to contain_exactly(custom_setting)
      end
    end
  end

  describe '.find_or_initialize_by_feature' do
    let(:existing_feature) { instance_feature_setting.feature.to_sym }

    context 'when setting exists' do
      it 'returns the existing setting' do
        instance_feature_setting.save!
        result = described_class.find_or_initialize_by_feature(existing_feature)
        expect(result).to eq(instance_feature_setting)
        expect(result).to be_persisted
      end
    end

    context 'when setting does not exist' do
      it 'returns a new initialized setting' do
        result = described_class.find_or_initialize_by_feature(:duo_chat)
        expect(result).to be_a(described_class)
        expect(result).not_to be_persisted
        expect(result.feature).to eq('duo_chat')
      end
    end

    context 'for duo chat tools' do
      it 'returns the duo chat feature setting for all duo chat tools' do
        described_class::DUO_CHAT_TOOLS.each do |feature_sym|
          result = described_class.find_or_initialize_by_feature(feature_sym)
          expect(result.feature).to eq('duo_chat')
        end
      end
    end
  end

  describe '#build_with_offered_model_ref' do
    let(:instance_feature_setting) do
      build(:instance_model_selection_feature_setting, feature: :duo_chat, offered_model_ref: 'original_ref')
    end

    subject(:record) { instance_feature_setting.build_with_offered_model_ref('selected_ref') }

    it 'builds a new unpersisted record for the same feature with the given offered model ref',
      :aggregate_failures do
      expect(record).to be_a(described_class)
      expect(record).not_to be_persisted
      expect(record.feature).to eq('duo_chat')
      expect(record.offered_model_ref).to eq('selected_ref')
    end
  end

  describe "#base_url" do
    it "returns cloud connector url" do
      expect(instance_feature_setting.base_url).to eq(::Gitlab::AiGateway.cloud_connector_url)
    end
  end

  describe '#vendored?' do
    it 'returns true' do
      expect(instance_feature_setting.vendored?).to be(true)
    end
  end

  describe '#set_to_gitlab_default?' do
    context 'when offered_model_ref is nil' do
      subject(:instance_feature_setting) do
        build(:instance_model_selection_feature_setting, offered_model_ref: nil)
      end

      it 'returns true' do
        expect(instance_feature_setting.set_to_gitlab_default?).to be true
      end
    end

    context 'when offered_model_ref is empty string' do
      subject(:instance_feature_setting) do
        build(:instance_model_selection_feature_setting, offered_model_ref: "")
      end

      it 'returns true' do
        expect(instance_feature_setting.set_to_gitlab_default?).to be true
      end
    end

    context 'when offered_model_ref has a value' do
      subject(:instance_feature_setting) do
        build(:instance_model_selection_feature_setting, offered_model_ref: "claude-3-7-sonnet-20250219")
      end

      it 'returns false' do
        expect(instance_feature_setting.set_to_gitlab_default?).to be false
      end
    end
  end

  describe '#pinned_model?' do
    context 'when offered_model_ref is nil' do
      subject(:pinned_model?) do
        build(:instance_model_selection_feature_setting, offered_model_ref: nil).pinned_model?
      end

      it 'returns false' do
        expect(pinned_model?).to be false
      end
    end

    context 'when offered_model_ref is empty string' do
      subject(:pinned_model?) do
        build(:instance_model_selection_feature_setting, offered_model_ref: "").pinned_model?
      end

      it 'returns false' do
        expect(pinned_model?).to be false
      end
    end

    context 'when offered_model_ref has a value' do
      subject(:pinned_model?) do
        build(:instance_model_selection_feature_setting, offered_model_ref: "claude-3-7-sonnet-20250219").pinned_model?
      end

      it 'returns true' do
        expect(pinned_model?).to be true
      end
    end
  end

  describe 'feature enum' do
    it 'includes all expected features from FEATURES constant' do
      expected_features = described_class::FEATURES.keys.map(&:to_s)
      expect(described_class.features.keys).to match_array(expected_features)
    end
  end

  describe 'when ::Ai::FeatureConfigurable is included' do
    context 'with request model info' do
      let(:feature_setting) { create(:instance_model_selection_feature_setting) }
      let(:expected_params_for_request) { expected_params_for_metadata }

      context 'when model info should be resolved' do
        let(:expected_params_for_metadata) do
          {
            feature_setting: "code_generations",
            identifier: "claude-3-7-sonnet-20250219",
            provider: "gitlab"
          }
        end

        it 'returns correct model metadata params' do
          expect(feature_setting.model_metadata_params).to eq(expected_params_for_metadata)
        end

        it 'returns correct model request params' do
          expect(feature_setting.model_request_params).to eq(expected_params_for_request)
        end
      end

      context 'when the feature setting is default' do
        let(:feature_setting) { create(:instance_model_selection_feature_setting, offered_model_ref: nil) }
        let(:expected_params_for_metadata) do
          {
            feature_setting: "code_generations",
            identifier: nil,
            provider: "gitlab"
          }
        end

        it 'returns correct model metadata params for default setting' do
          expect(feature_setting.model_metadata_params).to eq(expected_params_for_metadata)
        end
      end
    end
  end
end
