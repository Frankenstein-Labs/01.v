# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ToolRules::Permissions, feature_category: :ai_agents do
  it 'pins the permission value strings shared across the model, resolution, and GraphQL layers' do
    expect(described_class::ALLOW).to eq('allow')
    expect(described_class::ASK).to eq('ask')
    expect(described_class::DENY).to eq('deny')
  end

  describe '.background_effective' do
    it 'coerces ask to allow (no approver on a background flow)' do
      expect(described_class.background_effective(described_class::ASK)).to eq(described_class::ALLOW)
      expect(described_class.background_effective(:ask)).to eq(described_class::ALLOW)
    end

    it 'returns allow and deny unchanged' do
      expect(described_class.background_effective(described_class::ALLOW)).to eq(described_class::ALLOW)
      expect(described_class.background_effective(described_class::DENY)).to eq(described_class::DENY)
    end
  end

  it 'matches the ToolRule enum labels and integer mapping' do
    expected = { described_class::ALLOW => 0, described_class::ASK => 1, described_class::DENY => 2 }

    expect(::Ai::ToolRule.web_accesses).to eq(expected)
    expect(::Ai::ToolRule.local_accesses).to eq(expected)
  end

  it 'matches the GraphQL ToolPermissionEnum wire values' do
    wire_values = ::Types::Ai::ToolPermissionEnum.values.transform_values(&:value)

    expect(wire_values).to eq(
      'ALLOW' => described_class::ALLOW,
      'ASK' => described_class::ASK,
      'DENY' => described_class::DENY
    )
  end
end
