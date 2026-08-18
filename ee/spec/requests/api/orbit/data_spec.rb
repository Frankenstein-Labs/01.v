# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Orbit::Data, :clean_gitlab_redis_rate_limiting, feature_category: :knowledge_graph do
  let_it_be(:user) { create(:user) }

  before do
    stub_feature_flags(knowledge_graph: true)
    stub_licensed_features(orbit: true)
    stub_config(knowledge_graph: { 'enabled' => true })
  end

  shared_examples 'requires authentication' do
    context 'when not authenticated' do
      it 'returns 401' do
        send_request(user: nil)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end
  end

  shared_examples 'requires knowledge_graph feature flag' do
    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(knowledge_graph: false)
      end

      it 'returns 404' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  shared_examples 'requires :orbit licensed feature' do
    context 'when :orbit licensed feature is not available' do
      before do
        stub_licensed_features(orbit: false)
      end

      it 'returns 403' do
        send_request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end

  shared_examples 'maps gRPC error codes to HTTP statuses' do |grpc_method|
    using RSpec::Parameterized::TableSyntax

    where(:grpc_code, :http_status) do
      GRPC::Core::StatusCodes::DEADLINE_EXCEEDED | :gateway_timeout
      GRPC::Core::StatusCodes::PERMISSION_DENIED | :not_found
      GRPC::Core::StatusCodes::INVALID_ARGUMENT  | :bad_request
      GRPC::Core::StatusCodes::NOT_FOUND         | :not_found
      GRPC::Core::StatusCodes::UNAVAILABLE       | :service_unavailable
      GRPC::Core::StatusCodes::INTERNAL          | :internal_server_error
    end

    with_them do
      before do
        allow(grpc_client).to receive(grpc_method)
          .and_raise(Analytics::KnowledgeGraph::GrpcClient::ConnectionError.new('boom', grpc_code: grpc_code))
      end

      it 'returns the mapped status and echoes the gRPC code header', :aggregate_failures do
        send_request

        expect(response).to have_gitlab_http_status(http_status)
        expect(response.headers['X-GKG-Grpc-Code']).to eq(grpc_code.to_s)
        expect(json_response).to eq('code' => grpc_code, 'message' => 'Knowledge graph request failed')
      end
    end
  end

  describe 'POST /orbit/query' do
    include WorkhorseHelpers

    let(:current_user) { user }
    let(:query) { { nodes: ['MergeRequest'] } }
    let(:params) { { query: query } }
    let(:endpoint) { 'localhost:50054' }
    let(:jwt_token) { 'test-jwt-token' }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:configured_endpoint).and_return(endpoint)
      allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
        .and_return(Analytics::KnowledgeGraph::SourceType::REST)
      allow(Analytics::KnowledgeGraph::JwtAuth).to receive(:generate_token)
        .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST, session_id: nil)
        .and_return(jwt_token)
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:secure_channel?).with(endpoint).and_return(false)

      auth_context = instance_double(Analytics::KnowledgeGraph::AuthorizationContext, has_enabled_namespaces?: true)
      allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_return(auth_context)
    end

    def send_request(user: self.user, request_params: params)
      post api('/orbit/query', user), params: request_params
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) do
        post api('/orbit/query', personal_access_token: pat), params: params
      end
    end

    context 'with OAuth token scope' do
      where(:description, :auth_setup, :expected_status) do
        [
          ['read_api OAuth token', -> { create(:oauth_access_token, user: user, scopes: [:read_api]) }, :ok],
          ['api OAuth token', -> { create(:oauth_access_token, user: user, scopes: [:api]) }, :ok],
          ['ai_workflows OAuth token', -> { create(:oauth_access_token, user: user, scopes: [:ai_workflows]) }, :ok],
          ['read_user OAuth token (insufficient)', -> { create(:oauth_access_token, user: user, scopes: [:read_user]) },
            :forbidden]
        ]
      end

      with_them do
        it 'enforces access control correctly' do
          token = instance_exec(&auth_setup)
          post api('/orbit/query', oauth_access_token: token), params: params

          # A read_api-scoped token must not be rejected with 403 insufficient_scope.
          # The exact success status depends on namespace/FF configuration, but the
          # scope check must pass (i.e. not return forbidden due to insufficient scope).
          if expected_status == :ok
            expect(response).not_to have_gitlab_http_status(:forbidden)
          else
            expect(response).to have_gitlab_http_status(:forbidden)
          end
        end
      end
    end

    it_behaves_like 'rate limited endpoint', rate_limit_key: :orbit_query, use_second_scope: false do
      def request
        post api('/orbit/query', current_user), params: params
      end
    end

    context 'when authenticated' do
      it 'returns a Workhorse SendData response' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)

        type, params = workhorse_send_data
        expect(type).to eq('orbit-query')
        expect(params).to include(
          'GkgServer' => a_hash_including(
            'address' => endpoint,
            'tls' => false,
            'headers' => a_hash_including('authorization' => "Bearer #{jwt_token}")
          ),
          'Query' => query.to_json,
          'Format' => 'raw'
        )
      end

      it 'supports llm response format' do
        send_request(request_params: params.merge(response_format: 'llm'))

        expect(response).to have_gitlab_http_status(:ok)

        _, params = workhorse_send_data
        expect(params['Format']).to eq('llm')
      end

      it 'forwards User-Agent to Workhorse headers' do
        post api('/orbit/query', user), params: params, headers: { 'User-Agent' => 'TestAgent/1.0' }

        expect(response).to have_gitlab_http_status(:ok)
        _, decoded_params = workhorse_send_data
        expect(decoded_params.dig('GkgServer', 'headers')).to include('x-client-user-agent' => 'TestAgent/1.0')
      end

      context 'when query param is missing' do
        it 'returns 400' do
          send_request(request_params: {})

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when JWT generation raises AuthorizationError' do
        before do
          allow(Analytics::KnowledgeGraph::JwtAuth).to receive(:generate_token)
            .and_raise(Analytics::KnowledgeGraph::GrpcClient::AuthorizationError, 'JWT generation failed')
        end

        it 'returns 503' do
          send_request

          expect(response).to have_gitlab_http_status(:service_unavailable)
        end
      end

      context 'when user has no enabled namespaces' do
        before do
          auth_context = instance_double(Analytics::KnowledgeGraph::AuthorizationContext)
          allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new)
            .with(user).and_return(auth_context)
          allow(auth_context).to receive(:has_enabled_namespaces?).and_return(false)
        end

        it 'returns 403' do
          send_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with source_type param' do
        before do
          allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request).and_call_original
        end

        context 'when request is CSRF-authenticated and source_type is code_intelligence' do
          before do
            allow(Analytics::KnowledgeGraph::SourceType).to receive(:frontend_request?).and_return(true)
            allow(Analytics::KnowledgeGraph::JwtAuth).to receive(:generate_token)
              .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::CODE_INTELLIGENCE,
                session_id: nil)
              .and_return(jwt_token)
          end

          it 'passes code_intelligence to Workhorse' do
            send_request(request_params: params.merge(source_type: 'code_intelligence'))

            expect(response).to have_gitlab_http_status(:ok)
            expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
              .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::CODE_INTELLIGENCE,
                session_id: nil)
          end
        end

        context 'when request is not CSRF-authenticated and source_type is code_intelligence' do
          before do
            allow(Analytics::KnowledgeGraph::SourceType).to receive(:frontend_request?).and_return(false)
          end

          it 'ignores the param and falls back to rest' do
            send_request(request_params: params.merge(source_type: 'code_intelligence'))

            expect(response).to have_gitlab_http_status(:ok)
            expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
              .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST, session_id: nil)
          end
        end

        context 'when request is CSRF-authenticated and source_type is not in FRONTEND_SUBTYPES' do
          before do
            allow(Analytics::KnowledgeGraph::SourceType).to receive(:frontend_request?).and_return(true)
            allow(Analytics::KnowledgeGraph::JwtAuth).to receive(:generate_token)
              .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::FRONTEND, session_id: nil)
              .and_return(jwt_token)
          end

          it 'falls back to frontend' do
            send_request(request_params: params.merge(source_type: 'mcp'))

            expect(response).to have_gitlab_http_status(:ok)
            expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
              .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::FRONTEND, session_id: nil)
          end
        end
      end
    end
  end

  describe 'POST /orbit/query/:name' do
    include WorkhorseHelpers

    let(:current_user) { user }
    let(:query_name) { 'expand_neighbors' }
    let(:params) { { parameters: { entity: 'User', node_ids: [1], limit: 50 } } }
    let(:endpoint) { 'localhost:50054' }
    let(:jwt_token) { 'test-jwt-token' }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:configured_endpoint).and_return(endpoint)
      allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
        .and_return(Analytics::KnowledgeGraph::SourceType::REST)
      allow(Analytics::KnowledgeGraph::JwtAuth).to receive(:generate_token)
        .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST, session_id: nil)
        .and_return(jwt_token)
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:secure_channel?).with(endpoint).and_return(false)

      auth_context = instance_double(Analytics::KnowledgeGraph::AuthorizationContext, has_enabled_namespaces?: true)
      allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_return(auth_context)
    end

    def send_request(user: self.user, request_params: params)
      post api("/orbit/query/#{query_name}", user),
        params: request_params.to_json,
        headers: { 'CONTENT_TYPE' => 'application/json' }
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) do
        post api("/orbit/query/#{query_name}", personal_access_token: pat),
          params: params.to_json,
          headers: { 'CONTENT_TYPE' => 'application/json' }
      end
    end

    it_behaves_like 'rate limited endpoint', rate_limit_key: :orbit_query, use_second_scope: false do
      def request
        post api("/orbit/query/#{query_name}", current_user),
          params: params.to_json,
          headers: { 'CONTENT_TYPE' => 'application/json' }
      end
    end

    context 'when authenticated' do
      it 'returns a Workhorse SendData response carrying the named query envelope' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)

        type, decoded = workhorse_send_data
        expect(type).to eq('orbit-query')
        expect(decoded).to include(
          'GkgServer' => a_hash_including(
            'address' => endpoint,
            'headers' => a_hash_including('authorization' => "Bearer #{jwt_token}")
          ),
          'Query' => { name: 'expand_neighbors',
                       parameters: { entity: 'User', node_ids: [1], limit: 50 } }.to_json,
          'QueryType' => 'named',
          'Format' => 'raw'
        )
      end

      it 'defaults parameters to an empty object' do
        send_request(request_params: {})

        expect(response).to have_gitlab_http_status(:ok)

        _, decoded = workhorse_send_data
        expect(decoded['Query']).to eq({ name: 'expand_neighbors', parameters: {} }.to_json)
      end

      it 'supports llm response format' do
        send_request(request_params: params.merge(response_format: 'llm'))

        expect(response).to have_gitlab_http_status(:ok)

        _, decoded = workhorse_send_data
        expect(decoded['Format']).to eq('llm')
      end

      context 'when the request body is form-encoded' do
        it 'returns 400 telling the caller to send JSON' do
          post api("/orbit/query/#{query_name}", user), params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to include('JSON request body required')
        end
      end

      context 'with source_type param' do
        before do
          allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request).and_call_original
        end

        context 'when request is CSRF-authenticated and source_type is code_intelligence' do
          before do
            allow(Analytics::KnowledgeGraph::SourceType).to receive(:frontend_request?).and_return(true)
            allow(Analytics::KnowledgeGraph::JwtAuth).to receive(:generate_token)
              .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::CODE_INTELLIGENCE,
                session_id: nil)
              .and_return(jwt_token)
          end

          it 'passes code_intelligence to Workhorse' do
            send_request(request_params: params.merge(source_type: 'code_intelligence'))

            expect(response).to have_gitlab_http_status(:ok)
            expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
              .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::CODE_INTELLIGENCE,
                session_id: nil)
          end
        end

        context 'when request is not CSRF-authenticated and source_type is code_intelligence' do
          before do
            allow(Analytics::KnowledgeGraph::SourceType).to receive(:frontend_request?).and_return(false)
          end

          it 'ignores the param and falls back to rest' do
            send_request(request_params: params.merge(source_type: 'code_intelligence'))

            expect(response).to have_gitlab_http_status(:ok)
            expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:generate_token)
              .with(user: user, source_type: Analytics::KnowledgeGraph::SourceType::REST, session_id: nil)
          end
        end
      end

      context 'when user has no enabled namespaces' do
        before do
          auth_context = instance_double(Analytics::KnowledgeGraph::AuthorizationContext)
          allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new)
            .with(user).and_return(auth_context)
          allow(auth_context).to receive(:has_enabled_namespaces?).and_return(false)
        end

        it 'returns 403' do
          send_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe 'GET /orbit/schema' do
    let(:schema_result) do
      { schema_version: '1.0', domains: [], nodes: [], edges: [] }
    end

    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(grpc_client).to receive(:get_graph_schema).and_return(schema_result)
    end

    def send_request(user: self.user, request_params: {})
      get api('/orbit/schema', user), params: request_params
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) { get api('/orbit/schema', personal_access_token: pat) }
    end

    context 'when authenticated' do
      it 'returns the schema' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include('schema_version' => '1.0')
      end

      it 'passes expand nodes to the grpc client' do
        send_request(request_params: { expand: 'MergeRequest, Issue' })

        expect(grpc_client).to have_received(:get_graph_schema).with(
          hash_including(
            user: user,
            expand_nodes: %w[MergeRequest Issue],
            format: :raw
          )
        )
      end

      it 'supports llm response format' do
        send_request(request_params: { response_format: 'llm' })

        expect(grpc_client).to have_received(:get_graph_schema).with(
          hash_including(format: :llm)
        )
      end

      it 'forwards User-Agent to grpc client' do
        get api('/orbit/schema', user), headers: { 'User-Agent' => 'TestAgent/1.0' }

        expect(grpc_client).to have_received(:get_graph_schema)
          .with(hash_including(
            request_context: having_attributes(user_agent: 'TestAgent/1.0')
          ))
      end

      context 'when using an OAuth access token' do
        let(:oauth_token) { create(:oauth_access_token, user: user, scopes: [:api]) }

        before do
          allow(::Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
            .with(hash_including(oauth_access_token: oauth_token))
            .and_return(Analytics::KnowledgeGraph::SourceType::REST)
        end

        it 'passes the OAuth token to for_orbit_request' do
          get api('/orbit/schema', user, oauth_access_token: oauth_token)

          expect(::Analytics::KnowledgeGraph::SourceType).to have_received(:for_orbit_request)
            .with(hash_including(oauth_access_token: oauth_token))
        end
      end

      context 'when grpc client raises ConnectionError' do
        it_behaves_like 'maps gRPC error codes to HTTP statuses', :get_graph_schema
      end
    end
  end

  shared_examples 'an Orbit schema command endpoint' do |endpoint_path, command_name|
    let(:schema_command_endpoint_path) { endpoint_path }
    let(:command_result) { { formatted_text: "#{command_name} text" } }
    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
        .and_return(Analytics::KnowledgeGraph::SourceType::REST)
      allow(grpc_client).to receive(:invoke_agent_command).and_return(command_result)
    end

    def send_request(user: self.user, request_params: {}, headers: {})
      get api(schema_command_endpoint_path, user), params: request_params, headers: headers
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) { get api(schema_command_endpoint_path, personal_access_token: pat) }
    end

    it 'invokes the backing schema command' do
      send_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to eq('formatted_text' => "#{command_name} text")
      expect(grpc_client).to have_received(:invoke_agent_command).with(
        hash_including(
          command_name: command_name,
          parameters: { 'format' => 'raw' },
          user: user
        )
      )
    end

    it 'supports llm response format' do
      send_request(request_params: { response_format: 'llm' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(grpc_client).to have_received(:invoke_agent_command).with(
        hash_including(command_name: command_name, parameters: { 'format' => 'llm' })
      )
    end

    it 'forwards the Duo workflow session id to gRPC' do
      send_request(headers: { 'X-Duo-Workflow-Session-Id' => 'workflow-rest-123' })

      expect(grpc_client).to have_received(:invoke_agent_command)
        .with(hash_including(
          request_context: having_attributes(session_id: 'workflow-rest-123')
        ))
    end

    it 'forwards User-Agent to grpc client' do
      send_request(headers: { 'User-Agent' => 'TestAgent/1.0' })

      expect(grpc_client).to have_received(:invoke_agent_command)
        .with(hash_including(
          request_context: having_attributes(user_agent: 'TestAgent/1.0')
        ))
    end
  end

  describe 'GET /orbit/schema/dsl' do
    let(:dsl_result) { { 'title' => 'GraphQueryAsJSON', 'version' => '1.2.0' } }
    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
        .and_return(Analytics::KnowledgeGraph::SourceType::REST)
      allow(grpc_client).to receive(:get_query_dsl).and_return(dsl_result)
    end

    def send_request(user: self.user, request_params: {}, headers: {})
      get api('/orbit/schema/dsl', user), params: request_params, headers: headers
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) { get api('/orbit/schema/dsl', personal_access_token: pat) }
    end

    it 'serves the DSL through the dedicated GetQueryDsl gRPC method' do
      send_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to eq(dsl_result)
      expect(grpc_client).to have_received(:get_query_dsl).with(
        hash_including(user: user, format: :raw)
      )
    end

    it 'supports llm response format' do
      send_request(request_params: { response_format: 'llm' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(grpc_client).to have_received(:get_query_dsl).with(hash_including(format: :llm))
    end

    it 'forwards the Duo workflow session id to gRPC' do
      send_request(headers: { 'X-Duo-Workflow-Session-Id' => 'workflow-rest-123' })

      expect(grpc_client).to have_received(:get_query_dsl)
        .with(hash_including(request_context: having_attributes(session_id: 'workflow-rest-123')))
    end

    it 'forwards User-Agent to grpc client' do
      send_request(headers: { 'User-Agent' => 'TestAgent/1.0' })

      expect(grpc_client).to have_received(:get_query_dsl)
        .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
    end

    context 'when grpc client raises ConnectionError' do
      it_behaves_like 'maps gRPC error codes to HTTP statuses', :get_query_dsl
    end
  end

  describe 'GET /orbit/query/templates' do
    let(:templates_result) do
      [
        {
          name: 'my_neighbors',
          description: 'Immediate graph neighborhood of the current user.',
          raw_query: { 'query_type' => 'neighbors', 'limit' => 100 }
        }
      ]
    end

    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
        .and_return(Analytics::KnowledgeGraph::SourceType::REST)
      allow(grpc_client).to receive(:list_named_queries).and_return(templates_result)
    end

    def send_request(user: self.user, request_params: {}, headers: {})
      get api('/orbit/query/templates', user), params: request_params, headers: headers
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) { get api('/orbit/query/templates', personal_access_token: pat) }
    end

    it 'serves the catalog through the ListNamedQueries gRPC method' do
      send_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to eq(templates_result.map(&:deep_stringify_keys))
      expect(grpc_client).to have_received(:list_named_queries).with(
        hash_including(user: user)
      )
    end

    context 'when grpc client raises ConnectionError' do
      it_behaves_like 'maps gRPC error codes to HTTP statuses', :list_named_queries
    end
  end

  describe 'GET /orbit/schema/format' do
    it_behaves_like 'an Orbit schema command endpoint', '/orbit/schema/format', 'get_response_format'
  end

  describe 'GET /orbit/status' do
    let(:health_result) do
      { status: 'healthy', timestamp: '2026-01-01', version: '1.0', components: [] }
    end

    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(grpc_client).to receive(:get_cluster_health).and_return(health_result)
    end

    def send_request(user: self.user, request_params: {})
      get api('/orbit/status', user), params: request_params
    end

    include_examples 'requires authentication'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) { get api('/orbit/status', personal_access_token: pat) }
    end

    context 'when the user has access' do
      it 'returns 200 with available true and system health', :aggregate_failures do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['user']).to eq('available' => true)
        expect(json_response['system']).to include('status' => 'healthy')
      end

      it 'supports llm response format' do
        send_request(request_params: { response_format: 'llm' })

        expect(grpc_client).to have_received(:get_cluster_health).with(
          hash_including(format: :llm)
        )
      end

      it 'forwards User-Agent to grpc client' do
        get api('/orbit/status', user), headers: { 'User-Agent' => 'TestAgent/1.0' }

        expect(grpc_client).to have_received(:get_cluster_health)
          .with(hash_including(
            request_context: having_attributes(user_agent: 'TestAgent/1.0')
          ))
      end

      context 'when grpc service is unreachable' do
        before do
          allow(grpc_client).to receive(:get_cluster_health)
            .and_return({ status: 'unknown', error: 'Service unreachable' })
        end

        it 'returns 200 with the error status in system', :aggregate_failures do
          send_request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['system']).to include('status' => 'unknown', 'error' => 'Service unreachable')
        end
      end
    end

    shared_examples 'reports no access' do
      it 'returns 200 with available false and no system health', :aggregate_failures do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq('user' => { 'available' => false }, 'system' => nil)
        expect(grpc_client).not_to have_received(:get_cluster_health)
      end
    end

    context 'when the :orbit licensed feature is not available' do
      before do
        stub_licensed_features(orbit: false)
      end

      it_behaves_like 'reports no access'
    end

    context 'when the knowledge_graph feature flag is disabled' do
      before do
        stub_feature_flags(knowledge_graph: false)
      end

      it_behaves_like 'reports no access'
    end
  end

  describe 'GET /orbit/tools' do
    let(:tools_result) do
      [
        { name: 'query_graph', description: 'Query the graph', parameters: {} },
        { name: 'get_graph_schema', description: 'Get the graph schema', parameters: {} },
        { name: 'list_commands', description: 'List Orbit commands', parameters: {} },
        { name: 'invoke_command', description: 'Invoke an Orbit command', parameters: {} },
        { name: 'internal_tool', description: 'Internal GKG tool', parameters: {} }
      ]
    end

    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(grpc_client).to receive(:list_tools).and_return(tools_result)
      allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
        .and_return(Analytics::KnowledgeGraph::SourceType::REST)
    end

    def send_request(user: self.user)
      get api('/orbit/tools', user)
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) { get api('/orbit/tools', personal_access_token: pat) }
    end

    context 'when authenticated' do
      it 'returns only the command wrapper tools' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to be_an(Array)
        expect(json_response.pluck('name')).to eq(%w[list_commands invoke_command])
      end

      it 'passes user to grpc client' do
        send_request

        expect(grpc_client).to have_received(:list_tools)
          .with(hash_including(user: user))
      end

      it 'forwards User-Agent to grpc client' do
        get api('/orbit/tools', user), headers: { 'User-Agent' => 'TestAgent/1.0' }

        expect(grpc_client).to have_received(:list_tools)
          .with(hash_including(
            request_context: having_attributes(user_agent: 'TestAgent/1.0')
          ))
      end

      context 'when grpc client raises ConnectionError' do
        it_behaves_like 'maps gRPC error codes to HTTP statuses', :list_tools
      end
    end
  end

  describe 'GET /orbit/agent/commands' do
    let(:commands_result) do
      [{ name: 'get_query_dsl', description: 'Return query DSL', parameters: {} }]
    end

    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(grpc_client).to receive(:list_agent_commands).and_return(commands_result)
      allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
        .and_return(Analytics::KnowledgeGraph::SourceType::REST)
    end

    def send_request(user: self.user, request_params: {}, headers: {})
      get api('/orbit/agent/commands', user), params: request_params, headers: headers
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) { get api('/orbit/agent/commands', personal_access_token: pat) }
    end

    it 'returns available commands' do
      send_request(request_params: { command_names: 'get_query_dsl' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response.first).to include('name' => 'get_query_dsl')
      expect(grpc_client).to have_received(:list_agent_commands)
        .with(hash_including(user: user,
          command_names: ['get_query_dsl'], format: :raw))
    end

    it 'lists every command when command_names is omitted' do
      send_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(grpc_client).to have_received(:list_agent_commands)
        .with(hash_including(user: user,
          command_names: [], format: :raw))
    end

    it 'lists every command when command_names is blank' do
      send_request(request_params: { command_names: ' ' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(grpc_client).to have_received(:list_agent_commands)
        .with(hash_including(user: user,
          command_names: [], format: :raw))
    end

    it 'returns an LLM-formatted command catalog when requested' do
      allow(grpc_client).to receive(:list_agent_commands)
        .and_return({ formatted_text: "commands[1]:\n  - name: get_query_dsl" })

      send_request(request_params: { response_format: 'llm' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response['formatted_text']).to include('commands[1]:')
      expect(json_response['formatted_text']).to include('name: get_query_dsl')
      expect(grpc_client).to have_received(:list_agent_commands)
        .with(hash_including(format: :llm))
    end

    it 'forwards the Duo workflow session id to gRPC' do
      send_request(headers: { 'X-Duo-Workflow-Session-Id' => 'workflow-rest-123' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(grpc_client).to have_received(:list_agent_commands)
        .with(hash_including(
          request_context: having_attributes(session_id: 'workflow-rest-123')
        ))
    end

    it 'forwards User-Agent to grpc client' do
      send_request(headers: { 'User-Agent' => 'TestAgent/1.0' })

      expect(grpc_client).to have_received(:list_agent_commands)
        .with(hash_including(
          request_context: having_attributes(user_agent: 'TestAgent/1.0')
        ))
    end
  end

  describe 'POST /orbit/agent/commands/:name' do
    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }
    let(:command_name) { 'get_query_dsl' }
    let(:params) { { parameters: { format: 'llm' } } }

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(Analytics::KnowledgeGraph::SourceType).to receive(:for_orbit_request)
        .and_return(Analytics::KnowledgeGraph::SourceType::REST)
      allow(grpc_client).to receive(:invoke_agent_command).and_return({})

      auth_context = instance_double(Analytics::KnowledgeGraph::AuthorizationContext, has_enabled_namespaces?: true)
      allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_return(auth_context)
    end

    def send_request(user: self.user, request_params: params, headers: {})
      post api("/orbit/agent/commands/#{command_name}", user), params: request_params, headers: headers
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) do
        post api("/orbit/agent/commands/#{command_name}", personal_access_token: pat), params: params
      end
    end

    it 'invokes generic commands through gRPC' do
      allow(grpc_client).to receive(:invoke_agent_command)
        .and_return({ formatted_text: 'dsl text' })

      send_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to eq('formatted_text' => 'dsl text')
      expect(grpc_client).to have_received(:invoke_agent_command)
        .with(hash_including(command_name: 'get_query_dsl', parameters: { 'format' => 'llm' },
          user: user))
    end

    it 'forwards the Duo workflow session id to gRPC' do
      allow(grpc_client).to receive(:invoke_agent_command)
        .and_return({ formatted_text: 'dsl text' })

      send_request(headers: { 'X-Duo-Workflow-Session-Id' => 'workflow-rest-123' })

      expect(response).to have_gitlab_http_status(:ok)
      expect(grpc_client).to have_received(:invoke_agent_command)
        .with(hash_including(
          request_context: having_attributes(session_id: 'workflow-rest-123')
        ))
    end

    it 'forwards User-Agent to grpc client' do
      send_request(headers: { 'User-Agent' => 'TestAgent/1.0' })

      expect(grpc_client).to have_received(:invoke_agent_command)
        .with(hash_including(
          request_context: having_attributes(user_agent: 'TestAgent/1.0')
        ))
    end

    context 'when query_graph is invoked' do
      let(:command_name) { 'query_graph' }
      let(:params) { { parameters: { query: 'find pipelines' } } }

      before do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .with(hash_including(query: 'find pipelines', user: user, format: :llm))
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])
      end

      it_behaves_like 'rate limited endpoint', rate_limit_key: :orbit_query, use_second_scope: false do
        let(:current_user) { user }

        def request
          post api('/orbit/agent/commands/query_graph', current_user),
            params: { parameters: { query: 'find pipelines' } }
        end
      end

      it 'routes through the existing Workhorse path' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.headers['Gitlab-Workhorse-Send-Data']).to start_with('orbit-query:')
      end

      it 'forwards the Duo workflow session id to Workhorse' do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .with(hash_including(request_context: having_attributes(session_id: 'workflow-rest-123')))
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])

        send_request(headers: { 'X-Duo-Workflow-Session-Id' => 'workflow-rest-123' })

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
          .with(hash_including(request_context: having_attributes(session_id: 'workflow-rest-123')))
      end

      it 'forwards User-Agent to Workhorse' do
        allow(Gitlab::Workhorse).to receive(:send_orbit_query)
          .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
          .and_return(['Gitlab-Workhorse-Send-Data', 'orbit-query:test'])

        send_request(headers: { 'User-Agent' => 'TestAgent/1.0' })

        expect(response).to have_gitlab_http_status(:ok)
        expect(Gitlab::Workhorse).to have_received(:send_orbit_query)
          .with(hash_including(request_context: having_attributes(user_agent: 'TestAgent/1.0')))
      end

      context 'when query is missing' do
        let(:params) { { parameters: {} } }

        it 'returns 400' do
          send_request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'when user has no enabled namespaces' do
        before do
          auth_context = instance_double(Analytics::KnowledgeGraph::AuthorizationContext)
          allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new)
            .with(user).and_return(auth_context)
          allow(auth_context).to receive(:has_enabled_namespaces?).and_return(false)
        end

        it 'returns 403' do
          send_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end
    end
  end

  describe 'GET /orbit/graph_status' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }

    let(:graph_status_result) do
      {
        projects: { indexed: 5, total_known: 10 },
        domains: [
          { name: 'SDLC', items: [{ name: 'MergeRequest', count: 42 }] }
        ],
        indexing: {
          state: 'indexed',
          last_started_at: '2026-04-15T00:00:00Z',
          last_completed_at: '2026-04-15T01:00:00Z',
          last_duration_ms: 3_600_000,
          last_error: nil
        }
      }
    end

    let(:grpc_client) { instance_double(Analytics::KnowledgeGraph::GrpcClient) }

    before_all do
      group.add_reporter(user)
    end

    before do
      allow(Analytics::KnowledgeGraph::GrpcClient).to receive(:new).and_return(grpc_client)
      allow(grpc_client).to receive(:get_graph_status).and_return(graph_status_result)

      auth_context = instance_double(Analytics::KnowledgeGraph::AuthorizationContext, has_enabled_namespaces?: true)
      allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new).and_return(auth_context)
    end

    def send_request(user: self.user, request_params: { namespace_id: group.id })
      get api('/orbit/graph_status', user), params: request_params
    end

    include_examples 'requires authentication'
    include_examples 'requires knowledge_graph feature flag'
    include_examples 'requires :orbit licensed feature'

    it_behaves_like 'authorizing granular token permissions', :read_knowledge_graph do
      let(:boundary_object) { :user }
      let(:request) { get api('/orbit/graph_status', personal_access_token: pat), params: { namespace_id: group.id } }
    end

    context 'when authenticated' do
      it 'returns graph status by namespace_id' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response.keys).to match_array(%w[projects domains indexing])
        expect(json_response).to include(
          'projects' => { 'indexed' => 5, 'total_known' => 10 },
          'indexing' => hash_including('state' => 'indexed')
        )
      end

      it 'forwards traversal_path with organization to grpc client' do
        send_request

        expect(grpc_client).to have_received(:get_graph_status).with(
          hash_including(
            user: user,
            traversal_path: group.traversal_path(with_organization: true),
            target_type: :group,
            format: :raw
          )
        )
      end

      it 'forwards User-Agent to grpc client' do
        get api('/orbit/graph_status', user), params: { namespace_id: group.id },
          headers: { 'User-Agent' => 'TestAgent/1.0' }

        expect(grpc_client).to have_received(:get_graph_status)
          .with(hash_including(
            request_context: having_attributes(user_agent: 'TestAgent/1.0')
          ))
      end

      it 'forwards llm response_format to grpc client' do
        send_request(request_params: { namespace_id: group.id, response_format: 'llm' })

        expect(grpc_client).to have_received(:get_graph_status).with(
          hash_including(format: :llm)
        )
      end

      it 'returns graph status by project_id' do
        send_request(request_params: { project_id: project.id })

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include('projects' => hash_including('indexed' => 5))
        expect(grpc_client).to have_received(:get_graph_status).with(
          hash_including(
            traversal_path: project.project_namespace.traversal_path(with_organization: true),
            target_type: :project
          )
        )
      end

      it 'returns graph status by group full_path' do
        send_request(request_params: { full_path: group.full_path })

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include('projects' => hash_including('indexed' => 5))
        expect(grpc_client).to have_received(:get_graph_status).with(
          hash_including(
            traversal_path: group.traversal_path(with_organization: true),
            target_type: :group
          )
        )
      end

      it 'returns graph status by project full_path' do
        send_request(request_params: { full_path: project.full_path })

        expect(response).to have_gitlab_http_status(:ok)
        expect(grpc_client).to have_received(:get_graph_status).with(
          hash_including(
            traversal_path: project.project_namespace.traversal_path(with_organization: true),
            target_type: :project
          )
        )
      end

      it 'returns 400 when no lookup parameter provided' do
        send_request(request_params: {})

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when multiple lookup parameters provided' do
        send_request(request_params: { namespace_id: group.id, project_id: project.id })

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 404 for non-existent namespace' do
        send_request(request_params: { namespace_id: non_existing_record_id })

        expect(response).to have_gitlab_http_status(:not_found)
      end

      context 'when user is not a member of a private group' do
        let_it_be(:private_group) { create(:group, :private) }

        it 'returns 404 without leaking existence' do
          send_request(request_params: { namespace_id: private_group.id })

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when project_id points to a private project user cannot read' do
        let_it_be(:other_group) { create(:group) }
        let_it_be(:private_project) { create(:project, :private, namespace: other_group) }

        it 'returns 404' do
          send_request(request_params: { project_id: private_project.id })

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when namespace_id points to a user namespace' do
        let_it_be(:user_with_namespace) { create(:user, :with_namespace) }

        it 'returns 404' do
          send_request(request_params: { namespace_id: user_with_namespace.namespace.id })

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when project_id points to a personal project' do
        let_it_be(:user_with_namespace) { create(:user, :with_namespace) }
        let_it_be(:personal_project) { create(:project, namespace: user_with_namespace.namespace) }

        it 'returns 404' do
          send_request(request_params: { project_id: personal_project.id })

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when user has no enabled namespaces' do
        before do
          auth_context = instance_double(Analytics::KnowledgeGraph::AuthorizationContext)
          allow(Analytics::KnowledgeGraph::AuthorizationContext).to receive(:new)
            .with(user).and_return(auth_context)
          allow(auth_context).to receive(:has_enabled_namespaces?).and_return(false)
        end

        it 'returns 403' do
          send_request

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when grpc client raises ConnectionError' do
        it_behaves_like 'maps gRPC error codes to HTTP statuses', :get_graph_status
      end
    end
  end
end
