# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionHistory'], feature_category: :seat_cost_management do
  include GraphqlHelpers

  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionHistory') }
  it { expect(described_class).to require_graphql_authorizations(:read_billing) }

  it 'has expected fields' do
    expected_fields = %w[created_at start_date end_date seats seats_in_use max_seats_used change_type]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
