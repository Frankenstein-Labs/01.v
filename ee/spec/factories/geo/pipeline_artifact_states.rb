# frozen_string_literal: true

FactoryBot.define do
  factory :geo_pipeline_artifact_state, class: 'Geo::PipelineArtifactState' do
    pipeline_artifact factory: :ci_pipeline_artifact

    trait(:checksummed) do
      verification_checksum { 'abc' }
    end

    trait(:checksum_failure) do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
