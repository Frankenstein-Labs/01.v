# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::JobArtifactState, :geo, type: :model, feature_category: :geo_replication do
  include Ci::PartitioningHelpers

  describe 'partitioning' do
    let_it_be(:job_artifact, freeze: true) { build(:ee_ci_job_artifact, partition_id: ci_testing_partition_id) }
    let(:state) { build(:geo_job_artifact_state, job_artifact: job_artifact) }

    it 'copies the partition_id from the job_artifact' do
      expect { state.valid? }.to change { state.partition_id }.to(ci_testing_partition_id)
    end

    context 'when it is already set' do
      let(:state) { build(:geo_job_artifact_state, job_artifact: job_artifact, partition_id: ci_testing_partition_id) }

      it 'does not change the partition_id value' do
        expect(state.partition_id).to eq(ci_testing_partition_id)
      end
    end
  end
end
