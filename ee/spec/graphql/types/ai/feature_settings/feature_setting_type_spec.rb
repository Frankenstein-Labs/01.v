# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiFeatureSetting'], feature_category: :"self-hosted_models" do
  it 'has specific fields' do
    expected_fields = %w[feature provider title mainFeature compatibleLlms releaseState selfHostedModel validModels
      gitlabModel defaultGitlabModel validGitlabModels allowList]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
