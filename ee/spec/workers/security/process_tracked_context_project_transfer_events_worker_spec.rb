# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProcessTrackedContextProjectTransferEventsWorker, feature_category: :vulnerability_management do
  let_it_be(:old_namespace) { create(:group) }
  let_it_be(:new_namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: new_namespace) }
  let_it_be(:project_without_tracked_contexts) { create(:project, namespace: new_namespace) }

  let(:event) do
    ::Projects::ProjectTransferedEvent.new(data: {
      project_id: project.id,
      old_namespace_id: old_namespace.id,
      old_root_namespace_id: old_namespace.id,
      new_namespace_id: new_namespace.id,
      new_root_namespace_id: new_namespace.id
    })
  end

  before_all do
    create(:security_project_tracked_context, :tracked, project: project)
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  subject(:use_event) { consume_event(subscriber: described_class, event: event) }

  context 'when a project transfer event is published', :sidekiq_inline do
    it_behaves_like 'subscribes to event'

    it 'enqueues a sync job for the project id' do
      expect(::Security::SyncTrackedContextTraversalIdsWorker).to receive(:perform_async).with(project.id)

      use_event
    end
  end

  context 'when project does not have tracked contexts' do
    let(:project) { project_without_tracked_contexts }

    it 'does not enqueue a sync job' do
      expect(::Security::SyncTrackedContextTraversalIdsWorker).not_to receive(:perform_async)

      use_event
    end
  end
end
