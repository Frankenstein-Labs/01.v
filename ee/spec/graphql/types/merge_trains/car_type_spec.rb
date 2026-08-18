# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::MergeTrains::CarType, feature_category: :merge_trains do
  include GraphqlHelpers

  specify { expect(described_class).to require_graphql_authorizations(:read_merge_train_car) }

  it 'has the expected fields' do
    expected_fields = %w[
      id index merge_request user pipeline
      created_at updated_at target_project
      target_branch status merged_at duration
    ]

    expect(described_class).to have_graphql_fields(*expected_fields).at_least
  end
end
