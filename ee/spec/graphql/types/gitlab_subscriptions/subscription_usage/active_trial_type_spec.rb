# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ActiveTrial'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('ActiveTrial') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([:start_date, :end_date])
  end
end
