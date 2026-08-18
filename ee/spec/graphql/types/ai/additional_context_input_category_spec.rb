# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiAdditionalContextInput'], feature_category: :duo_chat do
  include GraphqlHelpers

  it { expect(described_class.graphql_name).to eq('AiAdditionalContextInput') }

  it 'has the expected fields' do
    expected_fields = %w[id category content metadata]

    expect(described_class.arguments.keys).to match_array(expected_fields)
  end
end
