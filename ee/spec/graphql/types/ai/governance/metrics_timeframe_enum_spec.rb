# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Governance::MetricsTimeframeEnum, feature_category: :compliance_management do
  specify { expect(described_class.graphql_name).to eq('AiGovernanceMetricsTimeframe') }

  it 'exposes the expected values' do
    expect(described_class.values).to match(
      'LAST_24_HOURS' => have_attributes(value: :last_24_hours),
      'LAST_7_DAYS' => have_attributes(value: :last_7_days),
      'LAST_30_DAYS' => have_attributes(value: :last_30_days)
    )
  end
end
