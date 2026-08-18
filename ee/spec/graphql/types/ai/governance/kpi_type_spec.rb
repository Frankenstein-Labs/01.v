# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Governance::KpiType, feature_category: :compliance_management do
  specify { expect(described_class.graphql_name).to eq('AiGovernanceKpi') }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:count, :previous_count, :trend)
  end
end
