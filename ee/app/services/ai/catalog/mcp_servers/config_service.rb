# frozen_string_literal: true

module Ai
  module Catalog
    module McpServers
      class ConfigService
        def initialize(item_version, current_user)
          @item_version = item_version
          @current_user = current_user
        end

        def execute
          return {} unless allowed?

          mcp_servers = ::Ai::Catalog::McpServers::ListService.new(item_version, current_user).execute
          mcp_servers_users = current_user.ai_catalog_mcp_servers_users.index_by(&:ai_catalog_mcp_server_id)

          mcp_servers.each_with_object({}) do |server, config|
            server_key = server.name.downcase.gsub(/[^a-z0-9]/, '_').to_sym
            mcp_servers_user = mcp_servers_users[server.id]

            config[server_key] = {
              URL: server.url,
              Headers: build_mcp_server_headers(server, mcp_servers_user)
            }
          end
        end

        private

        attr_reader :item_version, :current_user

        def allowed?
          Ability.allowed?(current_user, :read_ai_catalog_mcp_server, item_version.organization)
        end

        def build_mcp_server_headers(server, mcp_servers_user)
          return {} unless mcp_servers_user

          case server.auth_type
          when 'oauth'
            refresh_token_if_expired(server, mcp_servers_user)
            { Authorization: "Bearer #{mcp_servers_user.token}" }
          else
            {}
          end
        end

        CLOCK_SKEW = 2.minutes
        private_constant :CLOCK_SKEW

        def refresh_token_if_expired(server, mcp_servers_user)
          return unless mcp_servers_user.expires_at
          return unless mcp_servers_user.expires_at <= Time.current + CLOCK_SKEW

          ::Ai::Catalog::McpServers::RefreshTokenService.new(
            mcp_server: server,
            current_user: current_user
          ).execute

          mcp_servers_user.reset
        end
      end
    end
  end
end
