# frozen_string_literal: true

module Mcp
  module Tools
    module Security
      class AttachScanProfileService < Base::GraphqlService
        register_version '0.1.0', {
          description: 'Attach a given security scan profile to the given groups and projects.',
          input_schema: {
            type: 'object',
            properties: {
              security_scan_profile_id: {
                type: 'string',
                description: 'Global ID of the security scan profile to attach.'
              },
              project_ids: {
                type: 'array',
                description: 'Array of Global IDs of the projects. Required if `group_ids` not provided.',
                items: {
                  type: 'string'
                },
                minItems: 1
              },
              group_ids: {
                type: 'array',
                description: 'Array of Global IDs of the groups. Required if `project_ids` not provided.',
                items: {
                  type: 'string'
                },
                minItems: 1
              }
            },
            required: ['security_scan_profile_id'],
            additionalProperties: false
          },
          annotations: {
            readOnlyHint: false,
            destructiveHint: false
          }
        }

        private

        def graphql_tool_class
          Mcp::Tools::Security::AttachScanProfileTool
        end

        def perform_v0_1_0(arguments)
          execute_graphql_tool(arguments)
        end

        override :perform_default
        def perform_default(arguments = {})
          perform_v0_1_0(arguments)
        end
      end
    end
  end
end
