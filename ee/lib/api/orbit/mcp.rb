# frozen_string_literal: true

module API
  module Orbit
    class Mcp < ::API::Base
      include ::API::Concerns::AiWorkflowsAccess
      include ::API::Helpers::HeadersHelpers
      include APIGuard

      helpers ::API::Helpers::Mcp::AuthChallenge

      InternalError = Class.new(StandardError)

      JSONRPC_VERSION = '2.0'

      JSONRPC_ERRORS = {
        invalid_request: { code: -32600, message: 'Invalid Request' },
        method_not_found: { code: -32601, message: 'Method not found' },
        invalid_params: { code: -32602, message: 'Invalid params' },
        internal_error: { code: -32603, message: 'Internal error' }
      }.freeze

      JSONRPC_METHOD_HANDLERS = {
        'initialize' => McpHandlers::InitializeRequest,
        'notifications/initialized' => McpHandlers::InitializedNotification,
        'tools/list' => McpHandlers::ListTools,
        'tools/call' => McpHandlers::CallTool
      }.freeze

      feature_category :knowledge_graph
      allow_access_with_scope [:mcp_orbit, :mcp, :read_api]
      allow_ai_workflows_access
      urgency :low

      before do
        authenticate!
        unauthorized! unless access_token

        not_found! unless ::Analytics::KnowledgeGraph.enabled_for?(current_user)
        forbidden! unless ::Analytics::KnowledgeGraph::OrbitLicense.available_for?(current_user)
      end

      helpers do
        def source_type
          ::Analytics::KnowledgeGraph::SourceType.for_mcp_request(
            request: request,
            oauth_access_token: access_token.is_a?(OauthAccessToken) ? access_token : nil
          )
        end

        def mcp_request_context
          ::Analytics::KnowledgeGraph::RequestContext.new(
            source_type: source_type,
            session_id: request.headers['X-Duo-Workflow-Session-Id'],
            user_agent: request.user_agent
          )
        end

        def rate_limit_mcp_command!
          return unless params[:method] == 'tools/call'

          call_params = params[:params] || {}
          return unless call_params[:name] == 'invoke_command'

          arguments = call_params[:arguments] || {}
          return unless arguments[:command_name] == 'query_graph'

          check_rate_limit!(:orbit_query, scope: current_user)
        end

        def invoke_basic_handler
          method_name = params[:method]
          handler_class = JSONRPC_METHOD_HANDLERS[method_name] || method_not_found!(method_name)
          grpc_client = ::Analytics::KnowledgeGraph::GrpcClient.new
          handler_class.new(
            params[:params] || {}, access_token, current_user,
            grpc_client: grpc_client,
            mcp_request_id: params[:id],
            request_context: mcp_request_context
          ).invoke
        end

        def method_not_found!(method_name)
          render_structured_api_error!({
            jsonrpc: JSONRPC_VERSION,
            error: JSONRPC_ERRORS[:method_not_found].merge({ data: { method: method_name } }),
            id: params[:id]
          }, 404)
        end

        def format_jsonrpc_response(result)
          if params[:id].nil? || result.nil?
            body false
          else
            { jsonrpc: JSONRPC_VERSION, result: result, id: params[:id] }
          end
        end
      end

      namespace 'orbit/mcp' do
        params do
          requires :jsonrpc, type: String, desc: 'JSON-RPC protocol version identifier. Must be `2.0`.',
            allow_blank: false, values: [JSONRPC_VERSION]
          requires :method, type: String, desc: 'Name of the JSON-RPC method invoked on the MCP server.',
            allow_blank: false
          optional :id, desc: 'ID of the JSON-RPC request returned in the response.', # rubocop:disable API/ParameterType -- JSON-RPC id can be string, number, or null per spec
            allow_blank: false
          optional :params, desc: 'Object or array that contains parameters passed to the specified JSON-RPC method',
            types: [Hash, Array]
        end

        rescue_from Grape::Exceptions::ValidationErrors do |e|
          render_structured_api_error!({
            jsonrpc: JSONRPC_VERSION,
            error: JSONRPC_ERRORS[:invalid_request].merge({ data: { validations: e.full_messages } }),
            id: env['orbit_mcp.request_id']
          }, 400)
        end

        rescue_from ArgumentError do |e|
          render_structured_api_error!({
            jsonrpc: JSONRPC_VERSION,
            error: JSONRPC_ERRORS[:invalid_params].merge({ data: { params: e.message } }),
            id: env['orbit_mcp.request_id']
          }, 400)
        end

        rescue_from ::API::Orbit::Mcp::InternalError do |e|
          Gitlab::ErrorTracking.track_exception(e)
          render_structured_api_error!({
            jsonrpc: JSONRPC_VERSION,
            error: JSONRPC_ERRORS[:internal_error],
            id: env['orbit_mcp.request_id']
          }, 200)
        end

        desc 'MCP Orbit JSON-RPC request handler' do
          detail 'Handles JSON-RPC 2.0 requests for the Orbit Knowledge Graph MCP server'
          success code: 200
          tags %w[mcp]
          hidden true
        end
        route_setting :authorization, permissions: :execute_orbit_mcp_tool, boundary_type: :user
        post do
          env['orbit_mcp.request_id'] = params[:id]
          status :ok

          rate_limit_mcp_command!

          result = invoke_basic_handler

          if result.is_a?(McpHandlers::Base::WorkhorseSendData)
            send_workhorse_headers!(result.header_name, result.header_value)
            body ''
          else
            format_jsonrpc_response(result)
          end
        end

        desc 'MCP Orbit SSE listener' do
          detail 'Returns 405 as the Orbit MCP server uses POST only'
          success code: 405
          tags %w[mcp]
          hidden true
        end
        route_setting :authorization, permissions: :execute_orbit_mcp_tool, boundary_type: :user
        get do
          status :method_not_allowed
        end
      end
    end
  end
end

API::Orbit::Mcp.prepend_mod
