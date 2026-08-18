# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::DeleteProjectEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Projects::ProjectDeletedEvent.new(data: data) }
  let_it_be(:project) { create(:project) }
  let(:data) do
    { project_id: project.id, namespace_id: project.namespace_id, root_namespace_id: project.root_namespace.id }
  end

  before do
    allow(::Search::Zoekt).to receive(:delete_async).and_return(true)
  end

  it_behaves_like 'subscribes to event'
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  context 'when zoekt is disabled' do
    before do
      allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return false
    end

    it 'does not schedules deletion operation' do
      expect(::Search::Zoekt).not_to receive(:delete_async)
      consume_event(subscriber: described_class, event: event)
    end
  end

  it_behaves_like 'an idempotent worker' do
    before do
      allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
    end

    it 'schedules deletion operation' do
      expect(::Search::Zoekt).to receive(:delete_async).with(project.id, root_namespace_id: project.root_namespace.id)
      consume_event(subscriber: described_class, event: event)
    end
  end
end
