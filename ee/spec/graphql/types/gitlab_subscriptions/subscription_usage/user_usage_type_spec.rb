# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageUserUsage'],
  feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageUserUsage') }
  it { expect(described_class).to require_graphql_authorizations(:read_user) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([
      :credits_used,
      :monthly_waiver_credits_used,
      :overage_credits_used,
      :monthly_commitment_credits_used,
      :paid_tier_trial_credits_used,
      :total_credits,
      :total_credits_used
    ])
  end
end
