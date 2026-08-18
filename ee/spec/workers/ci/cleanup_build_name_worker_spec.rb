# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CleanupBuildNameWorker, feature_category: :continuous_integration do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:current_partition) { create(:ci_partition, :current, id: 205) }
    let_it_be(:previous_partition) { create(:ci_partition, :active, id: 204) }
    let_it_be(:old_partition_1) { create(:ci_partition, :active, id: 203) }
    let_it_be(:old_partition_2) { create(:ci_partition, :active, id: 202) }
    let(:table_name) { "ci_build_names" }
    let(:build_name_partitions) do
      [
        Gitlab::Database::Partitioning::MultipleNumericListPartition.new(
          table_name, 205, partition_name: "#{table_name}_205"
        ),
        Gitlab::Database::Partitioning::MultipleNumericListPartition.new(
          table_name, 204, partition_name: "#{table_name}_204"
        ),
        Gitlab::Database::Partitioning::MultipleNumericListPartition.new(
          table_name, 203, partition_name: "#{table_name}_203"
        ),
        Gitlab::Database::Partitioning::MultipleNumericListPartition.new(
          table_name, 202, partition_name: "#{table_name}_202"
        )
      ]
    end

    context 'when partitioned tables exist' do
      before do
        allow(Ci::BuildName).to receive_message_chain(:partitioning_strategy, :current_partitions)
          .and_return(build_name_partitions)
        allow(Ci::BuildName).to receive_message_chain(:in_partition, :any?).and_return(true)
      end

      it 'truncates old partition tables' do
        expect(Ci::ApplicationRecord.connection).not_to receive(:execute)
          .with('TRUNCATE TABLE "gitlab_partitions_dynamic"."ci_build_names_205"')
        expect(Ci::ApplicationRecord.connection).not_to receive(:execute)
          .with('TRUNCATE TABLE "gitlab_partitions_dynamic"."ci_build_names_204"')
        expect(Ci::ApplicationRecord.connection).to receive(:execute)
          .with('TRUNCATE TABLE "gitlab_partitions_dynamic"."ci_build_names_203"')
        expect(Ci::ApplicationRecord.connection).to receive(:execute)
          .with('TRUNCATE TABLE "gitlab_partitions_dynamic"."ci_build_names_202"')

        worker.perform
      end

      context 'when no old partitions exist' do
        before do
          old_partition_1.destroy!
          old_partition_2.destroy!
        end

        it 'does not truncate any tables' do
          expect(Ci::ApplicationRecord.connection).not_to receive(:execute)

          worker.perform
        end
      end
    end

    context 'when partitioned table does not exist' do
      before do
        allow(worker).to receive(:partitioned_table_exists?).and_return(false)
        allow(Ci::ApplicationRecord.connection).to receive(:execute)
      end

      it 'skips truncation for non-existent tables' do
        worker.perform

        expect(Ci::ApplicationRecord.connection).not_to have_received(:execute)
      end
    end
  end
end
