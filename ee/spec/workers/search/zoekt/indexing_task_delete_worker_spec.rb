# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexingTaskDeleteWorker, feature_category: :global_search do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe '#perform', :zoekt_settings_enabled do
    subject(:perform_worker) { described_class.new.perform(*job_args) }

    let_it_be(:project) { create(:project) }
    let_it_be(:job_args) { [project.id, { 'node_id' => 1 }] }

    context 'when zoekt is not available' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return(false)
      end

      it_behaves_like 'an idempotent worker' do
        it 'does not call the IndexingTaskService service' do
          expect(Search::Zoekt::IndexingTaskService).not_to receive(:execute)
          perform_worker
        end
      end
    end

    context 'when zoekt is available' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      it_behaves_like 'an idempotent worker' do
        it 'calls the IndexingTaskService service with delete_repo task type' do
          expect(Search::Zoekt::IndexingTaskService).to receive(:execute)
            .with(project.id, 'delete_repo', node_id: 1)
          perform_worker
        end
      end
    end
  end
end
