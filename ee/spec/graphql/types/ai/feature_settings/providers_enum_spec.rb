# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiFeatureProviders'], feature_category: :"self-hosted_models" do
  it { expect(described_class.graphql_name).to eq('AiFeatureProviders') }

  it 'exposes all the curated self-hosted feature providers' do
    expected_result = ::Ai::FeatureSetting.providers.each_key.map { |key| key.to_s.upcase }

    expect(described_class.values.keys).to include(*expected_result)
  end
end
