# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceHistoricalStatistics::ProcessTransferEventsWorker, feature_category: :vulnerability_management do
  let(:worker) { described_class.new }

  describe '#handle_event' do
    let_it_be(:parent_group) { create(:group) }

    let(:service_layer_logic) do
      Vulnerabilities::NamespaceHistoricalStatistics::ScheduleUpdatingTraversalIdsForHierarchyService
    end

    let(:event) do
      Groups::GroupTransferedEvent.new(data: {
        group_id: group_id,
        old_root_namespace_id: parent_group.id,
        new_root_namespace_id: parent_group.id
      })
    end

    subject(:handle_event) { worker.handle_event(event) }

    before do
      allow(service_layer_logic).to receive(:execute)
    end

    context 'when there is no group associated with the event' do
      let(:group_id) { non_existing_record_id }

      it 'does not call the service layer logic' do
        handle_event

        expect(service_layer_logic).not_to have_received(:execute)
      end
    end

    context 'when there is a group associated with the event' do
      let(:group) { create(:group) }
      let(:group_id) { group.id }

      it 'calls the service layer logic' do
        handle_event

        expect(service_layer_logic).to have_received(:execute).with(group)
      end
    end
  end
end
