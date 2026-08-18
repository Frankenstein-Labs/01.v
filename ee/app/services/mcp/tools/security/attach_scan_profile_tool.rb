# frozen_string_literal: true

module Mcp
  module Tools
    module Security
      class AttachScanProfileTool < Mcp::Tools::Base::GraphqlTool
        register_version '0.1.0', {
          operation_name: 'securityScanProfileAttach',
          graphql_operation: load_graphql('security/attach_scan_profile.query.graphql')
        }

        def build_variables
          {
            input: {
              securityScanProfileId: params[:security_scan_profile_id],
              projectIds: params[:project_ids].to_a,
              groupIds: params[:group_ids].to_a
            }
          }
        end
      end
    end
  end
end
