# frozen_string_literal: true

module Ci
  module PipelineExecutionPolicyHelpers
    def build_mock_policy_pipeline(config)
      build_mock_pipeline(config, config.keys)
    end

    def build_mock_pipeline(config, stages)
      build(:ci_pipeline, project: project).tap do |pipeline|
        pipeline.stages = config.map do |(stage, builds)|
          stage_idx = stages.index(stage)
          build(:ci_stage, name: stage, position: stage_idx, pipeline: pipeline).tap do |s|
            s.statuses = builds.map { |name| build(:ci_build, name: name, stage_idx: stage_idx, pipeline: pipeline) }
          end
        end
      end
    end

    def build_job_needs(job:, needs:)
      job.needs = build_list(:ci_build_need, 1, build: needs, name: needs.name)
    end

    def get_stage_jobs(pipeline, stage_name)
      stage = pipeline.stages.find { |stage| stage.name == stage_name }
      stage.statuses.map(&:name)
    end

    def get_job_needs(pipeline, stage_name, job_name)
      stage = pipeline.stages.find { |stage| stage.name == stage_name }
      job = stage.statuses.find { |status| status.name == job_name }
      job.needs.map(&:name)
    end
  end
end
