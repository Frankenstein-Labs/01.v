# frozen_string_literal: true

module EE
  module API
    module Mcp
      module Handlers
        module CallTool
          extend ActiveSupport::Concern

          prepended do
            include ::Gitlab::InternalEventsTracking
            include ::Mcp::Tools::Concerns::ResourceFinder
          end

          private

          def track_start_event(tool_name, session_id, current_user, params: nil)
            track_internal_event(
              'start_mcp_tool_call',
              user: current_user,
              **resolve_tracking_scope(params),
              additional_properties: {
                session_id: session_id,
                tool_name: tool_name
              }
            )
          end

          def track_finish_event(tool_name, session_id, current_user, success:, error: nil, params: nil)
            additional_properties = {
              session_id: session_id,
              tool_name: tool_name,
              has_tool_call_success: success.to_s
            }

            if error
              additional_properties[:failure_reason] = error.class.name
              additional_properties[:error_status] = error.message&.truncate(255)
            end

            track_internal_event(
              'finish_mcp_tool_call',
              user: current_user,
              **resolve_tracking_scope(params),
              additional_properties: additional_properties
            )
          end

          def tool_call_namespace(params)
            scope = resolve_tracking_scope(params)
            (scope[:project] || scope[:namespace])&.root_ancestor
          end

          # Returns `{ project: }`, `{ namespace: }`, or `{}` so analytics
          # attribute events to the tool's target namespace rather than the
          # user's personal namespace. `track_internal_event` derives the
          # namespace from `project.namespace` automatically when a project is
          # passed. Resolution failures rescue to `{}` because tracking must
          # never break tool execution. Memoized because both `track_start_event`
          # and `track_finish_event` run in the same request with the same params
          # and `find_project!` / `find_group!` each issue a database query.
          def resolve_tracking_scope(params)
            @resolved_tracking_scope ||= begin
              arguments = params.to_h.with_indifferent_access[:arguments] || {}

              if arguments[:project_id].present?
                { project: find_project!(arguments[:project_id].to_s) }
              elsif arguments[:group_id].present?
                { namespace: find_group!(arguments[:group_id].to_s) }
              else
                {}
              end
            rescue StandardError
              {}
            end
          end
        end
      end
    end
  end
end
