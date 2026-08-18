# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::GroupPathChangedEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { ::Namespaces::Groups::GroupPathChangedEvent.new(data: data) }
  let_it_be(:group) { create(:group, :with_hierarchy) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group.children[0]) }
  let_it_be(:project3) { create(:project, group: group.children[0].children[1]) }
  let_it_be(:project4) { create(:project, group: group.children[1].children[2]) }
  let_it_be(:_zoekt_repo) { create(:zoekt_repository, project: project) }
  let_it_be(:_zoekt_repo2) { create(:zoekt_repository, project: project2) }
  let_it_be(:_zoekt_repo3) { create(:zoekt_repository, project: project3) }
  let_it_be(:_zoekt_repo4) { create(:zoekt_repository, project: project4) }

  let(:data) do
    { group_id: group.id }
  end

  it_behaves_like 'subscribes to event'
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  context 'when the group does not exist' do
    before do
      allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
    end

    let(:data) do
      { group_id: non_existing_record_id }
    end

    it 'does not create any indexing tasks' do
      expect { consume_event(subscriber: described_class, event: event) }.not_to change { Search::Zoekt::Task.count }
    end
  end

  context 'when zoekt is disabled' do
    before do
      allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return false
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
      expect { consume_event(subscriber: described_class, event: event) }.to change { Search::Zoekt::Task.count }.by(4)

      tasks = Search::Zoekt::Task.where(project_identifier: [project, project2, project3, project4].map(&:id))
      expect(tasks.size).to eq(4)
      expect(tasks.all?(&:force_index_repo?)).to be true
    end
  end
end
