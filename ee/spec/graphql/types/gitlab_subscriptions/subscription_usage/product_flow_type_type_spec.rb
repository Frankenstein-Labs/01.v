# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageProductFlowType'],
  feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageProductFlowType') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([:id, :title])
  end

  it 'defines id as a string field' do
    expect(described_class.fields['id'].type.to_type_signature).to eq('String!')
  end
end
