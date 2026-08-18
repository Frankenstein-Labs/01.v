# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiModelSelectionAllowListModel'], feature_category: :"self-hosted_models" do
  it 'exposes the expected fields' do
    expected_fields = %w[
      ref
      name
      model_provider
      model_description
      cost_indicator
      allowed
      currently_chosen_model_for_feature
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
