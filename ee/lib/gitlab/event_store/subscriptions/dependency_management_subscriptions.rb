# frozen_string_literal: true

module Gitlab
  module EventStore
    module Subscriptions
      class DependencyManagementSubscriptions < BaseSubscriptions
        def register
          store.subscribe ::DependencyManagement::SecurityUpdate::CreateMergeRequestWorker,
            to: ::Ci::PipelineFinishedEvent,
            if: ->(event) { dependency_management_pipeline?(event) }

          store.subscribe ::DependencyManagement::SecurityUpdate::TriggerResolveDependencyBumpWorkflowWorker,
            to: ::Ci::PipelineFinishedEvent,
            if: ->(event) { dependency_bump_mr_failure?(event) }

          store.subscribe ::DependencyManagement::SecurityUpdate::TrackResolveDependencyBumpPipelineWorker,
            to: ::Ci::PipelineFinishedEvent,
            if: ->(event) { dependency_bump_mr_pipeline?(event) }

          store.subscribe ::DependencyManagement::SecurityUpdate::TrackMergedMrWorker,
            to: ::MergeRequests::MergedEvent,
            if: ->(event) { dependency_management_mr?(event) }

          store.subscribe ::DependencyManagement::SecurityUpdate::TrackClosedMrWorker,
            to: ::MergeRequests::ClosedEvent,
            if: ->(event) { dependency_management_closed_mr?(event) }
        end

        private

        def dependency_management_pipeline?(event)
          source = event.data[:source]
          return source == 'dependency_management_security_update' unless source.nil?

          # Fall back to a query for events published before `source` was added
          # to the event data (in-flight during rollout).
          partition_id = event.data[:partition_id]
          scope = partition_id ? ::Ci::Pipeline.in_partition(partition_id) : ::Ci::Pipeline

          scope
            .id_in(event.data[:pipeline_id])
            .from_dependency_management
            .exists?
        end

        def dependency_bump_mr_failure?(event)
          return false unless event.data[:status] == 'failed'

          # This condition is evaluated synchronously when Ci::PipelineFinishedEvent is
          # published (e.g. inside POST /api/v4/jobs/request). The pipeline lookup below
          # can push that already-saturated endpoint past Gitlab::QueryLimiting's cap.
          # Temporary: the proper fix is to move filtering into the async worker.
          # See https://gitlab.com/gitlab-org/gitlab/-/issues/605253
          ::Gitlab::QueryLimiting.disable!('https://gitlab.com/gitlab-org/gitlab/-/issues/605253', new_threshold: 105)

          pipeline = ::Ci::Pipeline.find_by_id(event.data[:pipeline_id])
          return false unless pipeline

          return false unless pipeline.source_ref&.start_with?(
            "#{::DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/"
          )

          root_ancestor = pipeline.project.root_ancestor
          ::Feature.enabled?(:enable_dependency_bump_breaking_changes, root_ancestor)
        end

        def dependency_bump_mr_pipeline?(event)
          return false unless ::Feature.enabled?(
            :enable_dependency_bump_breaking_changes_pipeline_tracking,
            ::Feature.current_request
          )

          # `p_ci_pipelines` is partitioned, so scope the lookup to prune to one partition.
          # `partition_id` is absent from events published before it was added to the payload.
          partition_id = event.data[:partition_id]
          scope = partition_id ? ::Ci::Pipeline.in_partition(partition_id) : ::Ci::Pipeline

          pipeline = scope.find_by_id(event.data[:pipeline_id])
          return false unless pipeline

          return false unless pipeline.source_ref&.start_with?(
            "#{::DependencyManagement::SecurityUpdate::Request::BRANCH_PREFIX}/"
          )

          true
        end

        def dependency_management_mr?(event)
          merge_request = MergeRequest.find_by_id(event.data[:merge_request_id])
          return false unless merge_request

          merge_request.dependency_management_mr?
        end

        def dependency_management_closed_mr?(event)
          event.data[:source] ==
            ::MergeRequests::ClosedEvent::SOURCE_TYPES[:dependency_management_auto_remediation]
        end
      end
    end
  end
end
