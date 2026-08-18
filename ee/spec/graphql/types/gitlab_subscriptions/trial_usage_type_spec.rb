# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabTrialUsage'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabTrialUsage') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([:active_trial, :users_usage])
  end
end
