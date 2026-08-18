# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::MergeTrains::TrainType, feature_category: :merge_trains do
  include GraphqlHelpers

  specify { expect(described_class).to require_graphql_authorizations(:read_merge_train) }

  it 'has the expected fields' do
    expected_fields = %w[
      target_branch cars
    ]

    expect(described_class).to have_graphql_fields(*expected_fields).only
  end
end
