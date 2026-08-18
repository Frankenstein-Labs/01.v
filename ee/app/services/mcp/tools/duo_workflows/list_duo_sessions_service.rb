# frozen_string_literal: true

module Mcp
  module Tools
    module DuoWorkflows
      class ListDuoSessionsService < Base::GraphqlService
        STATUS_GROUPS = ::Ai::DuoWorkflows::Workflow::GROUPED_STATUSES.keys.map(&:to_s).freeze

        register_version '0.1.0', {
          description: 'List the authenticated user\'s Duo Agent Platform sessions, excluding Duo Chat sessions, ' \
            'optionally filtered by project or status group, with compact metadata including a possibly truncated ' \
            'goal preview and cursor pagination.',
          input_schema: {
            type: 'object',
            properties: {
              url: {
                type: 'string',
                description: 'GitLab URL of the project to filter sessions by.'
              },
              project_id: {
                type: 'string',
                description: 'Numeric ID or full path of the project to filter sessions by.'
              },
              status_group: {
                type: 'string',
                description: 'Filter by session status group.',
                enum: STATUS_GROUPS
              },
              after: {
                type: 'string',
                description: 'Cursor for forward pagination. Use endCursor from the previous response.'
              },
              first: {
                type: 'integer',
                description: 'Number of sessions to return (forward pagination, default 20, max 100).',
                minimum: 1,
                maximum: 100
              }
            },
            required: []
          },
          annotations: {
            readOnlyHint: true
          }
        }

        protected

        override :perform_default
        def perform_default(arguments = {})
          execute_graphql_tool(arguments)
        end

        private

        def graphql_tool_class
          Mcp::Tools::DuoWorkflows::ListDuoSessionsTool
        end
      end
    end
  end
end
