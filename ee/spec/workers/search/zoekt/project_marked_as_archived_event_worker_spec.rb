# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ProjectMarkedAsArchivedEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { ::Projects::ProjectArchivedEvent.new(data: data) }
  let_it_be(:project) { create(:project) }
  let_it_be(:_zoekt_repo) { create(:zoekt_repository, project: project) }

  let(:data) do
    { project_id: project.id, namespace_id: project.namespace.id, root_namespace_id: project.root_ancestor.id }
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
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

    context 'when zoekt is enabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
      end

      it 'handles the event for archived project' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to raise_error
      end

      it 'creates a Search::Zoekt::Task with correct project_identifier and task_type' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Task.count }.by(1)

        task = Search::Zoekt::Task.last
        expect(task.project_identifier).to eq(project.id)
        expect(task).to be_index_repo
      end
    end
  end
end
