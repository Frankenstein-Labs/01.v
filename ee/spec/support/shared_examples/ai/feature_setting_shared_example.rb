# frozen_string_literal: true

RSpec.shared_examples '#metadata is defined for AI configurable features' do
  before do
    allow(::Ai::FeatureConfigurable::FEATURE_METADATA)
      .to receive(:[]).with(feature_setting.feature.to_s)
                      .and_return(feature_metadata)
  end

  context 'when feature metadata exists' do
    let(:feature_metadata) do
      { 'title' => 'Duo Chat', 'main_feature' => 'duo_chat', 'compatible_llms' => ['codellama'],
        'release_state' => 'BETA' }
    end

    it 'returns a FeatureMetadata object with correct attributes' do
      metadata = feature_setting.metadata

      expect(metadata).to be_an_instance_of(Ai::FeatureSetting::FeatureMetadata)
      expect(metadata.title).to eq('Duo Chat')
      expect(metadata.main_feature).to eq('duo_chat')
      expect(metadata.compatible_llms).to eq(['codellama'])
      expect(metadata.release_state).to eq('BETA')
    end
  end

  context 'when feature metadata does not exist' do
    let(:feature_metadata) { nil }

    it 'returns a FeatureMetadata object with nil attributes' do
      metadata = feature_setting.metadata

      expect(metadata).to be_an_instance_of(Ai::FeatureSetting::FeatureMetadata)
      expect(metadata.title).to be_nil
      expect(metadata.main_feature).to be_nil
      expect(metadata.compatible_llms).to be_nil
      expect(metadata.release_state).to be_nil
    end
  end
end

RSpec.shared_examples 'configurable AI features resolves model info correctly' do
  it 'returns the right values for #model_metadata_params' do
    expect(feature_setting.model_metadata_params).to eq(expected_params_for_metadata)
  end

  it 'returns the right values for #model_request_params' do
    expect(feature_setting.model_request_params).to eq(expected_params_for_request)
  end
end
