# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module Concerns
      module WorkflowEventTracking
        extend ActiveSupport::Concern
        include ::Gitlab::InternalEventsTracking

        private

        def track_workflow_event(event_name, workflow, source: nil)
          track_internal_event(
            event_name,
            user: workflow.user,
            project: workflow.project,
            additional_properties: workflow_tracking_properties(workflow, source: source)
          )
        end

        def workflow_tracking_properties(workflow, source: nil)
          {
            label: workflow.workflow_definition,
            value: workflow.id,
            property: workflow.environment,
            source: source
          }.compact
        end
      end
    end
  end
end
