# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiModelSelectionOfferedModel'], feature_category: :"self-hosted_models" do
  it 'has specific fields' do
    expected_fields = %w[ref name model_provider model_description cost_indicator]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
