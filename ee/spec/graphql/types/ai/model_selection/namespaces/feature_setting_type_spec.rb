# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiModelSelectionNamespaceFeatureSetting'], feature_category: :"self-hosted_models" do
  it 'has specific fields' do
    expected_fields =
      %w[feature title mainFeature namespace selectedModel defaultModel selectableModels allowList]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
