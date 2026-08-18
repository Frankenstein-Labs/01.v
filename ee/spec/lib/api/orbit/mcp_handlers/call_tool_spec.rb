# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Orbit::McpHandlers::CallTool, feature_category: :knowledge_graph do
  let_it_be(:user) { create(:user) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp_orbit]) }

  let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }
  let(:tool_name) { 'invoke_command' }
  let(:arguments) { invoke_command_arguments('query_graph', { 'query' => 'find pipelines' }) }
  let(:params) { { name: tool_name, arguments: arguments } }

  let(:request_context) do
    Analytics::KnowledgeGraph::RequestContext.new(source_type: Analytics::KnowledgeGraph::SourceType::MCP)
  end

  subject(:handler) do
    described_class.new(
      params,
      access_token,
      user,
      grpc_client: grpc_client,
      request_context: request_context
    )
  end

  def invoke_command_arguments(command_name, parameters)
    { 'command_name' => command_name, 'parameters' => parameters }
  end

  describe '#invoke' do
    before do
      auth_context = instance_double(
        Analytics::KnowledgeGraph::AuthorizationContext, has_enabled_namespaces?: true
      )
      allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_return(auth_context)
    end

    context 'when query_graph tool is called' do
      let(:send_data_header) { 'Gitlab-Workhorse-Send-Data' }
      let(:send_data_value) { 'orbit-query:test-encoded-data' }

      before do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .with(hash_including(query: 'find pipelines', user: user, format: :llm, mcp_id: nil))
          .and_return([send_data_header, send_data_value])
      end

      it 'returns a WorkhorseSendData struct' do
        result = handler.invoke

        expect(result).to be_a(described_class::WorkhorseSendData)
        expect(result.header_name).to eq(send_data_header)
        expect(result.header_value).to eq(send_data_value)
      end
    end

    context 'when query_graph is called with format raw' do
      let(:arguments) { invoke_command_arguments('query_graph', { 'query' => 'find pipelines', 'format' => 'raw' }) }

      before do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .with(hash_including(query: 'find pipelines', user: user, format: :raw, mcp_id: nil))
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
      end

      it 'passes raw format to Workhorse' do
        result = handler.invoke

        expect(result).to be_a(described_class::WorkhorseSendData)
        expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
          .with(hash_including(format: :raw))
      end
    end

    context 'when query_graph is called without format' do
      before do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .with(hash_including(query: 'find pipelines', user: user, format: :llm, mcp_id: nil))
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
      end

      it 'defaults to llm format' do
        handler.invoke

        expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
          .with(hash_including(format: :llm))
      end
    end

    context 'when query_graph is called with a Hash query' do
      let(:query) { { 'query_type' => 'search', 'node' => { 'id' => 'n', 'entity' => 'Project' } } }
      let(:arguments) { invoke_command_arguments('query_graph', { 'query' => query }) }

      before do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .with(hash_including(query: query.to_json, user: user, format: :llm, mcp_id: nil))
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
      end

      it 'serializes the Hash to JSON before passing to Workhorse' do
        result = handler.invoke

        expect(result).to be_a(described_class::WorkhorseSendData)
        expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
          .with(hash_including(query: query.to_json))
      end
    end

    context 'when query_graph is called without enabled namespaces' do
      before do
        auth_context = instance_double(
          Analytics::KnowledgeGraph::AuthorizationContext, has_enabled_namespaces?: false
        )
        allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_return(auth_context)
      end

      it 'returns a tool error response' do
        result = handler.invoke

        expect(result[:isError]).to be(true)
        expect(result[:content].first[:text]).to include('No Knowledge Graph enabled namespaces available')
      end

      it 'does not call Workhorse' do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)

        handler.invoke

        expect(Gitlab::Workhorse).not_to have_received(:send_orbit_query)
      end
    end

    context 'when list_commands is called' do
      let(:tool_name) { 'list_commands' }
      let(:arguments) { { 'command_names' => ['get_query_dsl'], 'format' => 'llm' } }
      let(:commands_result) do
        [{ name: 'get_query_dsl', description: 'Return query DSL', parameters: { 'type' => 'object' } }]
      end

      before do
        allow(grpc_client).to receive(:list_agent_commands)
          .with(user: user, command_names: ['get_query_dsl'], format: :llm,
            request_context: an_instance_of(Analytics::KnowledgeGraph::RequestContext))
          .and_return({ formatted_text: "commands[1]:\n  - name: get_query_dsl" })
      end

      it 'returns the LLM-formatted command catalog from gRPC' do
        result = handler.invoke

        expect(result[:isError]).to be(false)
        expect(result[:content].first[:text]).to include('commands[1]:')
        expect(result[:content].first[:text]).to include('name: get_query_dsl')
      end

      context 'with raw format' do
        let(:arguments) { { 'command_names' => ['get_query_dsl'], 'format' => 'raw' } }

        before do
          allow(grpc_client).to receive(:list_agent_commands)
            .with(user: user, command_names: ['get_query_dsl'], format: :raw,
              request_context: an_instance_of(Analytics::KnowledgeGraph::RequestContext))
            .and_return(commands_result)
        end

        it 'returns command metadata from gRPC as JSON text' do
          result = handler.invoke

          expect(result[:isError]).to be(false)
          parsed = Gitlab::Json.safe_parse(result[:content].first[:text])
          expect(parsed.first['name']).to eq('get_query_dsl')
        end
      end
    end

    context 'when invoke_command falls through to GKG' do
      let(:tool_name) { 'invoke_command' }
      let(:arguments) do
        {
          'command_name' => 'get_query_dsl',
          'parameters' => { 'format' => 'llm' }
        }
      end

      before do
        allow(grpc_client).to receive(:invoke_agent_command)
          .with(command_name: 'get_query_dsl', parameters: { 'format' => 'llm' }, user: user,
            request_context: an_instance_of(Analytics::KnowledgeGraph::RequestContext))
          .and_return({ formatted_text: 'dsl text' })
      end

      it 'invokes the command through gRPC' do
        result = handler.invoke

        expect(result[:isError]).to be(false)
        expect(result[:content].first[:text]).to eq('dsl text')
      end
    end

    context 'when invoke_command intercepts query_graph' do
      let(:tool_name) { 'invoke_command' }
      let(:arguments) do
        {
          'command_name' => 'query_graph',
          'parameters' => { 'query' => 'find pipelines' }
        }
      end

      before do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .with(hash_including(query: 'find pipelines', user: user, format: :llm, mcp_id: nil))
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
      end

      it 'routes to the existing Workhorse path' do
        result = handler.invoke

        expect(result).to be_a(described_class::WorkhorseSendData)
      end
    end

    context 'when invoke_command receives downstream arguments at the top level' do
      let(:tool_name) { 'invoke_command' }
      let(:arguments) { { 'command_name' => 'get_query_dsl', 'format' => 'llm' } }

      it 'raises an invalid parameter error' do
        expect { handler.invoke }.to raise_error(ArgumentError, /Put downstream command inputs inside 'parameters'/)
      end
    end

    context 'when tool name is unknown' do
      let(:params) { { name: 'unknown_tool', arguments: {} } }

      it 'raises ArgumentError' do
        expect { handler.invoke }.to raise_error(ArgumentError, /Unknown tool: unknown_tool/)
      end
    end

    %w[query_graph get_graph_schema get_graph_status].each do |legacy_tool|
      context "when #{legacy_tool} (a removed legacy tool) is called" do
        let(:params) { { name: legacy_tool, arguments: {} } }

        it 'raises ArgumentError treating it as an unknown tool' do
          expect { handler.invoke }.to raise_error(ArgumentError, /Unknown tool: #{legacy_tool}/)
        end
      end
    end

    context 'when invoke_command raises ConnectionError' do
      let(:arguments) { invoke_command_arguments('get_query_dsl', {}) }

      before do
        allow(grpc_client).to receive(:invoke_agent_command)
          .and_raise(Analytics::KnowledgeGraph::GrpcClient::ConnectionError, 'connection refused')
      end

      it 'raises API::Orbit::Mcp::InternalError' do
        expect { handler.invoke }.to raise_error(API::Orbit::Mcp::InternalError, /connection refused/)
      end
    end

    context 'when invoke_command raises ExecutionError' do
      let(:arguments) { invoke_command_arguments('get_query_dsl', {}) }

      before do
        allow(grpc_client).to receive(:invoke_agent_command)
          .and_raise(Analytics::KnowledgeGraph::GrpcClient::ExecutionError, 'INVALID_COMMAND: get_query_dsl')
      end

      it 'returns MCP error result with isError true' do
        result = handler.invoke

        expect(result[:isError]).to be(true)
        expect(result[:content]).to be_an(Array)
        expect(result[:content].first[:type]).to eq('text')
        expect(result[:content].first[:text]).to include('INVALID_COMMAND: get_query_dsl')
      end
    end

    context 'when invoke_command raises StreamError' do
      let(:arguments) { invoke_command_arguments('get_query_dsl', {}) }

      before do
        allow(grpc_client).to receive(:invoke_agent_command)
          .and_raise(Analytics::KnowledgeGraph::GrpcClient::StreamError, 'Stream ended without result')
      end

      it 'raises API::Orbit::Mcp::InternalError' do
        expect { handler.invoke }.to raise_error(API::Orbit::Mcp::InternalError, /Stream ended without result/)
      end
    end

    context 'when tool name is missing' do
      let(:params) { { name: nil, arguments: {} } }

      it 'raises ArgumentError' do
        expect { handler.invoke }.to raise_error(ArgumentError)
      end
    end

    context 'when tool name is empty' do
      let(:params) { { name: '', arguments: {} } }

      it 'raises ArgumentError' do
        expect { handler.invoke }.to raise_error(ArgumentError)
      end
    end

    context 'when session_id is provided' do
      subject(:handler) do
        described_class.new(
          params,
          access_token,
          user,
          grpc_client: grpc_client,
          request_context: Analytics::KnowledgeGraph::RequestContext.new(
            source_type: Analytics::KnowledgeGraph::SourceType::MCP,
            session_id: 'workflow-abc-123'
          )
        )
      end

      context 'when calling query_graph' do
        before do
          allow(Gitlab::Workhorse).to receive(:send_orbit_query)
            .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
        end

        it 'passes session_id to send_orbit_query' do
          handler.invoke

          expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
            .with(hash_including(request_context: having_attributes(session_id: 'workflow-abc-123')))
        end
      end
    end

    context 'when session_id is not provided' do
      before do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
      end

      it 'passes nil session_id to send_orbit_query' do
        handler.invoke

        expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
          .with(hash_including(request_context: having_attributes(session_id: nil)))
      end
    end

    context 'when user_agent is provided' do
      subject(:handler) do
        described_class.new(
          params,
          access_token,
          user,
          grpc_client: grpc_client,
          request_context: Analytics::KnowledgeGraph::RequestContext.new(
            source_type: Analytics::KnowledgeGraph::SourceType::MCP,
            user_agent: 'TestAgent/1.0'
          )
        )
      end

      context 'when calling query_graph' do
        before do
          allow(Gitlab::Workhorse).to receive(:send_orbit_query)
            .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
        end

        it 'passes user_agent to send_orbit_query' do
          handler.invoke

          expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
            .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
        end
      end

      context 'when calling list_commands' do
        let(:tool_name) { 'list_commands' }
        let(:arguments) { { 'command_names' => ['get_query_dsl'], 'format' => 'llm' } }

        before do
          allow(grpc_client).to receive(:list_agent_commands)
            .and_return({ formatted_text: "commands[1]:\n  - name: get_query_dsl" })
        end

        it 'passes user_agent to grpc_client.list_agent_commands' do
          handler.invoke

          expect(grpc_client).to have_received(:list_agent_commands)
            .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
        end
      end

      context 'when calling invoke_command' do
        let(:tool_name) { 'invoke_command' }
        let(:arguments) { { 'command_name' => 'get_query_dsl', 'parameters' => { 'format' => 'llm' } } }

        before do
          allow(grpc_client).to receive(:invoke_agent_command).and_return({ formatted_text: 'dsl text' })
        end

        it 'passes user_agent to grpc_client.invoke_agent_command' do
          handler.invoke

          expect(grpc_client).to have_received(:invoke_agent_command)
            .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
        end
      end
    end

    context 'when user_agent is not provided' do
      before do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
      end

      it 'passes nil user_agent to send_orbit_query' do
        handler.invoke

        expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
          .with(hash_including(request_context: having_attributes(user_agent: nil)))
      end
    end
  end
end
