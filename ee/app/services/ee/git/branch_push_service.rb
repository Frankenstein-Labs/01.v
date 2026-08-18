# frozen_string_literal: true

module EE
  module Git
    module BranchPushService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        enqueue_elasticsearch_indexing
        enqueue_zoekt_indexing
        enqueue_knowledge_graph_code_indexing
        enqueue_code_embedding_indexing
        enqueue_update_external_pull_requests
        enqueue_repository_xray
        enqueue_sync_pipeline_execution_policy_metadata

        super
      end

      private

      def enqueue_sync_pipeline_execution_policy_metadata
        return unless project.licensed_feature_available?(:security_orchestration_policies)
        return if ::Security::PipelineExecutionPolicyConfigLink.for_project(project).none?

        ::Security::SyncLinkedPipelineExecutionPolicyConfigsWorker
          .perform_async(project.id, current_user.id, oldrev, newrev, ref)
      end

      def enqueue_elasticsearch_indexing
        return unless should_index_commits?

        project.repository.index_commits_and_blobs
      end

      def enqueue_zoekt_indexing
        return false unless ::Gitlab::CurrentSettings.zoekt_indexing_enabled?
        return false unless default_branch?
        return false unless project.use_zoekt?

        project.repository.async_update_zoekt_index
      end

      def enqueue_knowledge_graph_code_indexing
        return false unless default_branch?
        # Backend indexing path: gated on knowledge_graph_infra, not the user-facing module.
        return false unless ::Feature.enabled?(:knowledge_graph_infra, :instance)
        return false unless project.knowledge_graph_indexing_enabled?

        ::Analytics::KnowledgeGraph::CodeIndexingWorker.perform_async(
          project.id,
          ref,
          newrev
        )
      end

      def enqueue_code_embedding_indexing
        return false unless default_branch?

        repository = Ai::ActiveContext::Code::Repository.find_by_project_id(project.id)
        return false unless repository&.ready?

        ::Ai::ActiveContext::Code::RepositoryIndexWorker.perform_async(repository.id)
      end

      def enqueue_update_external_pull_requests
        return unless project.mirror?
        return unless params.fetch(:create_pipelines, true)

        UpdateExternalPullRequestsWorker.perform_async(
          project.id,
          current_user.id,
          ref
        )
      end

      def should_index_commits?
        return false unless default_branch?

        project.use_elasticsearch?
      end

      def enqueue_repository_xray
        return if removing_branch?
        return unless default_branch? && project.duo_features_enabled

        ::Ai::RepositoryXray::ScanDependenciesWorker.perform_async(project.id)
      end
    end
  end
end
