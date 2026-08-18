# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::ProcessGroupTransferEventsWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }
  let(:event) do
    Groups::GroupTransferedEvent.new(data: {
      group_id: group_id,
      old_root_namespace_id: parent_group.id,
      new_root_namespace_id: parent_group.id
    })
  end

  let_it_be(:parent_group) { create(:group) }

  subject(:handle_event) { worker.handle_event(event) }

  describe '#handle_event' do
    let(:update_ancestors_service) { Security::AnalyzersStatus::UpdateGroupAncestorsStatusesService }
    let(:update_traversal_service) { Security::AnalyzersStatus::UpdateNamespaceTraversalIdsService }

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

      describe 'parallel execution' do
        include ExclusiveLeaseHelpers

        let(:lease_key) { "security:#{group_id}:process_group_transfer_events_worker" }
        let(:lease_ttl) { 5.minutes }

        before do
          stub_const("#{described_class}::LEASE_TRY_AFTER", 0.001)
          stub_exclusive_lease_taken(lease_key, timeout: lease_ttl)
        end

        context 'when the lock is locked' do
          it 'does not run its logic services' do
            expect(worker).to receive(:in_lock)
              .with(lease_key,
                ttl: described_class::LEASE_TTL,
                retries: described_class::LEASE_RETRIES,
                sleep_sec: described_class::LEASE_TRY_AFTER)

            expect(update_ancestors_service).not_to receive(:execute)
            expect(update_traversal_service).not_to receive(:execute)

            handle_event
          end

          it 'schedules a new job' do
            expect(worker).to receive(:in_lock)
              .with(lease_key,
                ttl: described_class::LEASE_TTL,
                retries: described_class::LEASE_RETRIES,
                sleep_sec: described_class::LEASE_TRY_AFTER)
              .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

            expect(described_class).to receive(:handle_event_in)
             .with(described_class::RETRY_IN_IF_LOCKED, event)

            handle_event
          end
        end
      end
    end
  end
end
