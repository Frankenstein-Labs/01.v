# frozen_string_literal: true

module Security
  module PipelineExecutionPolicies
    class CancelPolicyPipelinesService
      include Gitlab::Utils::StrongMemoize

      def initialize(security_policy:, project:)
        @security_policy = security_policy
        @project = project
      end

      def execute
        return unless feature_enabled?
        return unless bot_user

        cancel_pipelines
      end

      private

      attr_reader :security_policy, :project

      def cancel_pipelines
        pipelines = Security::PolicySchedulePipeline.cancelable_pipelines_for(
          security_policy: security_policy,
          project: project
        )

        pipelines.each { |pipeline| cancel_pipeline(pipeline) }
      end

      def cancel_pipeline(pipeline)
        return unless pipeline.cancelable?

        Ci::CancelPipelineService.new(
          pipeline: pipeline,
          current_user: bot_user,
          cascade_to_children: true,
          execute_async: true
        ).force_execute
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e,
          pipeline_id: pipeline.id,
          project_id: project.id
        )
      end

      def bot_user
        project.security_policy_bot
      end
      strong_memoize_attr :bot_user

      def feature_enabled?
        policy_configuration = security_policy.security_orchestration_policy_configuration

        Feature.enabled?(
          :cancel_pipelines_when_policy_disabled,
          policy_configuration.namespace || policy_configuration.project.namespace
        )
      end
    end
  end
end
