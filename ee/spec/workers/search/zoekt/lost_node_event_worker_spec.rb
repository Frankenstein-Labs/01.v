# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::LostNodeEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let_it_be_with_reload(:node) { create(:zoekt_node, :lost) }
  let_it_be(:zoekt_index) { create(:zoekt_index, node: node) }
  let_it_be(:zoekt_repository) { create(:zoekt_repository, zoekt_index: zoekt_index) }
  let_it_be(:zoekt_task) { create(:zoekt_task, zoekt_repository: zoekt_repository, node: node) }
  let(:data) do
    { zoekt_node_id: node.id }
  end

  let(:event) { Search::Zoekt::LostNodeEvent.new(data: data) }
  let(:worker) { described_class.new }

  subject(:execute_event) { worker.perform(event.class.name, event.data) }

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    before do
      allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return true
      allow(::Search::Zoekt::Settings).to receive(:lost_node_threshold).and_return(12.hours)
    end

    context 'when node can not be found' do
      let(:data) do
        { zoekt_node_id: non_existing_record_id }
      end

      it 'does not deletes anything' do
        expect { execute_event }.not_to change { Search::Zoekt::Node.count }
        expect { execute_event }.not_to change { Search::Zoekt::Task.count }
        expect { execute_event }.not_to change { Search::Zoekt::Repository.count }
        expect { execute_event }.not_to change { Search::Zoekt::Index.count }
      end
    end

    context 'when marking_lost_enabled? is false' do
      before do
        allow(Search::Zoekt::Node).to receive(:marking_lost_enabled?).and_return false
      end

      it 'does not deletes anything' do
        expect { execute_event }.not_to change { Search::Zoekt::Node.count }
        expect { execute_event }.not_to change { Search::Zoekt::Task.count }
        expect { execute_event }.not_to change { Search::Zoekt::Repository.count }
        expect { execute_event }.not_to change { Search::Zoekt::Index.count }
      end
    end

    context 'when node is not lost' do
      before do
        node.update_column :last_seen_at, Time.zone.now
      end

      it 'does not deletes anything' do
        expect { execute_event }.not_to change { Search::Zoekt::Node.count }
        expect { execute_event }.not_to change { Search::Zoekt::Task.count }
        expect { execute_event }.not_to change { Search::Zoekt::Repository.count }
        expect { execute_event }.not_to change { Search::Zoekt::Index.count }
      end
    end

    it 'deletes the given node, tasks, indices and repositories attached to this node' do
      expect(Search::Zoekt::Node.all).to include(node)
      expect(Search::Zoekt::Task.all).to include(zoekt_task)
      expect(Search::Zoekt::Repository.all).to include(zoekt_repository)
      expect(Search::Zoekt::Index.all).to include(zoekt_index)
      indices_count = node.indices.count
      repos_count = node.indices.reduce(0) { |sum, index| sum + index.zoekt_repositories.count }
      log_data = {
        node_id: node.id, node_name: node.metadata[:name], metadata: hash_including(
          deleted_repos_count: repos_count, deleted_indices_count: indices_count,
          transaction_time: a_kind_of(Float)
        )
      }
      expect(worker).to receive(:log_hash_metadata_on_done).with(log_data)
      execute_event
      expect(Search::Zoekt::Node.all).not_to include(node)
      expect(Search::Zoekt::Task.all).to include(zoekt_task)
      expect(Search::Zoekt::Repository.all).not_to include(zoekt_repository)
      expect(Search::Zoekt::Index.all).not_to include(zoekt_index)
    end
  end
end
