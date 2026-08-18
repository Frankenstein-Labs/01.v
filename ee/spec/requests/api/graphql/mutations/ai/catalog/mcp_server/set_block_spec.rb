# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::McpServer::SetBlock, :with_current_organization,
  feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:user) { create(:user, owner_of: current_organization) }
  let_it_be_with_reload(:group) { create(:group, organization: current_organization) }
  let_it_be_with_reload(:subgroup) { create(:group, parent: group, organization: current_organization) }
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, organization: current_organization) }

  let(:current_user) { user }
  let(:blocked) { true }
  let(:full_path) { group.full_path }

  let(:mutation) do
    graphql_mutation(:ai_catalog_mcp_server_set_block, {
      id: mcp_server.to_global_id.to_s,
      group_full_path: full_path,
      blocked: blocked
    }) do
      <<~FIELDS
        errors
        mcpServer {
          id
          blockStatus(groupFullPath: "#{full_path}")
        }
      FIELDS
    end
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before_all do
    group.add_owner(user)
    subgroup.add_owner(user)
  end

  before do
    allow(::Ai::Catalog).to receive(:mcp_servers_available?).and_return(true)
    group.namespace_settings.update!(duo_features_enabled: true)
  end

  context 'when blocking' do
    it 'creates a block record and reports BLOCKED', :aggregate_failures do
      expect { execute }.to change { Ai::Catalog::McpServerBlock.count }.by(1)

      expect(graphql_data_at(:ai_catalog_mcp_server_set_block, :errors)).to be_empty
      expect(graphql_data_at(:ai_catalog_mcp_server_set_block, :mcp_server, :blockStatus)).to eq('BLOCKED')
    end
  end

  context 'when allowing an existing block' do
    let(:blocked) { false }

    before do
      create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: mcp_server, organization: current_organization)
    end

    it 'removes the block record and reports ACTIVE', :aggregate_failures do
      expect { execute }.to change { Ai::Catalog::McpServerBlock.count }.by(-1)

      expect(graphql_data_at(:ai_catalog_mcp_server_set_block, :mcp_server, :blockStatus)).to eq('ACTIVE')
    end
  end

  context 'when resolving status for a subgroup blocked by its ancestor' do
    let(:full_path) { subgroup.full_path }
    # Allowing on the subgroup is a no-op (no own record); status stays inherited-blocked.
    let(:blocked) { false }

    before do
      subgroup.namespace_settings.update!(duo_features_enabled: true)
      create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: mcp_server, organization: current_organization)
    end

    it 'reports BLOCKED_BY_ANCESTOR' do
      execute

      expect(graphql_data_at(:ai_catalog_mcp_server_set_block, :mcp_server, :blockStatus))
        .to eq('BLOCKED_BY_ANCESTOR')
    end
  end

  context 'when the user can read the group but cannot block' do
    # Organization member who can read the server and the group, but is not an owner/maintainer, so
    # the block is denied by the service (they already know the group exists, so this is a permission
    # error rather than a generic not-found).
    let(:current_user) { create(:organization_user, organization: current_organization).user }

    it 'returns an authorization error and does not create a record', :aggregate_failures do
      expect { execute }.not_to change { Ai::Catalog::McpServerBlock.count }

      expect(graphql_data_at(:ai_catalog_mcp_server_set_block, :errors))
        .to include('You have insufficient permissions')
    end
  end

  context 'when both group and project paths are provided' do
    let_it_be(:project) { create(:project, group: group, organization: current_organization) }

    let(:mutation) do
      graphql_mutation(:ai_catalog_mcp_server_set_block, {
        id: mcp_server.to_global_id.to_s,
        group_full_path: group.full_path,
        project_full_path: project.full_path,
        blocked: blocked
      }, 'errors')
    end

    it 'returns an argument error and does not create a record', :aggregate_failures do
      expect { execute }.not_to change { Ai::Catalog::McpServerBlock.count }
      expect_graphql_errors_to_include('Provide exactly one of groupFullPath or projectFullPath.')
    end
  end

  context 'when neither group nor project path is provided' do
    let(:mutation) do
      graphql_mutation(:ai_catalog_mcp_server_set_block, {
        id: mcp_server.to_global_id.to_s,
        blocked: blocked
      }, 'errors')
    end

    it 'returns an argument error and does not create a record', :aggregate_failures do
      expect { execute }.not_to change { Ai::Catalog::McpServerBlock.count }
      expect_graphql_errors_to_include('Provide exactly one of groupFullPath or projectFullPath.')
    end
  end

  context 'with a project target' do
    let_it_be_with_reload(:project) { create(:project, group: group, organization: current_organization) }

    let(:mutation) do
      graphql_mutation(:ai_catalog_mcp_server_set_block, {
        id: mcp_server.to_global_id.to_s,
        project_full_path: project.full_path,
        blocked: blocked
      }) do
        <<~FIELDS
          errors
          mcpServer {
            id
            blockStatus(projectFullPath: "#{project.full_path}")
          }
        FIELDS
      end
    end

    before do
      project.project_setting.update!(duo_features_enabled: true)
    end

    it 'blocks for the project and stores the block against the project namespace', :aggregate_failures do
      expect { execute }.to change { Ai::Catalog::McpServerBlock.count }.by(1)

      expect(graphql_data_at(:ai_catalog_mcp_server_set_block, :errors)).to be_empty
      expect(graphql_data_at(:ai_catalog_mcp_server_set_block, :mcp_server, :blockStatus)).to eq('BLOCKED')
      expect(
        Ai::Catalog::McpServerBlock.find_by(
          namespace_id: project.project_namespace_id, ai_catalog_mcp_server_id: mcp_server.id
        )
      ).to be_present
    end

    context 'when the parent group has blocked the server' do
      let(:blocked) { false }

      before do
        create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: mcp_server,
          organization: current_organization)
      end

      it 'reports BLOCKED_BY_ANCESTOR for the project' do
        execute

        expect(graphql_data_at(:ai_catalog_mcp_server_set_block, :mcp_server, :blockStatus))
          .to eq('BLOCKED_BY_ANCESTOR')
      end
    end
  end

  describe 'granular token authorization' do
    let_it_be_with_reload(:project) { create(:project, group: group, organization: current_organization) }

    before do
      project.project_setting.update!(duo_features_enabled: true)
    end

    # One test per boundary declared on the mutation's `authorize_granular_token` (group and project).
    it_behaves_like 'authorizing granular token permissions for GraphQL', :block_ai_catalog_mcp_server do
      let(:boundary_object) { group }
      let(:mutation) do
        graphql_mutation(:ai_catalog_mcp_server_set_block,
          { id: mcp_server.to_global_id.to_s, group_full_path: group.full_path, blocked: true }, 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :block_ai_catalog_mcp_server do
      let(:boundary_object) { project }
      let(:mutation) do
        graphql_mutation(:ai_catalog_mcp_server_set_block,
          { id: mcp_server.to_global_id.to_s, project_full_path: project.full_path, blocked: true }, 'errors')
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
