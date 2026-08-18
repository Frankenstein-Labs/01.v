# frozen_string_literal: true

module API
  module Orbit
    module McpHandlers
      class InitializeRequest < Base
        SUPPORTED_PROTOCOL_VERSIONS = %w[
          2026-07-28
          2025-03-26
          2025-06-18
          2025-11-25
        ].freeze

        def invoke
          client_version = params[:protocolVersion]

          if client_version.nil?
            raise ArgumentError, "Missing required parameter 'protocolVersion'. " \
              "Supported: #{SUPPORTED_PROTOCOL_VERSIONS.join(', ')}"
          end

          unless SUPPORTED_PROTOCOL_VERSIONS.include?(client_version)
            raise ArgumentError, "Unsupported protocol version '#{client_version}'. " \
              "Supported: #{SUPPORTED_PROTOCOL_VERSIONS.join(', ')}"
          end

          {
            protocolVersion: client_version,
            capabilities: { tools: { listChanged: false } },
            serverInfo: { name: 'GitLab Orbit MCP Server', version: Gitlab::VERSION }
          }
        end
      end
    end
  end
end
