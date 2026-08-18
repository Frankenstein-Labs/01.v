# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionPaidTierTrial'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionPaidTierTrial') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([:is_active, :daily_usage])
  end
end
