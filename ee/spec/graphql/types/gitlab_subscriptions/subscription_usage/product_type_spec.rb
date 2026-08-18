# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageProduct'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageProduct') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([:id, :title, :credits_used, :flow_types])
  end

  it 'defines id as a string field' do
    expect(described_class.fields['id'].type.to_type_signature).to eq('String!')
  end

  it 'defines flow_types as non-null list' do
    field = described_class.fields['flowTypes']

    expect(field.type.non_null?).to be(true)
  end
end
