# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::RemoveOldDependencyGraphsWorker, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:now) { Time.zone.now }
  let_it_be(:yesterday) { now - 1.day }
  let_it_be(:old_graph) { create_list(:sbom_graph_path, 4, project: project, created_at: yesterday) }
  let_it_be(:new_graph) { create_list(:sbom_graph_path, 4, project: project, created_at: now) }

  let(:worker) { described_class.new }
  let(:job_args) { [project.id] }

  it_behaves_like 'an idempotent worker'

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  describe '#perform' do
    subject(:perform) { worker.perform(*job_args) }

    context 'when runtime limit is reached' do
      before do
        allow_next_instance_of(Gitlab::Metrics::RuntimeLimiter) do |runtime_limiter|
          allow(runtime_limiter).to receive(:over_time?).and_return(true)
        end
      end

      it 'schedules itself in 2 minutes', :freeze_time do
        expect(described_class).to receive(:perform_in).with(described_class::RESCHEDULE_TIMEOUT, project.id)

        perform
      end

      it 'logs information about runtime limit being reached' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(
          :result, {
            job_status: Sbom::RemoveOldDependencyGraphs::RUNTIME_LIMIT_REACHED,
            deleted: 4
          }
        )

        perform
      end
    end

    context 'when runtime limit is not reached' do
      it 'does not schedule itself again' do
        expect(described_class).not_to receive(:perform_in)

        perform
      end

      it 'logs information about success' do
        expect(worker).to receive(:log_extra_metadata_on_done).with(
          :result, {
            job_status: Sbom::RemoveOldDependencyGraphs::COMPLETED,
            deleted: 4
          }
        )

        perform
      end
    end
  end
end
