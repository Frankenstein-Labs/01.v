# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::ProcessGroupTransferEventsWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  describe '#handle_event' do
    let_it_be(:parent_group) { create(:group) }

    let(:event) do
      Groups::GroupTransferedEvent.new(data: {
        group_id: group_id,
        old_root_namespace_id: parent_group.id,
        new_root_namespace_id: parent_group.id
      })
    end

    let(:update_ancestors_service) { Vulnerabilities::NamespaceStatistics::UpdateGroupAncestorsStatisticsService }
    let(:update_traversal_service) { Vulnerabilities::NamespaceStatistics::UpdateTraversalIdsService }

    subject(:handle_event) { worker.handle_event(event) }

    before do
      allow(update_ancestors_service).to receive(:execute)
      allow(update_traversal_service).to receive(:execute)
    end

    context 'when there is no group associated with the event' do
      let(:group_id) { non_existing_record_id }

      it 'does not call the service layer logic' do
        handle_event

        expect(update_ancestors_service).not_to have_received(:execute)
        expect(update_traversal_service).not_to have_received(:execute)
      end
    end

    context 'when there is a group associated with the event' do
      let(:group) { create(:group) }
      let(:group_id) { group.id }

      it 'calls the service layer logic' do
        handle_event

        expect(update_ancestors_service).to have_received(:execute).with(group)
        expect(update_traversal_service).to have_received(:execute).with(group)
      end
    end
  end
end
