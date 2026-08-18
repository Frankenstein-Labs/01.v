# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::PipelineArtifactState, :geo, feature_category: :geo_replication do
  include Ci::PartitioningHelpers

  before do
    stub_current_partition_id(ci_testing_partition_id)
  end

  let_it_be(:pipeline, freeze: true) { create(:ci_pipeline, partition_id: ci_testing_partition_id) }
  let_it_be_with_reload(:pipeline_artifact) do
    create(:ci_pipeline_artifact, pipeline: pipeline, partition_id: ci_testing_partition_id)
  end

  describe 'associations' do
    it 'belongs to pipeline_artifact' do
      is_expected.to belong_to(:pipeline_artifact)
                       .class_name('Ci::PipelineArtifact')
                       .inverse_of(:pipeline_artifact_state)
    end

    it 'scopes the pipeline_artifact association by partition' do
      # Create artifacts in different partitions
      other_partition_id = ci_testing_partition_id + 1
      other_pipeline = create(:ci_pipeline, partition_id: other_partition_id)
      other_artifact = create(:ci_pipeline_artifact, pipeline: other_pipeline, partition_id: other_partition_id)

      # Create a state but try to associate it with an artifact from a different partition
      state = build(:geo_pipeline_artifact_state, pipeline_artifact_id: other_artifact.id,
        partition_id: ci_testing_partition_id)

      # When loading the association, it should respect the partition scope
      expect(state.pipeline_artifact).to be_nil # Because it's in a different partition
    end

    it 'includes partition scope when accessing pipeline_artifact_state association' do
      create(:geo_pipeline_artifact_state,
        pipeline_artifact: pipeline_artifact,
        partition_id: ci_testing_partition_id)

      pipeline_artifact.reload

      # Verify the association query includes the partition scope
      association_scope = pipeline_artifact.association(:pipeline_artifact_state).scope

      # Check that the SQL includes the partition condition
      expect(association_scope.to_sql).to include("partition_id")
      expect(association_scope.to_sql).to include(ci_testing_partition_id.to_s)
    end
  end

  describe 'partitioning' do
    it 'copies the partition_id from the pipeline_artifact' do
      state = build(:geo_pipeline_artifact_state, pipeline_artifact: pipeline_artifact)
      expect { state.valid? }.to change { state.partition_id }.from(nil).to(ci_testing_partition_id)
    end

    context 'when it is already set' do
      let_it_be(:state, freeze: true) do
        build(:geo_pipeline_artifact_state, pipeline_artifact: pipeline_artifact, partition_id: ci_testing_partition_id)
      end

      it 'does not change the partition_id value' do
        expect(state.partition_id).to eq(ci_testing_partition_id)
      end
    end
  end
end
