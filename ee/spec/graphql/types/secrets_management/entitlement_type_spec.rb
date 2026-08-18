# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['SecretsManagerEntitlement'], feature_category: :secrets_management do
  let(:expected_fields) do
    %i[
      state
      blocked_reason
      trial_started_at
      trial_expires_at
      credits_remaining
      credits_total
      on_demand_enabled
    ]
  end

  specify do
    expect(described_class.graphql_name).to eq('SecretsManagerEntitlement')
    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  it 'requires a non-null state' do
    expect(described_class.fields['state'].type.to_type_signature).to eq('SecretsManagerEntitlementState!')
  end

  it 'exposes blockedReason as nullable' do
    signature = described_class.fields['blockedReason'].type.to_type_signature
    expect(signature).to eq('SecretsManagerEntitlementBlockedReason')
  end
end
