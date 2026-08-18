# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ProjectPathChangedEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { ::Projects::ProjectPathChangedEvent.new(data: data) }
  let_it_be(:project) { create(:project) }
  let_it_be(:_zoekt_repo) { create(:zoekt_repository, project: project) }

  let(:data) do
    {
      project_id: project.id,
      namespace_id: project.namespace.id,
      root_namespace_id: project.root_ancestor.id,
      old_path: 'foo',
      new_path: 'bar'
    }
  end

  it_behaves_like 'subscribes to event'
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  context 'when zoekt is disabled' do
    before do
      allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return false
    end

    it 'does not create any indexing tasks' do
      expect do
        consume_event(subscriber: described_class, event: event)
      end.not_to change { Search::Zoekt::Task.count }
    end
  end

  context 'when the project does not exist' do
    before do
      allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
    end

    let(:data) do
      {
        project_id: non_existing_record_id,
        namespace_id: project.namespace.id,
        root_namespace_id: project.root_ancestor.id,
        old_path: 'foo',
        new_path: 'bar'
      }
    end

    it 'does not create any indexing tasks' do
      expect { consume_event(subscriber: described_class, event: event) }.not_to change { Search::Zoekt::Task.count }
    end
  end

  it_behaves_like 'an idempotent worker' do
    before do
      allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
    end

    it 'handles the event without error' do
      expect { consume_event(subscriber: described_class, event: event) }.not_to raise_error
    end

    it 'creates a Search::Zoekt::Task with correct project_identifier and task_type' do
      expect { consume_event(subscriber: described_class, event: event) }.to change { Search::Zoekt::Task.count }.by(1)

      task = Search::Zoekt::Task.find_by_project_identifier(project.id)
      expect(task).to be_force_index_repo
    end
  end
end
