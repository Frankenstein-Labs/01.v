# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class SessionArtifact < ::ApplicationRecord
      self.table_name = 'duo_workflow_session_artifacts'

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project, optional: true
      belongs_to :namespace, optional: false
      belongs_to :user

      validates :workflow_id, presence: true, uniqueness: true
      validates :user_id, presence: true
      validates :status, presence: true
      validates :workflow_definition, presence: true, length: { maximum: 255 }
      validates :model_used, length: { maximum: 255 }

      # Scopes for `Gitlab::Pagination::Keyset::InOperatorOptimization::QueryBuilder`.
      # `namespace_id` is the single sharding key and is populated on every row
      # (`project.project_namespace_id` for project rows, the group id otherwise),
      # so a group hierarchy is scoped by a single `namespace_id IN (...)` lookup.
      scope :in_optimization_array_mapping_scope, ->(namespace_id_expression) {
        where(arel_table[:namespace_id].eq(namespace_id_expression))
      }
      scope :in_optimization_finder_query, ->(_workflow_updated_at_expression, workflow_id_expression) {
        where(arel_table[:workflow_id].eq(workflow_id_expression))
      }
      scope :for_workflow, ->(workflow_id) { where(workflow_id: workflow_id) }
      # `preload` (not `includes`) so the association loads via a separate query,
      # which survives the `FROM (subquery)` rewrite done by the in-operator optimization.
      scope :with_project, -> { preload(:project) }
      scope :with_user, -> { preload(:user) }
      scope :with_keyset_order, -> {
        order(
          ::Gitlab::Pagination::Keyset::Order.build(
            [
              ::Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
                attribute_name: 'workflow_updated_at',
                order_expression: arel_table[:workflow_updated_at].desc,
                nullable: :not_nullable
              ),
              ::Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
                attribute_name: 'workflow_id',
                order_expression: arel_table[:workflow_id].desc,
                nullable: :not_nullable
              )
            ]
          )
        )
      }

      # Uses upsert which intentionally bypasses model validations and callbacks
      # for performance. Data integrity is guaranteed by DB constraints and the
      # fact that we copy from an already-validated Workflow record.
      #
      # `namespace_id` is always populated: project-scoped workflows store the
      # project's `project_namespace_id` so the row is reachable via the namespace
      # hierarchy, while group-scoped workflows store the group's namespace id.
      def self.sync_from_workflow!(workflow)
        upsert({
          workflow_id: workflow.id,
          user_id: workflow.user_id,
          project_id: workflow.project_id,
          namespace_id: workflow.namespace_id || workflow.project.project_namespace_id,
          status: workflow.status_before_type_cast,
          workflow_definition: workflow.workflow_definition,
          workflow_created_at: workflow.created_at,
          workflow_updated_at: workflow.updated_at
        }, unique_by: :workflow_id)
      end

      def web_path
        return unless project

        "#{Gitlab::Routing.url_helpers.project_automate_agent_sessions_path(project)}/#{workflow_id}"
      end

      def download_path
        return unless project

        Gitlab::Routing.url_helpers.download_project_security_agent_artifact_path(project, workflow_id)
      end
    end
  end
end
