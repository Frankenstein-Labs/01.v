# frozen_string_literal: true

module Ai
  module Catalog
    module Flows
      class ExecuteMergeRequestMergedWorkflowTriggersWorker
        include Ai::CloudEventsFlowTriggerWorker

        concurrency_limit -> { 100 }
        idempotent!

        SESSION_IDS_LIMIT = 20

        class << self
          def cloud_event_class
            MergeRequests::MergedEvent
          end

          def event_type
            :merge_request
          end

          def action
            'merged'
          end
        end

        private

        def find_resource_and_container(cloud_event)
          merge_request_id = cloud_event.data[:merge_request_id]
          merge_request = MergeRequest.find_by_id(merge_request_id)

          unless merge_request
            logger.info(structured_payload(message: 'Merge request not found.',
              merge_request_id: merge_request_id))
            return
          end

          [merge_request, merge_request.target_project]
        end

        def feature_enabled?(project)
          Feature.enabled?(:merge_request_merged_flow_trigger, project) &&
            Feature.enabled?(:merge_request_merged_memory_distillation, project)
        end

        def passes_event_checks?(_cloud_event, merge_request)
          return true if developer_session_ids(merge_request).any?

          logger.info(structured_payload(
            message: 'No existing Developer flow session for the merge request.',
            merge_request_id: merge_request.id))

          false
        end

        def developer_session_ids(merge_request)
          @developer_session_ids ||= {}
          @developer_session_ids[merge_request.id] ||= ::Ai::DuoWorkflows::Workflow
            .for_merge_request(merge_request)
            .with_workflow_definition(::Ai::Catalog::FoundationalFlow::Definitions::Developer::REFERENCE)
            .ordered_by_id_desc
            .limit(SESSION_IDS_LIMIT)
            .pluck_primary_key
        end

        def additional_run_params(merge_request)
          { session_ids: developer_session_ids(merge_request) }
        end

        # MergedEvent carries no acting user, so fall back to who merged the MR.
        def resolve_current_user(_cloud_event, merge_request)
          merge_request.metrics&.merged_by
        end
      end
    end
  end
end
