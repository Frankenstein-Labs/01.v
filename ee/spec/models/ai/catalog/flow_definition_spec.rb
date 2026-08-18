# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::FlowDefinition, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:flow_item, freeze: false) { create(:ai_catalog_flow) }
  let_it_be(:agent_1) { create(:ai_catalog_agent) }
  let_it_be(:agent_2) { create(:ai_catalog_agent) }
  let_it_be(:definition) do
    {
      'triggers' => [1],
      'steps' =>
      [
        { 'agent_id' => agent_1.id, 'current_version_id' => agent_1.latest_version.id, 'pinned_version_prefix' => nil },
        { 'agent_id' => agent_2.id, 'current_version_id' => agent_2.latest_version.id,
          'pinned_version_prefix' => '1.1' }
      ]
    }
  end

  let_it_be(:flow_version, freeze: false) do
    create(:ai_catalog_agent_referenced_flow_version, item: flow_item, definition: definition, version: '1.1.0')
  end

  subject(:flow_definition) { described_class.new(flow_item, flow_version) }

  describe 'inheritance' do
    it 'inherits from BaseDefinition' do
      expect(described_class.superclass).to eq(Ai::Catalog::BaseDefinition)
    end
  end

  describe '#steps' do
    it 'returns flow steps' do
      expect(flow_definition.steps).to contain_exactly(
        {
          unique_id: "#{agent_1.id}/0",
          agent: agent_1,
          current_version_id: agent_1.latest_version.id,
          pinned_version_prefix: nil,
          idx: 0
        },
        {
          unique_id: "#{agent_2.id}/1",
          agent: agent_2,
          current_version_id: agent_2.latest_version.id,
          pinned_version_prefix: '1.1',
          idx: 1
        }
      )
    end
  end
end
