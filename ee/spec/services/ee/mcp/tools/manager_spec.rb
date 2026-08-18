# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Manager, feature_category: :ai_agents do
  let(:api_double) { class_double(API::API) }
  let(:mock_tool_handler) { Class.new { def initialize(...); end } }

  before do
    custom_tools = {
      'get_mcp_server_version' => mock_tool_handler
    }
    ee_custom_tools = {
      'get_ee_mcp_server_version' => mock_tool_handler
    }
    stub_const("#{described_class}::CUSTOM_TOOLS", custom_tools)
    stub_const("::EE::#{described_class}::EE_CUSTOM_TOOLS", ee_custom_tools)

    # Stub the GRAPHQL_TOOLS with GraphQL tools
    graphql_tools = {
      'create_workitem_note' => mock_tool_handler
    }
    ee_graphql_tools = {
      'ee_create_workitem_note' => mock_tool_handler
    }
    stub_const("#{described_class}::GRAPHQL_TOOLS", graphql_tools)
    stub_const("::EE::#{described_class}::EE_GRAPHQL_TOOLS", ee_graphql_tools)
  end

  describe '#initialize' do
    let(:routes) { [] }

    before do
      stub_const('API::API', api_double)
      allow(api_double).to receive(:reset_routes!)
      allow(api_double).to receive(:routes).and_return(routes)
    end

    context 'with no API routes' do
      it 'initializes with custom and graphql tools' do
        manager = described_class.new

        expect(manager.tools.keys).to contain_exactly(
          'get_mcp_server_version',
          'get_ee_mcp_server_version',
          'create_workitem_note',
          'ee_create_workitem_note'
        )
      end
    end
  end
end
