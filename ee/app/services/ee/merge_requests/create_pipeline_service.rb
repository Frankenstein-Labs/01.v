# frozen_string_literal: true

module EE
  module MergeRequests
    module CreatePipelineService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(merge_request)
        response = create_merged_result_pipeline_for(merge_request)

        return response if response.success?

        super
      end

      def allowed?(merge_request)
        (
          merge_request.project.merge_pipelines_enabled? &&
          can_create_merged_result_pipeline_for?(merge_request) &&
          user_can_run_pipeline?(merge_request)
        ) || super
      end

      private

      def create_merged_result_pipeline_for(merge_request)
        unless merge_request.project.merge_pipelines_enabled?
          return ServiceResponse.error(
            message: 'Cannot create a pipeline for this merge request: merge pipelines not enabled'
          )
        end

        duplicate_error = check_duplicate_pipeline(merge_request)
        return duplicate_error if duplicate_error

        result = ::MergeRequests::MergeabilityCheckService.new(merge_request).execute(recheck: true)

        if result.success? || result.reason == :merge_status_race
          ref_payload = result.payload.fetch(:merge_ref_head)

          ::Ci::CreatePipelineService
            .new(merge_request.target_project, current_user,
              ref: merge_request.merge_ref_path,
              checkout_sha: ref_payload[:commit_id],
              target_sha: ref_payload[:target_id],
              source_sha: ref_payload[:source_id],
              pipeline_creation_request: params[:pipeline_creation_request],
              push_options: params[:push_options],
              defer_request_completion: params[:defer_request_completion])
            .execute(:merge_request_event, merge_request: merge_request)
        else
          cannot_create_pipeline_error('mergeability check failed')
        end
      end

      def can_create_merged_result_pipeline_for?(merge_request)
        return false unless can_create_pipeline_in_target_project?(merge_request)

        return false if merge_request.has_no_commits?

        true
      end
    end
  end
end
