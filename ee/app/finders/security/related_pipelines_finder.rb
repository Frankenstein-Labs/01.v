# frozen_string_literal: true

# Security::RelatedPipelinesFinder
#
# This finder returns the IDs of latest completed pipelines per given
# sources matching the SHA as the given pipeline. If the pipeline is a
# merged_request_pipeline, the source SHA of the pipeline is used to
# find the related pipelines.
#
# Arguments:
#   pipeline - pipeline for which the related pipelines should be returned
#   params:
#     sources:     Array<String>
#     ref:         String
module Security
  class RelatedPipelinesFinder
    attr_reader :pipeline, :params

    PIPELINES_LIMIT = 1_000

    def initialize(pipeline, params = {})
      @pipeline = pipeline
      @params = params
    end

    def execute
      pipelines = all_pipelines.no_tag
      pipelines = pipelines.for_branch(params[:ref]) if params[:ref].present?
      pipelines = pipelines.with_pipeline_source(params[:sources]) if params[:sources].present?
      pipelines = latest_completed_pipelines_matching_sha(pipelines)

      # Using map here as `pluck` would not work due to usage of `SELECT DISTINCT ON`
      pipeline_ids = pipelines.map(&:id)

      # rubocop:disable CodeReuse/ActiveRecord -- number of pipelines is limited by source
      Ci::Pipeline
        .object_hierarchy(all_pipelines.id_in(pipeline_ids), project_condition: :same)
        .base_and_descendant_ids.limit(PIPELINES_LIMIT).pluck(:id)
      # rubocop:enable CodeReuse/ActiveRecord
    end

    private

    delegate :project, to: :pipeline

    def all_pipelines
      project.all_pipelines
    end

    def latest_completed_pipelines_matching_sha(pipelines)
      # merged_result_pipeline should include itself and the pipelines with source_sha
      sha = pipeline.merged_result_pipeline? ? [pipeline.source_sha, pipeline.sha] : pipeline.sha
      Ci::Pipeline.latest_limited_pipeline_ids_per_source(pipelines, sha)
    end
  end
end
