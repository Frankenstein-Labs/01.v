# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiModelSelectionAllowList'], feature_category: :"self-hosted_models" do
  it 'exposes the expected fields' do
    expected_fields = %w[enabled models]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
