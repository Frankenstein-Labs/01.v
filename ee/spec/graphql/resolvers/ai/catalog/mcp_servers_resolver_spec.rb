# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Catalog::McpServersResolver, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, organization: organization) }

  let(:current_user) { user }
  let(:context) { { current_user: current_user, current_organization: organization } }

  subject(:resolve_servers) { resolve(described_class, obj: nil, ctx: context) }

  it 'returns a non-null connection type' do
    expect(described_class.type.of_type).to eq(Types::Ai::Catalog::McpServerType.connection_type)
  end

  context 'when user has permission' do
    before do
      allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
    end

    it 'returns MCP servers for the organization' do
      expect(resolve_servers).to contain_exactly(mcp_server)
    end
  end

  context 'when user does not have permission' do
    before do
      allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(false)
    end

    it 'returns an empty result' do
      expect(resolve_servers).to be_empty
    end
  end

  context 'when organization context is missing' do
    let(:context) { { current_user: current_user, current_organization: nil } }

    it 'returns an empty result' do
      expect(resolve_servers).to be_empty
    end
  end
end
