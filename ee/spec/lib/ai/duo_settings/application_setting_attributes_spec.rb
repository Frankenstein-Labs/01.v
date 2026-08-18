# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoSettings::ApplicationSettingAttributes, feature_category: :ai_abstraction_layer do
  describe '.duo_related?' do
    it 'returns true for a column based setting' do
      expect(described_class.duo_related?(:duo_features_enabled)).to be true
    end

    it 'returns true for a jsonb sub-key setting' do
      expect(described_class.duo_related?(:duo_custom_agents_enabled)).to be true
    end

    it 'returns false for a non-Duo setting' do
      expect(described_class.duo_related?(:default_project_visibility)).to be false
    end

    it 'works with a string' do
      expect(described_class.duo_related?('duo_custom_agents_enabled')).to be true
    end

    it 'returns false for nil' do
      expect(described_class.duo_related?(nil)).to be false
    end
  end

  describe 'DUO_RELATED_ATTRIBUTES drift guard' do
    it 'labels every attribute stored in the Duo jsonb columns' do
      # jsonb_store_key_mapping_for_<column> is the jsonb_accessor gem's canonical mapping of the AR
      # attributes stored in each jsonb column. Its keys are the only sub-keys that are dirty-tracked
      # and can therefore fire an audit event, so every one must be labeled. Adding a new
      # jsonb_accessor sub-key fails this spec until it is added to DUO_RELATED_ATTRIBUTES.
      # Schema-only keys with no accessor never surface here (they cannot be audited).
      %w[duo_settings duo_chat duo_workflow code_creation].each do |column|
        stored_attributes = ::ApplicationSetting.public_send(:"jsonb_store_key_mapping_for_#{column}").keys
        unlabeled = stored_attributes - described_class::DUO_RELATED_ATTRIBUTES.to_a

        expect(unlabeled).to be_empty,
          "#{column} has unlabeled attributes: #{unlabeled.inspect}. Add them to DUO_RELATED_ATTRIBUTES."
      end
    end

    it 'only lists real ApplicationSetting attributes' do
      expect(::ApplicationSetting.attribute_names)
        .to include(*described_class::DUO_RELATED_ATTRIBUTES.to_a)
    end
  end
end
