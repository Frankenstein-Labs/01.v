# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionBudgetCaps'], feature_category: :consumables_cost_management do
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionBudgetCaps') }
  it { expect(described_class).to require_graphql_authorizations(:read_subscription_usage) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([
      :subscription_cap,
      :subscription_cap_enabled,
      :flat_user_cap,
      :flat_user_cap_enabled,
      :user_overrides
    ])
  end

  describe 'user_overrides field arguments' do
    it 'has user_ids argument' do
      expect(described_class.fields['userOverrides'].arguments['userIds'].type.to_type_signature)
        .to eq('[UserID!]')
    end
  end
end
