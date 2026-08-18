# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::CustomAndFoundationalItemType, feature_category: :workflow_catalog do
  using RSpec::Parameterized::TableSyntax

  it 'returns possible types' do
    expect(described_class.possible_types).to contain_exactly(
      ::Types::Ai::Catalog::AgentType,
      ::Types::Ai::Catalog::FlowType,
      ::Types::Ai::Catalog::ThirdPartyFlowType,
      ::Types::Ai::FoundationalChatAgentType
    )
  end

  describe '.resolve_type' do
    let(:ai_catalog_third_party_flow) { build(:ai_catalog_third_party_flow) }
    let(:ai_catalog_flow) { build(:ai_catalog_flow) }
    let(:ai_catalog_agent) { build(:ai_catalog_agent) }
    let(:foundational_chat_agent) { Ai::FoundationalChatAgent.find(1) }

    where(:item, :expected_type) do
      ref(:ai_catalog_agent)            | ::Types::Ai::Catalog::AgentType
      ref(:ai_catalog_flow)             | ::Types::Ai::Catalog::FlowType
      ref(:ai_catalog_third_party_flow) | ::Types::Ai::Catalog::ThirdPartyFlowType
      ref(:foundational_chat_agent)     | ::Types::Ai::FoundationalChatAgentType
    end

    with_them do
      it 'resolves the correct type' do
        expect(described_class.resolve_type(item, {})).to eq(expected_type)
      end
    end
  end

  it 'raises an error for invalid types' do
    item = build(:ai_catalog_item)
    allow(item).to receive(:item_type).and_return('unknown_type')
    expect { described_class.resolve_type(item, {}) }.to raise_error 'Unknown catalog item type: unknown_type'
  end
end
