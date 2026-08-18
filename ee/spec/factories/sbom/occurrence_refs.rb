# frozen_string_literal: true

FactoryBot.define do
  factory :sbom_occurrence_ref, class: 'Sbom::OccurrenceRef' do
    pipeline { association :ci_pipeline }
    project { pipeline.project }
    commit_sha { pipeline.sha }
    occurrence { association :sbom_occurrence, project: project, pipeline: pipeline }
    tracked_context { association :security_project_tracked_context, project: project }
  end
end
