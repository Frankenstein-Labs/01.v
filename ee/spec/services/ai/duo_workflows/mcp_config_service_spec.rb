# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::McpConfigService, feature_category: :duo_agent_platform do
  let_it_be(:organization) { create(:organization) }
  let_it_be_with_reload(:user) { create(:user, organizations: [organization]) }
  let(:gitlab_token) { 'test_gitlab_token_12345' }
  let(:workflow_definition) { 'chat' }
  let(:ai_catalog_item_version_id) { nil }
  let(:built_in_tool_ids) { [] }
  let(:mcp_tools) { [] }

  let(:read_only_tool_names) do
    %w[
      get_issue get_job_log get_mcp_server_version
      get_merge_request get_merge_request_commits get_merge_request_conflicts
      get_merge_request_diffs get_merge_request_notes get_merge_request_pipelines
      get_pipeline get_pipeline_jobs get_saved_view_work_items get_work_item_types
      get_workitem_notes list_duo_sessions list_merge_requests list_pipelines search search_labels
      semantic_code_search list_wiki_pages get_repository_file
    ]
  end

  let(:read_only_alias_names) { %w[gitlab_search gitlab_merge_request_search] }

  before do
    # Orbit availability now also requires the Knowledge Graph service to be
    # configured on the instance (via Ai::Orbit::Settings.platform_available?
    # -> Analytics::KnowledgeGraph.enabled_for?), which does not default on in
    # the test suite. Stub it so the default-available assumption holds.
    stub_config(knowledge_graph: { 'enabled' => true })

    ::API::API.reset_routes!

    item_version = double('Ai::Catalog::ItemVersion', def_tools: built_in_tool_ids, def_mcp_tools: mcp_tools) # rubocop:disable RSpec/VerifiedDoubles -- def_tools/def_mcp_tools are method_missing accessors on ItemVersion
    allow(service).to receive(:item_version).and_return(item_version)
  end

  subject(:service) do
    described_class.new(
      user,
      gitlab_token,
      workflow_definition: workflow_definition,
      ai_catalog_item_version_id: ai_catalog_item_version_id
    )
  end

  describe '#execute' do
    context 'with default chat (no catalog agent)' do
      it 'returns configuration hash with gitlab server' do
        result = service.execute

        expect(result).to be_a(Hash)
        expect(result).to have_key(:gitlab)
      end

      it 'omits the Tools key to allow all MCP server tools' do
        result = service.execute

        expect(result[:gitlab]).not_to have_key(:Tools)
      end

      it 'includes default preapproved tools derived from readOnlyHint annotations' do
        result = service.execute

        # Read-only aliases are pre-approved too: a client may call either name.
        expect(result[:gitlab][:PreApprovedTools]).to match_array(read_only_tool_names + read_only_alias_names)
      end

      it 'includes proper authorization header with token' do
        result = service.execute

        expect(result[:gitlab][:Headers][:Authorization]).to eq("Bearer #{gitlab_token}")
      end

      it 'marks the server as trusted' do
        result = service.execute

        expect(result[:gitlab][:Trusted]).to be(true)
      end

      it 'builds the tool manager once across a request' do
        allow(Mcp::Tools::Manager).to receive(:new).and_call_original

        service.preapproved_tool_names
        service.gitlab_enabled_tools
        service.execute

        expect(Mcp::Tools::Manager).to have_received(:new).once
      end
    end

    context 'with a catalog agent that has both built-in tool IDs and MCP tools' do
      let(:built_in_tool_ids) { [17, 6] }
      let(:mcp_tools) { %w[search create_workitem_note] }

      it 'includes tools from both sources that exist on the MCP server' do
        result = service.execute

        expect(result[:gitlab][:Tools]).to match_array(
          %w[get_issue create_issue search create_workitem_note]
        )
      end

      it 'preapproves only read-only agent-selected MCP tools' do
        result = service.execute

        expect(result[:gitlab][:PreApprovedTools]).to match_array(
          %w[get_issue search]
        )
      end

      it 'does not include tools not selected by the agent' do
        result = service.execute

        expect(result[:gitlab][:Tools]).not_to include('get_mcp_server_version')
      end

      it 'memoizes mcp_tools_for_agent' do
        config = service.execute
        reloaded_config = service.execute

        expect(config[:gitlab][:Tools]).to equal(reloaded_config[:gitlab][:Tools])
      end
    end

    context 'with only mcp_tools enabled' do
      let(:built_in_tool_ids) { nil }
      let(:mcp_tools) { %w[search semantic_code_search] }

      it 'includes only MCP tools that exist on the server' do
        result = service.execute

        expect(result[:gitlab][:Tools]).to match_array(%w[search semantic_code_search])
      end
    end

    context 'with a catalog agent that has tools NOT on the MCP server' do
      let(:built_in_tool_ids) { [10] }
      let(:mcp_tools) { %w[search] }

      it 'includes only tools that exist on the MCP server' do
        result = service.execute

        # edit_file (ID 10) is not in the MCP server tool list, so it's excluded
        expect(result[:gitlab][:Tools]).to match_array(%w[search])
        expect(result[:gitlab][:Tools]).not_to include('edit_file')
      end
    end

    context 'with only built-in tools not on the MCP server' do
      let(:built_in_tool_ids) { [10, 11] }

      it 'returns built-in tools unfiltered' do
        result = service.execute

        expect(result[:gitlab][:Tools]).to match_array(%w[edit_file find_files])
      end
    end

    context 'when mcp_client feature flag is disabled' do
      before do
        stub_feature_flags(mcp_client: false)
      end

      it 'returns nil' do
        expect(service.execute).to be_nil
      end
    end

    context 'when workflow_definition is a custom agent with both built-in and MCP tools' do
      let(:workflow_definition) { 'custom_agent' }
      let(:built_in_tool_ids) { [17, 6] }
      let(:mcp_tools) { %w[search create_workitem_note] }

      it 'preserves built-in tools that exist on the MCP server alongside MCP tools' do
        result = service.execute

        expect(result[:gitlab][:Tools]).to match_array(
          %w[get_issue create_issue search create_workitem_note]
        )
      end
    end

    context 'with different gitlab tokens' do
      it 'uses the provided token in authorization header' do
        custom_token = 'custom_token_xyz'
        custom_service = described_class.new(
          user,
          custom_token,
          workflow_definition: 'chat',
          ai_catalog_item_version_id: nil
        )

        result = custom_service.execute

        expect(result[:gitlab][:Headers][:Authorization]).to eq("Bearer #{custom_token}")
      end
    end

    context 'when ai_catalog_item_version_id is provided' do
      let_it_be(:mcp_server) do
        create(
          :ai_catalog_mcp_server,
          organization: organization,
          name: 'Test MCP Server',
          url: 'https://mcp.example.com',
          auth_type: :oauth
        )
      end

      let_it_be(:mcp_servers_user) do
        create(
          :ai_catalog_mcp_servers_user,
          mcp_server: mcp_server,
          user: user,
          organization: organization,
          token: 'user_mcp_token_123'
        )
      end

      let_it_be_with_reload(:item) { create(:ai_catalog_item, :agent, :public, organization: organization) }
      let_it_be(:item_version) do
        create(
          :ai_catalog_item_version,
          item: item,
          organization: organization,
          definition: {
            system_prompt: 'Test prompt',
            tools: [],
            mcp_servers: [mcp_server.id]
          }
        )
      end

      let(:ai_catalog_item_version_id) { item_version.id }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
      end

      it 'includes user MCP servers in the configuration' do
        result = service.execute

        expect(result).to have_key(:gitlab)
        expect(result).to have_key(:test_mcp_server)
      end

      it 'includes proper MCP server configuration' do
        result = service.execute

        expect(result[:test_mcp_server]).to match(
          URL: 'https://mcp.example.com',
          Headers: { Authorization: 'Bearer user_mcp_token_123' }
        )
      end

      context 'when MCP server has no_auth type' do
        let_it_be(:no_auth_server) do
          create(
            :ai_catalog_mcp_server,
            organization: organization,
            name: 'No Auth Server',
            url: 'https://noauth.example.com',
            auth_type: :no_auth
          )
        end

        let_it_be(:no_auth_servers_user) do
          create(
            :ai_catalog_mcp_servers_user,
            mcp_server: no_auth_server,
            user: user,
            organization: organization
          )
        end

        let_it_be(:item_version_with_no_auth) do
          create(
            :ai_catalog_item_version,
            item: item,
            organization: organization,
            definition: {
              system_prompt: 'Test prompt',
              tools: [],
              mcp_servers: [no_auth_server.id]
            }
          )
        end

        let(:ai_catalog_item_version_id) { item_version_with_no_auth.id }

        it 'includes MCP server with empty headers' do
          result = service.execute

          expect(result[:no_auth_server]).to match(
            URL: 'https://noauth.example.com',
            Headers: {}
          )
        end
      end

      context 'when user does not have MCP server user association' do
        let_it_be(:server_without_user) do
          create(
            :ai_catalog_mcp_server,
            organization: organization,
            name: 'Server Without User',
            url: 'https://noaccess.example.com',
            auth_type: :oauth
          )
        end

        let_it_be(:item_version_without_user) do
          create(
            :ai_catalog_item_version,
            item: item,
            organization: organization,
            definition: {
              system_prompt: 'Test prompt',
              tools: [],
              mcp_servers: [server_without_user.id]
            }
          )
        end

        let(:ai_catalog_item_version_id) { item_version_without_user.id }

        it 'includes server with empty headers' do
          result = service.execute

          expect(result[:server_without_user]).to match(
            URL: 'https://noaccess.example.com',
            Headers: {}
          )
        end
      end

      context 'when item version does not exist' do
        let(:ai_catalog_item_version_id) { non_existing_record_id }

        it 'does not include catalog MCP servers' do
          result = service.execute

          expect(result).to have_key(:gitlab)
          expect(result).not_to have_key(:test_mcp_server)
        end
      end

      context 'when item version has no mcp_servers in definition' do
        let_it_be(:item_version_no_servers) do
          create(
            :ai_catalog_item_version,
            item: item,
            organization: organization,
            definition: {
              system_prompt: 'Test prompt',
              tools: []
            }
          )
        end

        let(:ai_catalog_item_version_id) { item_version_no_servers.id }

        it 'does not include catalog MCP servers' do
          result = service.execute

          expect(result).to have_key(:gitlab)
          expect(result).not_to have_key(:test_mcp_server)
        end
      end

      context 'when mcp servers are not available' do
        before do
          allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(false)
        end

        it 'does not include catalog MCP servers' do
          result = service.execute

          expect(result).to have_key(:gitlab)
          expect(result).not_to have_key(:test_mcp_server)
        end
      end

      context 'when user is not authorized to read the item version' do
        before do
          item.update!(visibility: :private)
        end

        it 'does not include MCP servers from unauthorized item versions' do
          result = service.execute

          expect(result).to have_key(:gitlab)
          expect(result).not_to have_key(:test_mcp_server)
        end
      end
    end

    context 'when workflow_definition is for agentic chat' do
      where(:workflow_definition) { %w[chat agentic_chat/v1] }

      with_them do
        it 'returns MCP server configuration', :aggregate_failures do
          result = service.execute
          expect(result).to be_a(Hash)
          expect(result).to have_key(:gitlab)
        end
      end
    end

    context 'when workflow_definition is for a foundational agent without configured tools' do
      where(:workflow_definition) { [nil, '', 'software_development', 'analytics_agent/v1'] }

      before do
        user.user_preference.update!(orbit_settings: { 'enabled' => true })
      end

      with_them do
        it 'returns only orbit MCP configuration' do
          expect(service.execute).to eq(
            orbit: {
              Headers: { Authorization: "Bearer #{gitlab_token}" },
              PreApprovedTools: described_class::ORBIT_PREAPPROVED_TOOLS,
              Trusted: true
            }
          )
        end
      end
    end

    context 'when workflow_definition is for a foundational agent with mcp_tools configured' do
      let(:workflow_definition) { 'software_development' }
      let(:mcp_tools) { %w[search semantic_code_search] }

      it 'injects the GitLab MCP server with the configured tools' do
        result = service.execute

        expect(result).to have_key(:gitlab)
        expect(result[:gitlab][:Tools]).to match_array(%w[search semantic_code_search])
      end

      it 'preapproves all configured tools' do
        result = service.execute

        expect(result[:gitlab][:PreApprovedTools]).to match_array(%w[search semantic_code_search])
      end
    end

    context 'when workflow_definition is a foundational agent with selected MCP tools and no item version' do
      let(:workflow_definition) { 'duo_planner/v1' }
      let(:ai_catalog_item_version_id) { nil }

      let(:foundational_version) do
        # rubocop:disable RSpec/VerifiedDoubles -- def_tools/def_mcp_tools are method_missing accessors on ItemVersion
        double('Ai::Catalog::ItemVersion', def_tools: [], def_mcp_tools: %w[get_saved_view_work_items])
        # rubocop:enable RSpec/VerifiedDoubles
      end

      before do
        # No catalog item version is passed for foundational agents, so item_version is nil.
        allow(service).to receive(:item_version).and_return(nil)

        agent = instance_double(Ai::FoundationalChatAgent, global_catalog_id: 348)
        allow(Ai::FoundationalChatAgent).to receive(:with_workflow_definition)
          .with('duo_planner/v1').and_return(agent)
        catalog_item = instance_double(Ai::Catalog::Item, latest_released_version_with_fallback: foundational_version)
        allow(Ai::Catalog::Item).to receive(:find_by_id).with(348).and_return(catalog_item)
      end

      it 'resolves the catalog version and injects its selected MCP tools', :aggregate_failures do
        result = service.execute

        expect(result).to have_key(:gitlab)
        expect(result[:gitlab][:Tools]).to include('get_saved_view_work_items')
        expect(result[:gitlab][:PreApprovedTools]).to include('get_saved_view_work_items')
      end

      context 'when no foundational agent matches the workflow definition' do
        before do
          allow(Ai::FoundationalChatAgent).to receive(:with_workflow_definition)
            .with('duo_planner/v1').and_return(nil)
        end

        it 'does not inject the GitLab MCP server' do
          result = service.execute

          expect(result).not_to have_key(:gitlab)
        end
      end

      context 'when the foundational agent has no global_catalog_id' do
        before do
          agent = instance_double(Ai::FoundationalChatAgent, global_catalog_id: nil)
          allow(Ai::FoundationalChatAgent).to receive(:with_workflow_definition)
            .with('duo_planner/v1').and_return(agent)
        end

        it 'does not inject the GitLab MCP server' do
          result = service.execute

          expect(result).not_to have_key(:gitlab)
        end
      end

      context 'when the catalog item does not exist' do
        before do
          allow(Ai::Catalog::Item).to receive(:find_by_id).with(348).and_return(nil)
        end

        it 'does not inject the GitLab MCP server' do
          result = service.execute

          expect(result).not_to have_key(:gitlab)
        end
      end
    end
  end

  describe '#gitlab_enabled_tools' do
    it 'includes aliases of read-only tools and excludes aliases of write tools' do
      read_only = Class.new do
        def annotations
          { readOnlyHint: true }
        end
      end.new
      write = Class.new do
        def annotations
          { readOnlyHint: false }
        end
      end.new
      allow(Mcp::Tools::Manager).to receive(:new).and_return(
        instance_double(
          Mcp::Tools::Manager,
          list_tools: { 'reader' => read_only, 'writer' => write },
          alias_map: { 'read_only_alias' => 'reader', 'write_alias' => 'writer' }
        )
      )

      result = service.gitlab_enabled_tools

      expect(result).to include('reader', 'read_only_alias')
      expect(result).not_to include('writer', 'write_alias')
    end

    context 'with default chat (no catalog agent)' do
      where(:workflow_definition) { %w[chat agentic_chat/v1] }

      with_them do
        it 'returns preapproved tools derived from readOnlyHint annotations' do
          expect(service.gitlab_enabled_tools).to match_array(read_only_tool_names + read_only_alias_names)
        end
      end
    end

    context 'with a catalog agent that has tools matching MCP server' do
      let(:built_in_tool_ids) { [17, 6] }
      let(:mcp_tools) { %w[search create_workitem_note] }

      it 'includes tools from both sources' do
        expect(service.gitlab_enabled_tools).to match_array(
          %w[get_issue create_issue search create_workitem_note]
        )
      end
    end

    context 'with a catalog agent using a non-chat workflow definition' do
      let(:workflow_definition) { 'software_development' }
      let(:mcp_tools) { %w[search create_issue] }

      it 'returns the configured tools regardless of workflow definition' do
        expect(service.gitlab_enabled_tools).to match_array(%w[search create_issue])
      end
    end

    context 'when mcp_client feature flag is disabled' do
      before do
        stub_feature_flags(mcp_client: false)
      end

      it 'returns empty array' do
        expect(service.gitlab_enabled_tools).to eq([])
      end
    end

    context 'when workflow_definition is for a foundational agent without configured tools' do
      where(:workflow_definition) { [nil, '', 'software_development', 'analytics_agent/v1', 'code_review/v2'] }

      with_them do
        it 'returns empty array' do
          expect(service.gitlab_enabled_tools).to eq([])
        end
      end
    end
  end

  describe '#preapproved_tool_names' do
    let(:prefixed_orbit_tools) { described_class::ORBIT_PREAPPROVED_TOOLS.map { |tool| "orbit_#{tool}" } }
    let(:gitlab_claim_tools) { read_only_tool_names.map { |tool_name| "gitlab_#{tool_name}" } }

    context 'when orbit is enabled' do
      before do
        stub_feature_flags(knowledge_graph: user)
        user.user_preference.update!(orbit_settings: { 'enabled' => true })
      end

      it 'returns the gitlab claim tools plus the prefixed orbit tool names' do
        expect(service.preapproved_tool_names).to match_array(gitlab_claim_tools + prefixed_orbit_tools)
      end

      # Asserted literally: a wrong prefix fails silently at runtime, so the
      # expectation must not be built from the same source as the code.
      it 'emits gitlab MCP names under the gitlab_ prefix' do
        expect(service.preapproved_tool_names).to include('gitlab_search', 'gitlab_get_mcp_server_version')
      end

      context 'with the agentic_chat/v1 definition' do
        let(:workflow_definition) { 'agentic_chat/v1' }

        it 'returns the same names as legacy chat' do
          expect(service.preapproved_tool_names).to match_array(gitlab_claim_tools + prefixed_orbit_tools)
        end
      end

      context 'with a custom agent that has selected a subset of tools' do
        let(:ai_catalog_item_version_id) { 42 }
        let(:built_in_tool_ids) { [17] }
        let(:mcp_tools) { %w[create_workitem_note search invoke_command] }

        it 'returns only the selected gitlab tools and selected orbit tools' do
          expect(service.preapproved_tool_names)
            .to contain_exactly('gitlab_get_issue', 'gitlab_search', 'orbit_invoke_command')
        end
      end

      context 'with a custom agent whose selection contains no claim-eligible tool' do
        let(:ai_catalog_item_version_id) { 42 }
        let(:built_in_tool_ids) { [] }
        let(:mcp_tools) { %w[create_workitem_note invoke_command] }

        it 'contributes no gitlab names rather than falling back to the full list' do
          expect(service.preapproved_tool_names).to contain_exactly('orbit_invoke_command')
        end
      end

      context 'when the gitlab MCP server is not enabled for the definition' do
        let(:workflow_definition) { 'software_development' }

        it 'returns only the prefixed orbit tool names' do
          expect(service.preapproved_tool_names).to match_array(prefixed_orbit_tools)
        end
      end
    end

    context 'when orbit is not enabled' do
      it 'returns only the gitlab claim tools' do
        expect(service.preapproved_tool_names).to match_array(gitlab_claim_tools)
      end
    end

    context 'when neither orbit nor the gitlab MCP server is enabled' do
      let(:workflow_definition) { 'software_development' }

      it 'returns empty array' do
        expect(service.preapproved_tool_names).to eq([])
      end
    end

    context 'when mcp_client feature flag is disabled' do
      before do
        stub_feature_flags(mcp_client: false)
      end

      it 'returns empty array' do
        expect(service.preapproved_tool_names).to eq([])
      end
    end
  end

  describe 'orbit MCP server' do
    before do
      stub_feature_flags(knowledge_graph: user)
      user.user_preference.update!(orbit_settings: { 'enabled' => true })
    end

    context 'with agentic chat workflow' do
      let(:workflow_definition) { 'chat' }

      it 'includes orbit server with tools and trusted flag' do
        result = service.execute

        expect(result).to have_key(:orbit)
        expect(result[:orbit]).not_to have_key(:Tools)
        expect(result[:orbit][:PreApprovedTools])
          .to eq(::API::Orbit::McpHandlers::ToolCatalog::COMMAND_TOOL_NAMES)
        expect(result[:orbit][:Trusted]).to be(true)
        expect(result[:orbit][:Headers][:Authorization]).to eq("Bearer #{gitlab_token}")
      end
    end

    context 'with a non-chat foundational agent' do
      let(:workflow_definition) { 'security_analyst_agent/v1' }

      it 'includes orbit server' do
        result = service.execute

        expect(result).to have_key(:orbit)
      end
    end

    context 'with a custom agent that has selected only removed legacy orbit tools' do
      let(:workflow_definition) { 'chat' }
      let(:ai_catalog_item_version_id) { 42 }
      let(:mcp_tools) { %w[query_graph get_graph_schema] }

      it 'does not include orbit server' do
        result = service.execute

        expect(result).not_to have_key(:orbit)
      end
    end

    context 'with a custom agent that has selected legacy and command orbit tools' do
      let(:workflow_definition) { 'chat' }
      let(:ai_catalog_item_version_id) { 42 }
      let(:mcp_tools) { %w[query_graph get_graph_schema invoke_command] }

      it 'injects only the command selected tools' do
        result = service.execute

        expect(result[:orbit][:Tools]).to match_array(%w[invoke_command])
        expect(result[:orbit][:PreApprovedTools]).to match_array(%w[invoke_command])
      end
    end

    context 'with the Duo Code Review workflow' do
      where(:workflow_definition) { %w[code_review/v1 code_review/v2] }

      with_them do
        it 'does not include orbit server' do
          result = service.execute

          expect(result).not_to have_key(:orbit)
        end

        context 'when ai_catalog_item_version_id is present and agent has orbit tools' do
          let(:ai_catalog_item_version_id) { 42 }
          let(:built_in_tool_ids) { [17] }
          let(:mcp_tools) { %w[invoke_command] }

          before do
            stub_feature_flags(orbit_foundational_agent: user)
          end

          it 'still does not include orbit server' do
            result = service.execute

            expect(result).not_to have_key(:orbit)
          end
        end
      end
    end

    context 'with orbit agent workflow' do
      let(:workflow_definition) { 'orbit_agent/v1' }

      it 'includes orbit server with tools and trusted flag' do
        result = service.execute

        expect(result).to have_key(:orbit)
        expect(result[:orbit][:PreApprovedTools])
          .to eq(::API::Orbit::McpHandlers::ToolCatalog::COMMAND_TOOL_NAMES)
        expect(result[:orbit][:Trusted]).to be(true)
        expect(result[:orbit][:Headers][:Authorization]).to eq("Bearer #{gitlab_token}")
      end
    end

    context 'with a custom agent that has explicit tools configured' do
      let(:workflow_definition) { 'chat' }
      let(:ai_catalog_item_version_id) { 42 }
      let(:built_in_tool_ids) { [17, 6] }

      it 'does not inject orbit server' do
        result = service.execute

        expect(result).not_to have_key(:orbit)
      end

      it 'still includes the gitlab server with the agent tools' do
        result = service.execute

        expect(result).to have_key(:gitlab)
        expect(result[:gitlab][:Tools]).to include('get_issue', 'create_issue')
      end
    end

    context 'with a custom agent that has only non-orbit MCP tools configured' do
      let(:workflow_definition) { 'chat' }
      let(:ai_catalog_item_version_id) { 42 }
      let(:mcp_tools) { %w[search create_workitem_note] }

      it 'does not inject orbit server' do
        result = service.execute

        expect(result).not_to have_key(:orbit)
      end
    end

    context 'with a custom agent that has orbit MCP tools selected' do
      let(:workflow_definition) { 'chat' }
      let(:ai_catalog_item_version_id) { 42 }
      let(:mcp_tools) { %w[list_commands invoke_command] }

      it 'includes orbit server' do
        result = service.execute

        expect(result).to have_key(:orbit)
      end

      it 'restricts Tools and PreApprovedTools to selected orbit tools' do
        result = service.execute

        expect(result[:orbit][:Tools]).to match_array(%w[list_commands invoke_command])
        expect(result[:orbit][:PreApprovedTools]).to match_array(%w[list_commands invoke_command])
      end

      it 'marks the server as trusted' do
        result = service.execute

        expect(result[:orbit][:Trusted]).to be(true)
      end
    end

    context 'with a custom agent that has mixed orbit and non-orbit MCP tools' do
      let(:workflow_definition) { 'chat' }
      let(:ai_catalog_item_version_id) { 42 }
      let(:mcp_tools) { %w[invoke_command search create_workitem_note] }

      it 'includes orbit server with only orbit tools' do
        result = service.execute

        expect(result[:orbit][:Tools]).to match_array(%w[invoke_command])
        expect(result[:orbit][:PreApprovedTools]).to match_array(%w[invoke_command])
      end

      it 'includes gitlab server with non-orbit tools' do
        result = service.execute

        expect(result).to have_key(:gitlab)
        expect(result[:gitlab][:Tools]).to include('search', 'create_workitem_note')
        expect(result[:gitlab][:Tools]).not_to include('invoke_command')
      end
    end

    context 'with a catalog item version but no tools (falls back to default chat)' do
      let(:workflow_definition) { 'chat' }
      let(:ai_catalog_item_version_id) { 42 }
      let(:built_in_tool_ids) { [] }
      let(:mcp_tools) { [] }

      it 'includes orbit server with full tool set and no Tools key' do
        result = service.execute

        expect(result).to have_key(:orbit)
        expect(result[:orbit]).not_to have_key(:Tools)
        expect(result[:orbit][:PreApprovedTools]).to eq(described_class::ORBIT_PREAPPROVED_TOOLS)
      end
    end

    context 'when knowledge_graph feature flag is disabled' do
      before do
        stub_feature_flags(knowledge_graph: false)
      end

      it 'does not include orbit server' do
        result = service.execute

        expect(result).not_to have_key(:orbit)
      end
    end

    context 'when the Knowledge Graph service is not configured on the instance' do
      before do
        stub_config(knowledge_graph: { 'enabled' => false })
      end

      it 'does not inject orbit tools even with the feature flag on' do
        result = service.execute

        expect(result).not_to have_key(:orbit)
      end
    end

    context 'when orbit_foundational_agent feature flag is disabled' do
      before do
        stub_feature_flags(orbit_foundational_agent: false)
      end

      it 'does not include orbit server' do
        result = service.execute

        expect(result).not_to have_key(:orbit)
      end
    end

    context 'when orbit_user_preference feature flag is disabled (default)' do
      before do
        stub_feature_flags(orbit_user_preference: false)
        user.user_preference.update!(orbit_settings: { 'enabled' => false })
      end

      it 'ignores user preference and includes orbit server' do
        result = service.execute

        expect(result).to have_key(:orbit)
      end
    end

    context 'when orbit_user_preference feature flag is enabled' do
      before do
        stub_feature_flags(orbit_user_preference: user)
      end

      context 'when user has orbit_enabled: false' do
        before do
          user.user_preference.update!(orbit_settings: { 'enabled' => false })
        end

        context 'with agentic chat workflow' do
          let(:workflow_definition) { 'chat' }

          it 'does not include orbit server' do
            result = service.execute

            expect(result).not_to have_key(:orbit)
          end
        end

        context 'with orbit agent workflow' do
          let(:workflow_definition) { 'orbit_agent/v1' }

          it 'does not include orbit server' do
            result = service.execute

            expect(result).not_to have_key(:orbit)
          end
        end

        context 'with a non-chat foundational agent' do
          let(:workflow_definition) { 'security_analyst_agent/v1' }

          it 'does not include orbit server' do
            result = service.execute

            expect(result).not_to have_key(:orbit)
          end
        end
      end

      context 'when user has orbit_enabled: true (explicit opt-in)' do
        before do
          user.user_preference.update!(orbit_settings: { 'enabled' => true })
        end

        it 'includes orbit server for chat' do
          result = service.execute

          expect(result).to have_key(:orbit)
        end

        context 'with orbit agent workflow' do
          let(:workflow_definition) { 'orbit_agent/v1' }

          it 'includes orbit server' do
            result = service.execute

            expect(result).to have_key(:orbit)
          end
        end

        context 'with a non-chat foundational agent' do
          let(:workflow_definition) { 'security_analyst_agent/v1' }

          it 'includes orbit server' do
            result = service.execute

            expect(result).to have_key(:orbit)
          end
        end
      end

      context 'when user has empty orbit_settings (default - treated as disabled)' do
        before do
          user.user_preference.update!(orbit_settings: {})
        end

        it 'does not include orbit server (empty means disabled)' do
          result = service.execute

          expect(result).not_to have_key(:orbit)
        end
      end

      context 'with granular subsettings (killswitch on)' do
        context 'when only orbit_agent_enabled is true' do
          before do
            user.user_preference.update!(orbit_settings: {
              'enabled' => true,
              'orbit_agent_enabled' => true,
              'orbit_agentic_chat_enabled' => false,
              'orbit_other_foundational_agents_enabled' => false
            })
          end

          context 'with the orbit agent workflow' do
            let(:workflow_definition) { 'orbit_agent/v1' }

            it 'includes the orbit server' do
              expect(service.execute).to have_key(:orbit)
            end
          end

          context 'with the agentic chat workflow' do
            let(:workflow_definition) { 'chat' }

            it 'does not include the orbit server' do
              expect(service.execute).not_to have_key(:orbit)
            end
          end

          context 'with a non-chat foundational agent' do
            let(:workflow_definition) { 'security_analyst_agent/v1' }

            it 'does not include the orbit server' do
              expect(service.execute).not_to have_key(:orbit)
            end
          end
        end

        context 'when only orbit_agentic_chat_enabled is true' do
          before do
            user.user_preference.update!(orbit_settings: {
              'enabled' => true,
              'orbit_agent_enabled' => false,
              'orbit_agentic_chat_enabled' => true,
              'orbit_other_foundational_agents_enabled' => false
            })
          end

          context 'with the agentic chat workflow' do
            let(:workflow_definition) { 'chat' }

            it 'includes the orbit server' do
              expect(service.execute).to have_key(:orbit)
            end
          end

          context 'with the orbit agent workflow' do
            let(:workflow_definition) { 'orbit_agent/v1' }

            it 'does not include the orbit server' do
              expect(service.execute).not_to have_key(:orbit)
            end
          end

          context 'with a non-chat foundational agent' do
            let(:workflow_definition) { 'security_analyst_agent/v1' }

            it 'does not include the orbit server' do
              expect(service.execute).not_to have_key(:orbit)
            end
          end
        end

        context 'when only orbit_other_foundational_agents_enabled is true' do
          before do
            user.user_preference.update!(orbit_settings: {
              'enabled' => true,
              'orbit_agent_enabled' => false,
              'orbit_agentic_chat_enabled' => false,
              'orbit_other_foundational_agents_enabled' => true
            })
          end

          context 'with a non-chat foundational agent' do
            let(:workflow_definition) { 'security_analyst_agent/v1' }

            it 'includes the orbit server' do
              expect(service.execute).to have_key(:orbit)
            end
          end

          context 'with the agentic chat workflow' do
            let(:workflow_definition) { 'chat' }

            it 'does not include the orbit server' do
              expect(service.execute).not_to have_key(:orbit)
            end
          end

          context 'with the orbit agent workflow' do
            let(:workflow_definition) { 'orbit_agent/v1' }

            it 'does not include the orbit server' do
              expect(service.execute).not_to have_key(:orbit)
            end
          end
        end

        context 'when subsetting keys are absent (legacy opt-in)' do
          before do
            # Existing users from the original killswitch-only MR may have
            # orbit_settings: { 'enabled' => true } with no subsetting keys.
            # All flows should remain enabled (subsettings default to true).
            user.user_preference.update!(orbit_settings: { 'enabled' => true })
          end

          [nil, 'chat', 'orbit_agent/v1', 'security_analyst_agent/v1'].each do |definition|
            context "with workflow #{definition}" do
              let(:workflow_definition) { definition }

              it 'includes the orbit server (subsettings default to true)' do
                expect(service.execute).to have_key(:orbit)
              end
            end
          end
        end

        context 'with a custom agent that has selected orbit tools' do
          let(:workflow_definition) { 'chat' }
          let(:ai_catalog_item_version_id) { 42 }
          let(:mcp_tools) { %w[list_commands invoke_command] }

          context 'when orbit_custom_agents_enabled is true (other subsettings off)' do
            before do
              user.user_preference.update!(orbit_settings: {
                'enabled' => true,
                'orbit_agent_enabled' => false,
                'orbit_agentic_chat_enabled' => false,
                'orbit_other_foundational_agents_enabled' => false,
                'orbit_custom_agents_enabled' => true
              })
            end

            it 'includes the orbit server for the custom agent' do
              expect(service.execute).to have_key(:orbit)
            end
          end

          context 'when orbit_custom_agents_enabled is false (other subsettings on)' do
            before do
              user.user_preference.update!(orbit_settings: {
                'enabled' => true,
                'orbit_agent_enabled' => true,
                'orbit_agentic_chat_enabled' => true,
                'orbit_other_foundational_agents_enabled' => true,
                'orbit_custom_agents_enabled' => false
              })
            end

            it 'does not include the orbit server for the custom agent' do
              expect(service.execute).not_to have_key(:orbit)
            end
          end
        end
      end
    end
  end

  describe 'constants' do
    it 'defines ORBIT_PREAPPROVED_TOOLS from trusted Orbit tools' do
      expect(described_class::ORBIT_PREAPPROVED_TOOLS).to eq(
        ::API::Orbit::McpHandlers::ToolCatalog::COMMAND_TOOL_NAMES
      )
    end
  end
end
