# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ProcessTransferEventsWorker, feature_category: :dependency_management, type: :worker do
  let_it_be(:old_namespace) { create(:group) }
  let_it_be(:new_namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: new_namespace) }
  let_it_be(:other_project) { create(:project, namespace: new_namespace) }
  let_it_be(:project_without_dependencies) { create(:project, namespace: new_namespace) }

  let(:project_event) do
    ::Projects::ProjectTransferedEvent.new(data: {
      project_id: project.id,
      old_namespace_id: old_namespace.id,
      old_root_namespace_id: old_namespace.id,
      new_namespace_id: new_namespace.id,
      new_root_namespace_id: new_namespace.id
    })
  end

  let(:namespace_event) do
    ::Groups::GroupTransferedEvent.new(data: {
      group_id: new_namespace.id,
      old_root_namespace_id: old_namespace.id,
      new_root_namespace_id: new_namespace.id
    })
  end

  before_all do
    # We create two to ensure we aren't enqueuing duplicate IDs
    create_list(:sbom_occurrence, 2, project: project)
    create(:sbom_occurrence, project: other_project)
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  subject(:use_event) { consume_event(subscriber: described_class, event: event) }

  context 'when a project sync event is published', :sidekiq_inline do
    let(:event) { project_event }

    it_behaves_like 'subscribes to event'

    it 'enqueues a sync job for the project id' do
      expect(::Sbom::SyncProjectTraversalIdsWorker).to receive(:bulk_perform_async).with([[project.id]])

      use_event
    end
  end

  context 'when a namespace sync event is published', :sidekiq_inline do
    let(:event) { namespace_event }

    it_behaves_like 'subscribes to event'

    it 'enqueues a sync job for each project id belonging to the namespace id' do
      expect(::Sbom::SyncProjectTraversalIdsWorker).to receive(:bulk_perform_async).with(
        match_array([[project.id], [other_project.id]])
      )

      use_event
    end
  end

  context 'when project does not have dependencies' do
    let(:project) { project_without_dependencies }
    let(:event) { project_event }

    it 'does not enqueue a sync job' do
      expect(::Sbom::SyncProjectTraversalIdsWorker).to receive(:bulk_perform_async).with([])

      use_event
    end
  end
end
