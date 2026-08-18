# frozen_string_literal: true

module EE
  module Gitlab
    module Workhorse
      def self.prepended(base)
        base.singleton_class.prepend(ClassMethods)
      end

      ORBIT_DEFAULT_TIMEOUT_SECONDS = 30

      ORBIT_QUERY_TYPE_NAMED = 'named'

      VALID_SOURCE_TYPES = [
        ::Analytics::KnowledgeGraph::SourceType::FRONTEND,
        ::Analytics::KnowledgeGraph::SourceType::DWS,
        ::Analytics::KnowledgeGraph::SourceType::MCP,
        ::Analytics::KnowledgeGraph::SourceType::CORE,
        ::Analytics::KnowledgeGraph::SourceType::REST,
        ::Analytics::KnowledgeGraph::SourceType::CODE_INTELLIGENCE
      ].freeze

      module ClassMethods
        def send_orbit_query(
          query:, user:, format:, query_type: :json, mcp_id: nil,
          request_context: ::Analytics::KnowledgeGraph::RequestContext.new
        )
          endpoint = ::Analytics::KnowledgeGraph::GrpcClient.configured_endpoint
          secure = ::Analytics::KnowledgeGraph::GrpcClient.secure_channel?(endpoint)
          private_addr = ::Analytics::KnowledgeGraph::GrpcClient.private_address?(endpoint)

          headers = ::Analytics::KnowledgeGraph::GrpcClient.outgoing_headers
          headers['x-client-user-agent'] = request_context.user_agent if request_context.user_agent.present?

          if secure || private_addr
            jwt = ::Analytics::KnowledgeGraph::JwtAuth.generate_token(
              user: user,
              source_type: validated_source_type(request_context.source_type),
              session_id: request_context.session_id
            )
            headers = headers.merge('authorization' => "Bearer #{jwt}") if jwt
          end

          params = {
            'GkgServer' => {
              'address' => endpoint,
              'tls' => secure,
              'headers' => headers
            },
            'Query' => query,
            'Format' => format.to_s,
            'TimeoutSeconds' => orbit_timeout_seconds
          }
          params['QueryType'] = ORBIT_QUERY_TYPE_NAMED if query_type.to_sym == :named
          params['McpId'] = mcp_id unless mcp_id.nil?

          client_ip = ::Gitlab::IpAddressState.current
          params['ClientIp'] = client_ip if client_ip.present?

          [
            ::Gitlab::Workhorse::SEND_DATA_HEADER,
            "orbit-query:#{encode(params)}"
          ]
        end

        def orbit_timeout_seconds
          ::Gitlab.config.knowledge_graph.streaming_timeout_seconds
        rescue ::Gitlab::Configs::MissingConfig
          ENV.fetch('KNOWLEDGE_GRAPH_STREAMING_TIMEOUT', ORBIT_DEFAULT_TIMEOUT_SECONDS).to_i
        end

        private

        def validated_source_type(source_type)
          return source_type if VALID_SOURCE_TYPES.include?(source_type)

          ::Gitlab::AppLogger.warn(
            "Invalid source_type for Orbit query: #{source_type.inspect}, falling back to 'rest'"
          )

          ::Analytics::KnowledgeGraph::SourceType::REST
        end
      end
    end
  end
end
