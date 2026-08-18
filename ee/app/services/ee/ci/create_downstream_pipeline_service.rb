# frozen_string_literal: true

module EE
  module Ci
    module CreateDownstreamPipelineService
      extend ::Gitlab::Utils::Override

      override :log_audit_event
      def log_audit_event(downstream_pipeline)
        return unless downstream_pipeline&.persisted?
        return if downstream_pipeline.parent_pipeline?

        root_pipeline = downstream_pipeline.upstream_root

        audit_context = {
          name: "multi_project_downstream_pipeline_created",
          author: current_user,
          scope: downstream_pipeline.project,
          target: downstream_pipeline,
          target_details: downstream_pipeline.id.to_s,
          message: "Multi-project downstream pipeline created.",
          additional_details: {
            upstream_root_pipeline_id: root_pipeline.id,
            upstream_root_project_path: root_pipeline.project&.full_path
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
