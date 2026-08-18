# frozen_string_literal: true

module API
  module Orbit
    class Data < ::API::Base
      include ::API::Concerns::AiWorkflowsAccess
      include ::API::Helpers::HeadersHelpers
      include APIGuard

      feature_category :knowledge_graph
      urgency :low

      GRPC_CODE_TO_HTTP_STATUS = {
        ::GRPC::Core::StatusCodes::DEADLINE_EXCEEDED => 504,
        ::GRPC::Core::StatusCodes::PERMISSION_DENIED => 404,
        ::GRPC::Core::StatusCodes::INVALID_ARGUMENT => 400,
        ::GRPC::Core::StatusCodes::NOT_FOUND => 404,
        ::GRPC::Core::StatusCodes::UNAVAILABLE => 503
      }.freeze
      GRPC_DEFAULT_HTTP_STATUS = 500
      GRPC_CODE_HEADER = 'X-GKG-Grpc-Code'
      GRPC_ERROR_MESSAGE = 'Knowledge graph request failed'

      # Although this API endpoint responds to POST requests, it is a read-only operation
      allow_access_with_scope :read_api
      allow_ai_workflows_access

      before do
        authenticate!

        unless route.settings[:skip_orbit_entitlement]
          not_found! unless ::Analytics::KnowledgeGraph.enabled_for?(current_user)
          forbidden! unless ::Analytics::KnowledgeGraph::OrbitLicense.available_for?(current_user)
        end
      end

      helpers do
        def source_type(frontend_subtype: nil)
          ::Analytics::KnowledgeGraph::SourceType.for_orbit_request(
            request: request,
            oauth_access_token: access_token.is_a?(OauthAccessToken) ? access_token : nil,
            frontend_subtype: frontend_subtype
          )
        end

        def orbit_response_format
          params[:response_format].to_sym == :llm ? :llm : :raw
        end

        def grpc_client
          @grpc_client ||= ::Analytics::KnowledgeGraph::GrpcClient.new
        end

        include ::Analytics::Orbit::TargetResolver
        include ::Analytics::Orbit::CommandInterceptor

        def require_enabled_namespaces!
          context = ::Analytics::KnowledgeGraph::AuthorizationContext.new(current_user)
          forbidden!('No Knowledge Graph enabled namespaces available') unless context.has_enabled_namespaces?
        end

        def orbit_request_context(resolved_source_type = source_type)
          ::Analytics::KnowledgeGraph::RequestContext.new(
            source_type: resolved_source_type,
            session_id: request.headers['X-Duo-Workflow-Session-Id'],
            user_agent: request.user_agent
          )
        end

        def invoke_agent_command(command_name, parameters)
          rate_limit_agent_command!(command_name)

          format = orbit_command_format(parameters)
          intercepted = intercept_orbit_command(
            command_name,
            arguments: parameters,
            format: format,
            user: current_user,
            request_context: orbit_request_context
          )

          return agent_command_response(workhorse_send_data: intercepted.workhorse_send_data) if intercepted.workhorse?
          return agent_command_response(body: intercepted.result) if intercepted.handled?

          result = grpc_client.invoke_agent_command(
            command_name: command_name,
            parameters: parameters,
            user: current_user,
            request_context: orbit_request_context
          )

          agent_command_response(body: result)
        rescue ::Analytics::Orbit::CommandInterceptor::EnabledNamespacesRequiredError => e
          forbidden!(e.message)
        rescue ::Analytics::Orbit::CommandInterceptor::CommandError => e
          bad_request!(e.message)
        end

        def agent_command_response(body: nil, workhorse_send_data: nil)
          ::Analytics::Orbit::CommandInterceptor::CommandResponse.new(
            body: body,
            workhorse_send_data: workhorse_send_data
          )
        end

        def present_agent_schema_command(command_name)
          result = invoke_agent_command(command_name, { 'format' => params[:response_format] })

          present result.body
        end

        def rate_limit_agent_command!(command_name)
          check_rate_limit!(:orbit_query, scope: current_user) if command_name == 'query_graph'
        end
      end

      rescue_from ::Analytics::KnowledgeGraph::GrpcClient::AuthorizationError do
        error!('503 Service Unavailable', 503)
      end

      rescue_from ::Analytics::KnowledgeGraph::GrpcClient::ConnectionError do |e|
        status = GRPC_CODE_TO_HTTP_STATUS.fetch(e.grpc_code, GRPC_DEFAULT_HTTP_STATUS)
        error!({ code: e.grpc_code, message: GRPC_ERROR_MESSAGE }, status, { GRPC_CODE_HEADER => e.grpc_code.to_s })
      end

      namespace :orbit do
        desc 'Execute a query' do
          detail 'Executes a query against the Knowledge Graph gRPC service.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        params do
          requires :query, type: Hash, desc: 'Query DSL object'
          optional :response_format, type: String, values: %w[raw llm],
            default: 'raw', desc: 'Response format: raw or llm'
          optional :source_type, type: String, desc: 'Optional frontend source subtype (e.g. code_intelligence)'
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        post :query do
          check_rate_limit!(:orbit_query, scope: current_user)
          require_enabled_namespaces!

          status 200
          send_workhorse_headers!(*Gitlab::Workhorse.send_orbit_query(
            query: declared_params[:query].to_json,
            user: current_user,
            format: orbit_response_format,
            request_context: orbit_request_context(source_type(frontend_subtype: params[:source_type]))
          ))
          body ''
        end

        desc 'Execute a named query' do
          detail 'Executes a server-defined named query against the Knowledge Graph gRPC service. ' \
            'Requires a JSON request body: form encoding stringifies nested parameter values, ' \
            'which the per-query parameter schemas reject.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        params do
          requires :name, type: String, desc: 'Named query identifier'
          optional :parameters, type: Hash, default: {}, desc: 'Named query parameters'
          optional :response_format, type: String, values: %w[raw llm],
            default: 'raw', desc: 'Response format: raw or llm'
          optional :source_type, type: String, desc: 'Optional frontend source subtype (e.g. code_intelligence)'
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        post 'query/:name' do
          unless request.media_type == 'application/json'
            bad_request!('JSON request body required (Content-Type: application/json)')
          end

          check_rate_limit!(:orbit_query, scope: current_user)

          require_enabled_namespaces!

          status 200
          header(*Gitlab::Workhorse.send_orbit_query(
            query: {
              name: declared_params[:name],
              parameters: declared_params[:parameters]
            }.to_json,
            query_type: :named,
            user: current_user,
            format: orbit_response_format,
            request_context: orbit_request_context(source_type(frontend_subtype: params[:source_type]))
          ))
          body ''
        end

        desc 'List named query templates' do
          detail 'Lists the server-defined named queries with their query DSL rendered for the current user.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        get 'query/templates' do
          result = grpc_client.list_named_queries(
            user: current_user,
            request_context: orbit_request_context
          )
          present result
        end

        desc 'Retrieve the schema' do
          detail 'Retrieves the Knowledge Graph schema.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        params do
          optional :expand, type: String,
            desc: 'Comma-separated node names to expand'
          optional :response_format, type: String, values: %w[raw llm],
            default: 'raw', desc: 'Response format: raw or llm'
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        get :schema do
          expand_nodes = params[:expand]&.split(',')&.map(&:strip) || []
          result = grpc_client.get_graph_schema(
            user: current_user,
            expand_nodes: expand_nodes,
            format: orbit_response_format,
            request_context: orbit_request_context
          )
          present result
        end

        desc 'Retrieve the query DSL' do
          detail 'Retrieves the Knowledge Graph query DSL.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        params do
          optional :response_format, type: String, values: %w[raw llm],
            default: 'raw', desc: 'Response format: raw or llm'
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        get 'schema/dsl' do
          result = grpc_client.get_query_dsl(
            user: current_user,
            format: orbit_response_format,
            request_context: orbit_request_context
          )
          present result
        end

        desc 'Retrieve response format guidance' do
          detail 'Retrieves guidance for formatting Knowledge Graph query responses.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        params do
          optional :response_format, type: String, values: %w[raw llm],
            default: 'raw', desc: 'Response format: raw or llm'
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        get 'schema/format' do
          present_agent_schema_command('get_response_format')
        end

        # get_cluster_health swallows gRPC errors (returns status: 'unknown'),
        # so this route stays 200 without a rescue.
        desc 'Retrieve access and cluster health' do
          detail 'Returns whether the user can access the Knowledge Graph, plus cluster health. ' \
            'Always returns 200, regardless of access.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        params do
          optional :response_format, type: String, values: %w[raw llm],
            default: 'raw', desc: 'Response format: raw or llm'
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        route_setting :skip_orbit_entitlement, true
        get :status do
          available = ::Analytics::KnowledgeGraph.accessible_for?(current_user)

          system = if available
                     grpc_client.get_cluster_health(
                       user: current_user,
                       format: orbit_response_format,
                       request_context: orbit_request_context
                     )
                   end

          present({ user: { available: available }, system: system })
        end

        desc 'Retrieve graph status' do
          detail 'Returns indexing progress and entity counts for a namespace or project.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        params do
          optional :namespace_id, type: Integer, desc: 'Namespace (group) ID'
          optional :project_id, type: Integer, desc: 'Project ID'
          optional :full_path, type: String, desc: 'Full path of a project or group (e.g. gitlab-org/gitlab)'
          optional :response_format, type: String, values: %w[raw llm],
            default: 'raw', desc: 'Response format: raw or llm'
          exactly_one_of :namespace_id, :project_id, :full_path
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        get :graph_status do
          require_enabled_namespaces!

          context = resolve_graph_status_context(params)
          not_found!('Namespace') unless context

          is_project = context[:target].is_a?(Project)
          ability = is_project ? :read_project : :read_group
          not_found!('Namespace') unless can?(current_user, ability, context[:target])

          result = grpc_client.get_graph_status(
            user: current_user,
            traversal_path: context[:traversal_path],
            target_type: is_project ? :project : :group,
            format: orbit_response_format,
            request_context: orbit_request_context
          )
          present result
        end

        desc 'List all tools' do
          detail 'Lists all available Orbit operations.'
          tags 'knowledge_graph'
          hidden true
          success code: 200
        end
        route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
        get :tools do
          result = grpc_client.list_tools(user: current_user, request_context: orbit_request_context)
          visible_tool_names = ::API::Orbit::McpHandlers::ToolCatalog::COMMAND_TOOL_NAMES
          result = result.select { |tool| visible_tool_names.include?(tool[:name]) }
          present result
        end

        namespace :agent do
          desc 'List Orbit agent commands' do
            detail 'Lists Orbit commands that can be invoked through the agent command endpoint.'
            tags 'knowledge_graph'
            hidden true
            success code: 200
          end
          params do
            optional :command_names, type: String,
              desc: 'Comma-separated command names to describe. Omit or leave empty to list every command.'
            optional :response_format, type: String, values: %w[raw llm],
              default: 'raw', desc: 'Response format: raw or llm'
          end
          route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
          get 'commands' do
            result = grpc_client.list_agent_commands(
              user: current_user,
              command_names: normalize_orbit_command_names(params[:command_names]),
              format: orbit_response_format,
              request_context: orbit_request_context
            )

            present result
          rescue ::Analytics::Orbit::CommandInterceptor::CommandError => e
            bad_request!(e.message)
          end

          desc 'Invoke an Orbit agent command' do
            detail 'Invokes a command by name. Rails intercepts commands that require Rails-owned behavior.'
            tags 'knowledge_graph'
            hidden true
            success code: 200
          end
          params do
            requires :name, type: String, desc: 'Command name'
            optional :parameters, type: Hash, default: {}, desc: 'Command parameters'
          end
          route_setting :authorization, permissions: :read_knowledge_graph, boundary_type: :user
          post 'commands/:name' do
            parameters = declared_params[:parameters] || {}
            result = invoke_agent_command(params[:name], parameters)

            status 200

            if result.workhorse?
              send_workhorse_headers!(*result.workhorse_send_data)
              body ''
            else
              present result.body
            end
          end
        end
      end
    end
  end
end
