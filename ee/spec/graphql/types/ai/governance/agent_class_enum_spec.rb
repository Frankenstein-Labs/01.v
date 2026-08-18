# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Governance::AgentClassEnum, feature_category: :compliance_management do
  specify { expect(described_class.graphql_name).to eq('AiGovernanceAgentClass') }

  it 'exposes the expected values' do
    expect(described_class.values).to match(
      'ALL' => have_attributes(value: :all),
      'INTERNAL_DAP' => have_attributes(value: :internal_dap),
      'EXTERNAL' => have_attributes(value: :external)
    )
  end
end
