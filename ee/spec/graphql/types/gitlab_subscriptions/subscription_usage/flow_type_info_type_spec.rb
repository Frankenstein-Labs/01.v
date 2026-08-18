# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GitlabSubscriptionUsageFlowTypeInfo'], feature_category: :consumables_cost_management do
  include GraphqlHelpers
  it { expect(described_class.graphql_name).to eq('GitlabSubscriptionUsageFlowTypeInfo') }
  it { expect(described_class).to require_graphql_authorizations(:read_user) }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields([:id, :title])
  end

  describe '#id' do
    it 'returns the flow type id instead of a global id' do
      user = build(:user)
      flow_type_info = Types::GitlabSubscriptions::SubscriptionUsage::UserType::FlowTypeInfo.new(
        'agentic_chat', 'Agentic Chat', user
      )

      expect(resolve_field(:id, flow_type_info, current_user: user)).to eq('agentic_chat')
    end
  end
end
