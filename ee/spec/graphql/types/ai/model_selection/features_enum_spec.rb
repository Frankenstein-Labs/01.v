# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiModelSelectionFeatures'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiModelSelectionFeatures') }

  it 'exposes curated self-hosted features excepting excluded features' do
    excluded_features = [:embeddings_code, :feature_discovery_search]
    expected_features = ::Ai::ModelSelection::FeaturesConfigurable::FEATURES.keys - excluded_features
    expected_result = expected_features.map { |key| key.to_s.upcase }

    expect(described_class.values.keys).to include(*expected_result)
  end
end
