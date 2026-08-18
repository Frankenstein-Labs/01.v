# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineArtifact, feature_category: :job_artifacts do
  include EE::GeoHelpers
  include Ci::PartitioningHelpers

  before do
    stub_current_partition_id(ci_testing_partition_id)
  end

  describe '.search' do
    let_it_be(:project1) do
      create(:project, name: 'project_1_name', path: 'project_1_path', description: 'project_desc_1')
    end

    let_it_be(:project2) do
      create(:project, name: 'project_2_name', path: 'project_2_path', description: 'project_desc_2')
    end

    let_it_be(:project3) do
      create(:project, name: 'another_name', path: 'another_path', description: 'another_description')
    end

    let_it_be(:pipeline1) { create(:ci_pipeline, project: project1) }
    let_it_be(:pipeline2) { create(:ci_pipeline, project: project2) }
    let_it_be(:pipeline3) { create(:ci_pipeline, project: project3) }

    let_it_be(:pipeline_artifact1) { create(:ci_pipeline_artifact, pipeline: pipeline1) }
    let_it_be(:pipeline_artifact2) { create(:ci_pipeline_artifact, pipeline: pipeline2) }
    let_it_be(:pipeline_artifact3) { create(:ci_pipeline_artifact, pipeline: pipeline3) }

    context 'when search query is empty' do
      it 'returns all records' do
        result = described_class.search('')

        expect(result).to contain_exactly(pipeline_artifact1, pipeline_artifact2, pipeline_artifact3)
      end
    end

    context 'when search query is not empty' do
      context 'without matches' do
        it 'filters all pipeline artifacts' do
          result = described_class.search('something_that_does_not_exist')

          expect(result).to be_empty
        end
      end

      context 'with matches' do
        context 'with project association' do
          it 'filters by project path' do
            result = described_class.search('project_1_PATH')

            expect(result).to contain_exactly(pipeline_artifact1)
          end

          it 'filters by project name' do
            result = described_class.search('Project_2_NAME')

            expect(result).to contain_exactly(pipeline_artifact2)
          end

          it 'filters project description' do
            result = described_class.search('Project_desc')

            expect(result).to contain_exactly(pipeline_artifact1, pipeline_artifact2)
          end
        end
      end
    end
  end

  describe 'Geo replication', feature_category: :geo_replication do
    before do
      stub_artifacts_object_storage
    end

    describe 'associations' do
      it 'has one verification state table class' do
        is_expected
          .to have_one(:pipeline_artifact_state)
                .class_name('Geo::PipelineArtifactState')
                .inverse_of(:pipeline_artifact)
                .autosave(false)
      end
    end

    include_examples 'a verifiable model for verification state' do
      let(:verifiable_model_record) do
        build(
          :ci_pipeline_artifact,
          pipeline: create(
            :ci_pipeline,
            project: create(:project),
            partition_id: ci_testing_partition_id
          ),
          partition_id: ci_testing_partition_id
        )
      end

      let(:unverifiable_model_record) do
        build(:ci_pipeline_artifact, :remote_store, # means it won't be in the verifiables scope
          pipeline: create(:ci_pipeline, partition_id: ci_testing_partition_id),
          partition_id: ci_testing_partition_id
        )
      end
    end

    describe 'replication/verification' do
      let_it_be(:group_1) { create(:group, organization: create(:organization)) }
      let_it_be(:group_2) { create(:group, organization: create(:organization)) }
      let_it_be(:nested_group_1) { create(:group, parent: group_1) }
      let_it_be(:project_1) { create(:project, group: group_1) }
      let_it_be(:project_2) { create(:project, group: nested_group_1) }
      let_it_be(:project_3) { create(:project, group: group_2) }
      let_it_be(:pipeline_1) { create(:ci_pipeline, project: project_1) }
      let_it_be(:pipeline_2) { create(:ci_pipeline, project: project_2) }
      let_it_be(:pipeline_3) { create(:ci_pipeline, project: project_3) }
      let_it_be(:pipeline_4) { create(:ci_pipeline, project: project_1) }

      # Pipeline artifact for the root group
      let_it_be(:first_replicable_and_in_selective_sync) do
        create(:ci_pipeline_artifact, pipeline: pipeline_1)
      end

      # Pipeline artifact for a subgroup
      let_it_be(:second_replicable_and_in_selective_sync) do
        create(:ci_pipeline_artifact, pipeline: pipeline_2)
      end

      # Pipeline artifact for a subgroup and on object storage
      let!(:third_replicable_on_object_storage_and_in_selective_sync) do
        create(:ci_pipeline_artifact, :remote_store, pipeline: pipeline_4)
      end

      # Pipeline artifact for a group not in selective sync
      let_it_be(:last_replicable_and_not_in_selective_sync) do
        create(:ci_pipeline_artifact, pipeline: pipeline_3)
      end

      include_examples 'Geo Framework selective sync behavior'
    end
  end

  describe '.create_verification_details_for' do
    let_it_be(:pipeline_with_partition) { create(:ci_pipeline, partition_id: ci_testing_partition_id) }
    let_it_be(:artifact1) do
      create(:ci_pipeline_artifact, pipeline: pipeline_with_partition,
        partition_id: ci_testing_partition_id, file_type: :code_coverage)
    end

    let_it_be(:artifact2) do
      create(:ci_pipeline_artifact, pipeline: pipeline_with_partition,
        partition_id: ci_testing_partition_id, file_type: :code_quality_mr_diff)
    end

    context 'when creating verification details for multiple artifacts' do
      it 'creates verification state records without duplicates' do
        primary_keys = [artifact1.id, artifact2.id]

        expect { described_class.create_verification_details_for(primary_keys) }
          .to change { Geo::PipelineArtifactState.count }.by(2)

        # Verify the records were created with correct attributes
        state1 = Geo::PipelineArtifactState.find_by(pipeline_artifact_id: artifact1.id,
          partition_id: ci_testing_partition_id)
        state2 = Geo::PipelineArtifactState.find_by(pipeline_artifact_id: artifact2.id,
          partition_id: ci_testing_partition_id)

        expect(state1).to be_present
        expect(state2).to be_present
        expect(state1.partition_id).to eq(ci_testing_partition_id)
        expect(state2.partition_id).to eq(ci_testing_partition_id)
      end
    end
  end
end
