# frozen_string_literal: true

require "spec_helper"

RSpec.describe API::Orbit::Mcp, feature_category: :knowledge_graph do
  let_it_be(:user) { create(:user) }
  let_it_be(:access_token) { create(:oauth_access_token, user: user, scopes: [:mcp_orbit]) }
  let_it_be(:group) { create(:group) }

  let(:initialize_params) do
    { jsonrpc: '2.0', method: 'initialize', id: '1', params: { protocolVersion: '2025-06-18' } }
  end

  before_all do
    group.add_reporter(user)
  end

  before do
    stub_licensed_features(orbit: true)
    stub_config(knowledge_graph: { 'enabled' => true })
  end

  describe 'POST /orbit/mcp' do
    context 'when unauthenticated' do
      it 'returns a WWW-Authenticate challenge pointing at the resource metadata', :aggregate_failures do
        post api('/orbit/mcp')

        metadata_url = "#{Gitlab.config.gitlab.url}/.well-known/oauth-protected-resource/api/v4/orbit/mcp"
        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(response.headers['WWW-Authenticate'])
          .to eq(%(Bearer realm="GitLab", resource_metadata="#{metadata_url}"))
      end
    end

    context 'when knowledge_graph feature flag is disabled' do
      before do
        stub_feature_flags(knowledge_graph: false)
      end

      it 'returns not found' do
        post api('/orbit/mcp', user, oauth_access_token: access_token), params: initialize_params

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when knowledge_graph feature flag is enabled' do
      before do
        stub_feature_flags(knowledge_graph: user)
      end

      context 'when user belongs to a group with Premium plan' do
        it 'returns success for initialize' do
          post api('/orbit/mcp', user, oauth_access_token: access_token), params: initialize_params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({
            "id" => "1",
            "jsonrpc" => "2.0",
            "result" => {
              "capabilities" => { "tools" => { "listChanged" => false } },
              "protocolVersion" => "2025-06-18",
              "serverInfo" => { "name" => "GitLab Orbit MCP Server", "version" => Gitlab::VERSION }
            }
          })
        end
      end

      context 'when orbit licensed feature is not available' do
        before do
          stub_licensed_features(orbit: false)
        end

        it 'returns forbidden' do
          post api('/orbit/mcp', user, oauth_access_token: access_token), params: initialize_params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with OAuth token scopes' do
        using RSpec::Parameterized::TableSyntax

        where(:scope_description, :token_scopes, :expected_status) do
          'mcp_orbit'         | [:mcp_orbit]       | :ok
          'mcp'               | [:mcp]             | :ok
          'read_api'          | [:read_api]        | :ok
          'api'               | [:api]             | :ok
          'ai_workflows'      | [:ai_workflows]    | :ok
          'api and mcp_orbit' | [:api, :mcp_orbit] | :ok
          'read_user'         | [:read_user]       | :forbidden
        end

        with_them do
          let(:scoped_token) { create(:oauth_access_token, user: user, scopes: token_scopes) }

          it 'enforces the accepted scopes', :aggregate_failures do
            post api('/orbit/mcp', user, oauth_access_token: scoped_token), params: initialize_params

            expect(response).to have_gitlab_http_status(expected_status)
            expect(json_response['error']).to eq('insufficient_scope') if expected_status == :forbidden
          end
        end
      end

      context 'with a personal access token' do
        let_it_be(:read_api_pat) { create(:personal_access_token, user: user, scopes: [:read_api]) }
        let_it_be(:api_pat) { create(:personal_access_token, user: user, scopes: [:api]) }
        let_it_be(:read_user_pat) { create(:personal_access_token, user: user, scopes: [:read_user]) }

        it 'accepts a read_api token sent in the PRIVATE-TOKEN header' do
          post api('/orbit/mcp'), headers: { 'PRIVATE-TOKEN' => read_api_pat.token }, params: initialize_params

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'accepts a read_api token sent in the Authorization header' do
          post api('/orbit/mcp'), headers: { 'Authorization' => "Bearer #{read_api_pat.token}" },
            params: initialize_params

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'accepts a read_api token sent in the access_token query parameter' do
          post api('/orbit/mcp', access_token: read_api_pat), params: initialize_params

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'accepts an api token, which is a superset of read_api' do
          post api('/orbit/mcp'), headers: { 'PRIVATE-TOKEN' => api_pat.token }, params: initialize_params

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'rejects a read_user token' do
          post api('/orbit/mcp'), headers: { 'PRIVATE-TOKEN' => read_user_pat.token }, params: initialize_params

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with a group access token' do
        let_it_be(:group_access_token) do
          create(:resource_access_token, resource: group, access_level: Gitlab::Access::REPORTER,
            scopes: [:read_api])
        end

        before do
          stub_feature_flags(knowledge_graph: group_access_token.user)
        end

        it 'accepts a read_api token sent in the PRIVATE-TOKEN header' do
          post api('/orbit/mcp'), headers: { 'PRIVATE-TOKEN' => group_access_token.token },
            params: initialize_params

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'accepts a read_api token sent in the Authorization header' do
          post api('/orbit/mcp'), headers: { 'Authorization' => "Bearer #{group_access_token.token}" },
            params: initialize_params

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when the requesting user is not entitled to Orbit' do
        let_it_be(:unentitled_user) { create(:user) }

        let_it_be(:read_api_pat) { create(:personal_access_token, user: unentitled_user, scopes: [:read_api]) }
        let_it_be(:read_user_pat) { create(:personal_access_token, user: unentitled_user, scopes: [:read_user]) }

        it 'returns not found for an accepted scope' do
          post api('/orbit/mcp'), headers: { 'PRIVATE-TOKEN' => read_api_pat.token }, params: initialize_params

          expect(response).to have_gitlab_http_status(:not_found)
        end

        it 'returns insufficient_scope for a rejected scope', :aggregate_failures do
          post api('/orbit/mcp'), headers: { 'PRIVATE-TOKEN' => read_user_pat.token }, params: initialize_params

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['error']).to eq('insufficient_scope')
        end
      end

      context 'when authenticated with a session and no access token' do
        before do
          login_as(user)
        end

        it 'returns unauthorized with a WWW-Authenticate challenge', :aggregate_failures do
          post api('/orbit/mcp'), params: initialize_params

          metadata_url = "#{Gitlab.config.gitlab.url}/.well-known/oauth-protected-resource/api/v4/orbit/mcp"
          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(response.headers['WWW-Authenticate'])
            .to eq(%(Bearer realm="GitLab", resource_metadata="#{metadata_url}"))
        end
      end

      context 'when required jsonrpc param is missing' do
        it 'returns JSON-RPC Invalid Request error' do
          post api('/orbit/mcp', user, oauth_access_token: access_token), params: { id: '1', method: 'initialize' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32600)
          expect(json_response['error']['data']['validations']).to include('jsonrpc is missing')
        end
      end

      context 'when required jsonrpc param is empty' do
        it 'returns JSON-RPC Invalid Request error' do
          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '', method: 'initialize', id: '1' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32600)
          expect(json_response['error']['data']['validations']).to include('jsonrpc is empty')
        end
      end

      context 'when required jsonrpc param is invalid value' do
        it 'returns JSON-RPC Invalid Request error' do
          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '1.0', method: 'initialize', id: '1' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32600)
          expect(json_response['error']['data']['validations']).to include('jsonrpc does not have a valid value')
        end
      end

      context 'when required method param is missing' do
        it 'returns JSON-RPC Invalid Request error' do
          post api('/orbit/mcp', user, oauth_access_token: access_token), params: { jsonrpc: '2.0', id: '1' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32600)
          expect(json_response['error']['data']['validations']).to include('method is missing')
        end
      end

      context 'when required method param is empty' do
        it 'returns JSON-RPC Invalid Request error' do
          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: '', id: '1' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32600)
          expect(json_response['error']['data']['validations']).to include('method is empty')
        end
      end

      context 'when optional id param is empty' do
        it 'returns JSON-RPC Invalid Request error' do
          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'initialize', id: '' }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32600)
          expect(json_response['error']['data']['validations']).to include('id is empty')
        end
      end

      context 'when method does not exist' do
        it 'returns JSON-RPC Method not found error' do
          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'unknown/method', id: '1' }

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['error']['code']).to eq(-32601)
          expect(json_response['error']['message']).to eq('Method not found')
        end
      end

      context 'when notifications/initialized is sent without id' do
        it 'returns empty body' do
          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'notifications/initialized' }

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end

      describe 'tools/list' do
        let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }
        let(:grpc_tools) do
          [
            {
              name: 'query_graph',
              description: 'Query the knowledge graph',
              parameters: { 'type' => 'object', 'properties' => { 'query' => { 'type' => 'string' } } }
            },
            {
              name: 'get_graph_schema',
              description: 'Get the graph schema',
              parameters: { 'type' => 'object' }
            },
            {
              name: 'list_commands',
              description: 'List Orbit commands',
              parameters: { 'type' => 'object' }
            },
            {
              name: 'invoke_command',
              description: 'Invoke an Orbit command',
              parameters: { 'type' => 'object' }
            }
          ]
        end

        before do
          allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
        end

        it 'returns only the command wrapper tools from gRPC' do
          allow(grpc_client).to receive(:list_tools)
            .with(user: user,
              request_context: having_attributes(source_type: Analytics::KnowledgeGraph::SourceType::MCP))
            .and_return(grpc_tools)

          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/list', id: '1' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['result']['tools'].pluck('name')).to eq(%w[list_commands invoke_command])
          expect(json_response['result']['tools'].first['inputSchema']).to be_present
        end

        it 'uses dws source_type when ai_workflows scope is present' do
          dws_access_token = create(:oauth_access_token, user: user, scopes: [:mcp_orbit, :ai_workflows])

          allow(grpc_client).to receive(:list_tools)
            .with(user: user,
              request_context: having_attributes(source_type: Analytics::KnowledgeGraph::SourceType::DWS))
            .and_return(grpc_tools)

          post api('/orbit/mcp', user, oauth_access_token: dws_access_token),
            params: { jsonrpc: '2.0', method: 'tools/list', id: '1' }

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when access_token is nil (session-authenticated user)' do
          before do
            allow(::Analytics::KnowledgeGraph::SourceType).to receive(:for_mcp_request)
              .and_return(Analytics::KnowledgeGraph::SourceType::MCP)
            allow(grpc_client).to receive(:list_tools)
              .with(user: user,
                request_context: having_attributes(source_type: Analytics::KnowledgeGraph::SourceType::MCP))
              .and_return(grpc_tools)
          end

          it 'delegates to SourceType.for_mcp_request' do
            post api('/orbit/mcp', user, oauth_access_token: access_token),
              params: { jsonrpc: '2.0', method: 'tools/list', id: '1' }

            expect(::Analytics::KnowledgeGraph::SourceType).to have_received(:for_mcp_request)
            expect(grpc_client).to have_received(:list_tools)
              .with(user: user,
                request_context: having_attributes(source_type: Analytics::KnowledgeGraph::SourceType::MCP))
          end
        end
      end

      describe 'tools/call' do
        let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

        before do
          allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)

          auth_context = instance_double(
            Analytics::KnowledgeGraph::AuthorizationContext, has_enabled_namespaces?: true
          )
          allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_return(auth_context)
        end

        it 'returns Workhorse SendData when invoke_command dispatches query_graph' do
          allow(Gitlab::Workhorse).to receive(:send_orbit_query)
            .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test-encoded-data'])

          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'invoke_command',
                                arguments: { command_name: 'query_graph',
                                             parameters: { query: 'pipelines' } } } }

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.headers['Gitlab-Workhorse-Send-Data']).to start_with('orbit-query:')
          # Body content depends on whether Workhorse SendData middleware is active;
          # the SendData header is the meaningful assertion.
        end

        it 'passes dws source_type to Workhorse when ai_workflows scope is present' do
          dws_access_token = create(:oauth_access_token, user: user, scopes: [:mcp_orbit, :ai_workflows])

          allow(Gitlab::Workhorse).to receive(:send_orbit_query)
            .with(hash_including(
              request_context: having_attributes(source_type: Analytics::KnowledgeGraph::SourceType::DWS)))
            .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test-encoded-data'])

          post api('/orbit/mcp', user, oauth_access_token: dws_access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'invoke_command',
                                arguments: { command_name: 'query_graph',
                                             parameters: { query: 'pipelines' } } } }

          expect(response).to have_gitlab_http_status(:ok)
        end

        it 'returns result from gRPC on success for invoke_command' do
          allow(grpc_client).to receive(:invoke_agent_command)
            .with(hash_including(command_name: 'get_query_dsl', user: user))
            .and_return({ formatted_text: 'dsl text' })

          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'invoke_command',
                                arguments: { command_name: 'get_query_dsl', parameters: {} } } }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['result']['isError']).to be(false)
        end

        it 'passes X-Duo-Workflow-Session-Id to Workhorse when invoke_command dispatches query_graph' do
          allow(Gitlab::Workhorse).to receive(:send_orbit_query)
            .with(hash_including(request_context: having_attributes(session_id: 'workflow-xyz-789')))
            .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test-encoded-data'])

          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'invoke_command',
                                arguments: { command_name: 'query_graph',
                                             parameters: { query: 'pipelines' } } } },
            headers: { 'X-Duo-Workflow-Session-Id' => 'workflow-xyz-789' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
            .with(hash_including(request_context: having_attributes(session_id: 'workflow-xyz-789')))
        end

        it 'extracts X-Duo-Workflow-Session-Id header and passes to gRPC for list_commands' do
          allow(grpc_client).to receive(:list_agent_commands)
            .with(hash_including(request_context: having_attributes(session_id: 'workflow-xyz-789')))
            .and_return({ formatted_text: 'commands' })

          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'list_commands', arguments: {} } },
            headers: { 'X-Duo-Workflow-Session-Id' => 'workflow-xyz-789' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(grpc_client).to have_received(:list_agent_commands)
            .with(hash_including(request_context: having_attributes(session_id: 'workflow-xyz-789')))
        end

        it 'passes nil session_id when X-Duo-Workflow-Session-Id header is absent' do
          allow(Gitlab::Workhorse).to receive(:send_orbit_query)
            .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test-encoded-data'])

          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'invoke_command',
                                arguments: { command_name: 'query_graph',
                                             parameters: { query: 'pipelines' } } } }

          expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
            .with(hash_including(request_context: having_attributes(session_id: nil)))
        end

        it 'forwards User-Agent to Workhorse when invoke_command dispatches query_graph' do
          allow(Gitlab::Workhorse).to receive(:send_orbit_query)
            .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
            .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test-encoded-data'])

          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'invoke_command',
                                arguments: { command_name: 'query_graph',
                                             parameters: { query: 'pipelines' } } } },
            headers: { 'User-Agent' => 'TestAgent/1.0' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
            .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
        end

        it 'forwards User-Agent to gRPC for list_commands' do
          allow(grpc_client).to receive(:list_agent_commands)
            .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
            .and_return({ formatted_text: 'commands' })

          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'list_commands', arguments: {} } },
            headers: { 'User-Agent' => 'TestAgent/1.0' }

          expect(response).to have_gitlab_http_status(:ok)
          expect(grpc_client).to have_received(:list_agent_commands)
            .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
        end

        it 'rejects removed legacy tools' do
          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'query_graph', arguments: { query: 'pipelines' } } }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32602)
        end

        it 'rejects unknown tools' do
          post api('/orbit/mcp', user, oauth_access_token: access_token),
            params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                      params: { name: 'unknown_tool', arguments: {} } }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['error']['code']).to eq(-32602)
        end
      end

      describe 'rate limiting', :clean_gitlab_redis_rate_limiting do
        let(:current_user) { user }

        let(:query_graph_params) do
          { jsonrpc: '2.0', method: 'tools/call', id: '1',
            params: { name: 'invoke_command',
                      arguments: { command_name: 'query_graph', parameters: { query: 'pipelines' } } } }
        end

        before do
          allow(Gitlab::Workhorse).to receive(:send_orbit_query)
            .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test-encoded-data'])

          auth_context = instance_double(
            Analytics::KnowledgeGraph::AuthorizationContext, has_enabled_namespaces?: true
          )
          allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_return(auth_context)
        end

        it_behaves_like 'rate limited endpoint', rate_limit_key: :orbit_query, use_second_scope: false do
          def request
            post api('/orbit/mcp', current_user, oauth_access_token: access_token), params: query_graph_params
          end
        end

        context 'when the tools/call does not dispatch query_graph' do
          it 'does not apply the orbit_query rate limit to list_commands' do
            allow_next_instance_of(Analytics::KnowledgeGraph::GrpcClient) do |client|
              allow(client).to receive(:list_agent_commands).and_return({ formatted_text: 'commands' })
            end
            expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?).with(:orbit_query, any_args)

            post api('/orbit/mcp', current_user, oauth_access_token: access_token),
              params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                        params: { name: 'list_commands', arguments: {} } }

            expect(response).to have_gitlab_http_status(:ok)
          end

          it 'does not apply the orbit_query rate limit to invoke_command with another command' do
            allow_next_instance_of(Analytics::KnowledgeGraph::GrpcClient) do |client|
              allow(client).to receive(:invoke_agent_command).and_return({ formatted_text: 'dsl text' })
            end
            expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?).with(:orbit_query, any_args)

            post api('/orbit/mcp', current_user, oauth_access_token: access_token),
              params: { jsonrpc: '2.0', method: 'tools/call', id: '1',
                        params: { name: 'invoke_command',
                                  arguments: { command_name: 'get_query_dsl', parameters: {} } } }

            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context 'when the method is not tools/call' do
          it 'does not apply the orbit_query rate limit to initialize' do
            expect(Gitlab::ApplicationRateLimiter).not_to receive(:throttled?).with(:orbit_query, any_args)

            post api('/orbit/mcp', current_user, oauth_access_token: access_token), params: initialize_params

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end
    end

    context 'with granular token authorization' do
      before do
        stub_feature_flags(knowledge_graph: user)
      end

      context 'when the token is granular' do
        let(:granular_permission) do
          ::Authz::PermissionGroups::Assignable.for_permission(:execute_orbit_mcp_tool).first.name
        end

        let(:granular_pat) do
          create(:granular_pat, user: user, boundary: ::Authz::Boundary.for(:user),
            permissions: [granular_permission])
        end

        it 'clears scope enforcement without carrying an accepted scope', :aggregate_failures do
          expect(granular_pat.scopes).to eq(['granular'])

          post api('/orbit/mcp'), headers: { 'Authorization' => "Bearer #{granular_pat.token}" },
            params: initialize_params

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      it_behaves_like 'authorizing granular token permissions', :execute_orbit_mcp_tool,
        legacy_token_scopes: [:mcp_orbit] do
        let(:boundary_object) { :user }
        let(:request) do
          post api('/orbit/mcp'), headers: { 'Authorization' => "Bearer #{pat.token}" }, params: initialize_params
        end
      end
    end
  end

  describe 'GET /orbit/mcp' do
    context 'when unauthenticated' do
      it 'returns authentication error' do
        get api('/orbit/mcp')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end

      it 'returns a WWW-Authenticate challenge pointing at the resource metadata', :aggregate_failures do
        get api('/orbit/mcp')

        metadata_url = "#{Gitlab.config.gitlab.url}/.well-known/oauth-protected-resource/api/v4/orbit/mcp"
        expect(response).to have_gitlab_http_status(:unauthorized)
        expect(response.headers['WWW-Authenticate'])
          .to eq(%(Bearer realm="GitLab", resource_metadata="#{metadata_url}"))
      end
    end

    context 'when authenticated' do
      before do
        stub_feature_flags(knowledge_graph: user)
      end

      it 'returns method not allowed' do
        get api('/orbit/mcp', user, oauth_access_token: access_token)

        expect(response).to have_gitlab_http_status(:method_not_allowed)
      end

      context 'when access token has read_api scope' do
        let(:read_api_access_token) { create(:oauth_access_token, user: user, scopes: [:read_api]) }

        it 'returns method not allowed' do
          get api('/orbit/mcp', user, oauth_access_token: read_api_access_token)

          expect(response).to have_gitlab_http_status(:method_not_allowed)
        end
      end
    end

    context 'with granular token authorization' do
      before do
        stub_feature_flags(knowledge_graph: user)
      end

      it_behaves_like 'authorizing granular token permissions', :execute_orbit_mcp_tool,
        expected_success_status: :method_not_allowed, legacy_token_scopes: [:mcp_orbit] do
        let(:boundary_object) { :user }
        let(:request) { get api('/orbit/mcp'), headers: { 'Authorization' => "Bearer #{pat.token}" } }
      end
    end
  end
end
