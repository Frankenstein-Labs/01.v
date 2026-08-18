# frozen_string_literal: true

module Analytics
  module Orbit
    module CommandInterceptor
      CommandError = Class.new(StandardError)
      EnabledNamespacesRequiredError = Class.new(CommandError)

      CommandResponse = Struct.new(:body, :workhorse_send_data, keyword_init: true) do
        def workhorse?
          workhorse_send_data.present?
        end
      end

      InterceptResult = Struct.new(:handled, :result, :workhorse_send_data, keyword_init: true) do
        def handled?
          handled
        end

        def workhorse?
          workhorse_send_data.present?
        end
      end

      def normalize_orbit_command_names(value)
        case value
        when nil
          []
        when String
          value.split(',').map(&:strip).reject(&:blank?)
        when Array
          value.map(&:to_s).map(&:strip).reject(&:blank?)
        else
          raise CommandError, "'command_names' must be an Array or comma-separated String"
        end
      end

      def orbit_command_format(arguments)
        raw_format = arguments['format'] || arguments[:format]
        raw_format&.to_sym == :raw ? :raw : :llm
      end

      def intercept_orbit_command(
        command_name, arguments:, format:, user:, mcp_request_id: nil,
        request_context: ::Analytics::KnowledgeGraph::RequestContext.new
      )
        case command_name
        when 'query_graph'
          intercept_query_graph(arguments, format: format, user: user,
            mcp_request_id: mcp_request_id, request_context: request_context)
        else
          InterceptResult.new(handled: false)
        end
      end

      private

      def intercept_query_graph(
        arguments, format:, user:, mcp_request_id:,
        request_context:
      )
        require_enabled_namespaces_for_command!(user)

        query = arguments['query'] || arguments[:query]
        raise CommandError, "Missing required parameter 'query'" if query.blank?

        query = query.to_json unless query.is_a?(String)

        InterceptResult.new(
          handled: true,
          workhorse_send_data: ::Gitlab::Workhorse.send_orbit_query(
            query: query,
            user: user,
            format: format,
            mcp_id: mcp_request_id,
            request_context: request_context
          )
        )
      end

      def require_enabled_namespaces_for_command!(user)
        context = ::Analytics::KnowledgeGraph::AuthorizationContext.new(user)
        return context if context.has_enabled_namespaces?

        raise EnabledNamespacesRequiredError, 'No Knowledge Graph enabled namespaces available'
      end
    end
  end
end
