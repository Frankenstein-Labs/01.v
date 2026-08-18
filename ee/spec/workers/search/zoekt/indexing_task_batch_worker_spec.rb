# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexingTaskBatchWorker, feature_category: :global_search do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe '#perform', :zoekt_settings_enabled do
    let_it_be(:project) { create(:project) }
    let_it_be(:project2) { create(:project) }
    let(:tasks) do
      [
        [project.id, 'index_repo', {}],
        [project2.id, 'force_index_repo', {}]
      ]
    end

    subject(:perform_worker) { described_class.new.perform(tasks) }

    context 'when zoekt settings is disabled' do
      before do
        stub_ee_application_setting(zoekt_indexing_enabled: false)
      end

      it 'does not call the IndexingTaskService service' do
        expect(Search::Zoekt::IndexingTaskService).not_to receive(:execute)
        perform_worker
      end
    end

    context 'when license zoekt_code_search is not available' do
      before do
        stub_licensed_features(zoekt_code_search: false)
      end

      it 'does not call the IndexingTaskService service' do
        expect(Search::Zoekt::IndexingTaskService).not_to receive(:execute)
        perform_worker
      end
    end

    it 'calls IndexingTaskService for each task in the batch' do
      expect(Search::Zoekt::IndexingTaskService).to receive(:execute)
        .with(project.id, 'index_repo').ordered
      expect(Search::Zoekt::IndexingTaskService).to receive(:execute)
        .with(project2.id, 'force_index_repo').ordered

      perform_worker
    end

    context 'when one task in the batch fails' do
      before do
        allow(Search::Zoekt::IndexingTaskService).to receive(:execute)
          .with(project.id, 'index_repo').and_raise(StandardError, 'test error')
        allow(Search::Zoekt::IndexingTaskService).to receive(:execute)
          .with(project2.id, 'force_index_repo')
      end

      it 'continues processing remaining tasks and tracks the error' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)
          .with(instance_of(StandardError), project_id: project.id, task_type: 'index_repo')
        expect(Search::Zoekt::IndexingTaskService).to receive(:execute)
          .with(project2.id, 'force_index_repo')

        perform_worker
      end
    end
  end
end
