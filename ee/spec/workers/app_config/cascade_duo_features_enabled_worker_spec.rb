# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AppConfig::CascadeDuoFeaturesEnabledWorker, type: :worker, feature_category: :ai_abstraction_layer do
  let(:duo_features_enabled) { true }

  subject(:worker) { described_class.new }

  describe '#perform' do
    it 'calls cascade_for_instance on service with the correct argument' do
      expect_next_instance_of(Ai::CascadeDuoSettingsService,
        { duo_features_enabled: duo_features_enabled }) do |service|
        expect(service).to receive(:cascade_for_instance)
      end

      worker.perform(duo_features_enabled)
    end
  end
end
