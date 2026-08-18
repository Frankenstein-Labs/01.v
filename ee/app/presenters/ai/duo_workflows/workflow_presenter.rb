# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowPresenter < Gitlab::View::Presenter::Delegated
      include Gitlab::Utils::StrongMemoize

      # Workflow also includes StrongMemoize, so its memoization helpers are
      # delegated here. Overriding them with the presenter's own copies of the
      # same module methods is intentional and inert (each operates on its own
      # instance's ivars).
      delegator_override_with Gitlab::Utils::StrongMemoize

      presents ::Ai::DuoWorkflows::Workflow, as: :workflow

      def human_status
        workflow.human_status_name
      end

      def web_url
        workflow.web_url
      end

      def mcp_enabled
        workflow.mcp_enabled?
      end

      def agent_privileges_names
        workflow.agent_privileges.map do |privilege|
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES[privilege][:name]
        end
      end

      def pre_approved_agent_privileges_names
        workflow.pre_approved_agent_privileges.map do |privilege|
          ::Ai::DuoWorkflows::Workflow::AgentPrivileges::ALL_PRIVILEGES[privilege][:name]
        end
      end

      # Falls back to the checkpoint_headers table once the workflow reconstructs
      # from blobs: `duo_workflow_write_incremental_only` stops writing the full
      # `checkpoints` row these otherwise read directly (see
      # https://gitlab.com/gitlab-org/gitlab/-/work_items/612586).
      def first_checkpoint(checkpoint_ns: nil)
        return workflow.earliest_checkpoint_header(checkpoint_ns: checkpoint_ns) if read_checkpoints_from_blobs?

        workflow.checkpoints.earliest(checkpoint_ns: checkpoint_ns)
      end

      def latest_checkpoint(checkpoint_ns: nil)
        return workflow.latest_checkpoint_header(checkpoint_ns: checkpoint_ns) if read_checkpoints_from_blobs?

        workflow.checkpoints.latest(checkpoint_ns: checkpoint_ns)
      end

      def agent_name
        return workflow.ai_catalog_item_version.item.name if workflow.ai_catalog_item_version_id.present?

        ::Ai::FoundationalChatAgent.with_workflow_definition(workflow.workflow_definition)&.name
      end

      def model_metadata_name
        parsed_model_metadata['name']
      end

      def model_metadata_identifier
        parsed_model_metadata['identifier']
      end

      def flow_metadata_version
        parsed_flow_metadata['flow_version']
      end

      def flow_metadata_id
        parsed_flow_metadata['flow_id']
      end

      def flow_metadata_schema_version
        parsed_flow_metadata['schema_version']
      end

      private

      def read_checkpoints_from_blobs?
        workflow.reconstruct_from_blobs_for_graphql?
      end

      def parsed_model_metadata
        return {} if workflow.model_metadata_json.blank?

        Gitlab::Json.safe_parse(workflow.model_metadata_json) || {}
      end
      strong_memoize_attr :parsed_model_metadata

      def parsed_flow_metadata
        return {} if workflow.flow_metadata_json.blank?

        Gitlab::Json.safe_parse(workflow.flow_metadata_json) || {}
      end
      strong_memoize_attr :parsed_flow_metadata
    end
  end
end
