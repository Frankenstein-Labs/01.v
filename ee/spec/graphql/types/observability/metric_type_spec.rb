# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Observability::MetricType, feature_category: :observability do
  include GraphqlHelpers

  specify { expect(described_class).to require_graphql_authorizations(:read_observability) }

  it 'has the expected fields' do
    expected_fields = %w[
      name
      type
      issue
    ]

    expect(described_class).to have_graphql_fields(*expected_fields).at_least
  end
end
