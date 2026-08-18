# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiFeatures'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiFeatures') }

  it 'exposes curated self-hosted features excepting excluded features' do
    excluded_features = [:embeddings_code]
    expected_features = ::Ai::FeatureSetting.allowed_features.keys - excluded_features
    expected_result = expected_features.map { |key| key.to_s.upcase }

    expect(described_class.values.keys).to include(*expected_result)
  end
end
