# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Governance::KpiTrendPointType, feature_category: :compliance_management do
  specify { expect(described_class.graphql_name).to eq('AiGovernanceKpiTrendPoint') }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:bucket_start, :count)
  end
end
