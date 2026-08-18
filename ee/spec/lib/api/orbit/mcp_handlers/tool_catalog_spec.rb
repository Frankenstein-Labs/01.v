# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Orbit::McpHandlers::ToolCatalog, feature_category: :knowledge_graph do
  describe 'COMMAND_TOOL_NAMES' do
    it 'contains only the command wrapper tools' do
      expect(described_class::COMMAND_TOOL_NAMES).to match_array(%w[list_commands invoke_command])
    end
  end

  describe '.trusted_tool?' do
    it 'returns true for command tool names' do
      expect(described_class.trusted_tool?('list_commands')).to be(true)
      expect(described_class.trusted_tool?('invoke_command')).to be(true)
    end

    it 'returns false for legacy tool names' do
      expect(described_class.trusted_tool?('query_graph')).to be(false)
      expect(described_class.trusted_tool?('get_graph_schema')).to be(false)
    end

    it 'returns false for unknown tool names' do
      expect(described_class.trusted_tool?('nonexistent')).to be(false)
    end
  end
end
