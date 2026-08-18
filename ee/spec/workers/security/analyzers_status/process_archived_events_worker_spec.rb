# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::ProcessArchivedEventsWorker, feature_category: :security_asset_inventories, type: :job do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let(:event) do
    ::Projects::ProjectArchivedEvent.new(data: {
      project_id: project.id,
      namespace_id: group.id,
      root_namespace_id: group.id
    })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky
  it_behaves_like 'subscribes to event'

  subject(:use_event) { consume_event(subscriber: described_class, event: event) }

  context 'when the project exists' do
    it 'calls the UpdateArchivedService with the project' do
      expect(Security::AnalyzersStatus::UpdateArchivedService).to receive(:execute).with(project)

      use_event
    end

    it 'calls the RecalculateService with the project' do
      expect(Security::AnalyzerNamespaceStatuses::RecalculateService).to receive(:execute).with(group)

      use_event
    end
  end

  context 'when the project does not exist' do
    before do
      allow(Project).to receive(:find_by_id).and_return(nil)
      allow(Group).to receive(:find_by_id).and_return(nil)
    end

    it 'does not call the UpdateArchivedService' do
      expect(Security::AnalyzersStatus::UpdateArchivedService).not_to receive(:execute)

      use_event
    end

    it 'does not call the RecalculateService' do
      expect(Security::AnalyzerNamespaceStatuses::RecalculateService).not_to receive(:execute)

      use_event
    end
  end
end
