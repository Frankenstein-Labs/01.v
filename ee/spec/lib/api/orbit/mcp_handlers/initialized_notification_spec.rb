# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Orbit::McpHandlers::InitializedNotification, feature_category: :knowledge_graph do
  let_it_be(:user) { create(:user) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp_orbit]) }

  describe '#invoke' do
    it 'returns nil' do
      handler = described_class.new({}, access_token, user,
        request_context: Analytics::KnowledgeGraph::RequestContext.new(
          source_type: Analytics::KnowledgeGraph::SourceType::MCP))

      expect(handler.invoke).to be_nil
    end
  end
end
