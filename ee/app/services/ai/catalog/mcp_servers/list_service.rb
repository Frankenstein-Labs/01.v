# frozen_string_literal: true

module Ai
  module Catalog
    module McpServers
      class ListService
        def initialize(agent_version, current_user)
          @agent_version = agent_version
          @current_user = current_user
        end

        def execute
          return ::Ai::Catalog::McpServer.none unless allowed?

          ::Ai::Catalog::McpServer.id_in(agent_version.def_mcp_servers)
        end

        private

        attr_reader :agent_version, :current_user

        def allowed?
          Ability.allowed?(current_user, :read_ai_catalog_mcp_server, agent_version.organization)
        end
      end
    end
  end
end
