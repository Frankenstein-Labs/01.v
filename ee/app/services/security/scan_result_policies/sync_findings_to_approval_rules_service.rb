# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class SyncFindingsToApprovalRulesService
      def initialize(pipeline)
        @project = pipeline.project
        @pipeline = if pipeline.child?
                      pipeline.root_ancestor
                    else
                      pipeline
                    end
      end

      def execute
        sync_scan_finding
      end

      private

      attr_reader :pipeline, :project

      def sync_scan_finding
        return unless Enums::Ci::Pipeline.ci_and_security_orchestration_sources.key?(pipeline.source.to_sym)

        pipeline_complete = pipeline.complete_or_manual?

        return if !pipeline_complete && !pipeline_has_security_findings?

        update_required_approvals_for_scan_finding
      end

      def update_required_approvals_for_scan_finding
        pipeline.opened_merge_requests_with_head_sha.each do |merge_request|
          update_approvals(merge_request)
        end

        # Ensure that approvals are in sync when the source branch pipeline
        # finishes before the target branch pipeline
        merge_requests_targeting_pipeline_ref.each do |merge_request|
          head_pipeline = merge_request.diff_head_pipeline || next

          Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker.perform_async(
            head_pipeline.id,
            merge_request.id)
        end
      end

      def pipeline_has_security_findings?
        pipeline.has_security_findings_in_self_and_descendants?
      end

      def update_approvals(merge_request)
        Security::ScanResultPolicies::SyncMergeRequestApprovalsWorker.perform_async(pipeline.id, merge_request.id)
      end

      def merge_requests_targeting_pipeline_ref
        return MergeRequest.none unless pipeline.latest?

        project
          .merge_requests
          .opened
          .by_target_branch(pipeline.ref)
      end
    end
  end
end
