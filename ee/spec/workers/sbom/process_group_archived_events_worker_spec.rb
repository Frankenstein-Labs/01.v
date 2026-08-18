# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ProcessGroupArchivedEventsWorker, feature_category: :dependency_management, type: :job do
  let_it_be(:group) { create(:group) }
  let_it_be(:project_1) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group) }

  let(:event) do
    ::Namespaces::Groups::GroupArchivedEvent.new(data: {
      group_id: group.id,
      root_namespace_id: group.id
    })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always
  it_behaves_like 'subscribes to event'

  subject(:use_event) { consume_event(subscriber: described_class, event: event) }

  it 'delegates to SyncGroupArchivedStatusService' do
    expect(Sbom::SyncGroupArchivedStatusService).to receive(:new).with(group.id).and_call_original

    use_event
  end

  context 'when group does not exist' do
    let(:event) do
      ::Namespaces::Groups::GroupArchivedEvent.new(data: {
        group_id: non_existing_record_id,
        root_namespace_id: non_existing_record_id
      })
    end

    it 'still calls SyncGroupArchivedStatusService' do
      expect(Sbom::SyncGroupArchivedStatusService).to receive(:new).with(non_existing_record_id).and_call_original

      use_event
    end
  end
end
