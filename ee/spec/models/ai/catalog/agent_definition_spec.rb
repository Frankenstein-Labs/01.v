# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::AgentDefinition, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:agent_item, freeze: false) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:tool_ids) { [1, 2, 5] }
  let_it_be(:definition) do
    {
      'system_prompt' => 'Talk like a pirate!',
      'tools' => tool_ids,
      'user_prompt' => 'What is a leap year?'
    }
  end

  let_it_be(:agent_version, freeze: false) do
    create(:ai_catalog_agent_version, item: agent_item, definition: definition, version: '1.1.0')
  end

  subject(:agent_definition) { described_class.new(agent_item, agent_version) }

  describe 'inheritance' do
    it 'inherits from BaseDefinition' do
      expect(described_class.superclass).to eq(Ai::Catalog::BaseDefinition)
    end
  end

  describe '#tool_names' do
    context 'when tools are specified in the definition' do
      it 'returns the tool names for the specified tool IDs' do
        expected_tools = Ai::Catalog::BuiltInTool.where(id: tool_ids)
        expected_names = expected_tools.map(&:name)

        expect(agent_definition.tool_names).to match_array(expected_names)
      end
    end
  end

  describe '#system_prompt' do
    it 'returns the system prompt from the version' do
      expect(agent_definition.system_prompt).to eq(agent_version.def_system_prompt)
    end
  end

  describe '#user_prompt' do
    it 'returns the user prompt from the version' do
      expect(agent_definition.user_prompt).to eq(agent_version.def_user_prompt)
    end
  end
end
