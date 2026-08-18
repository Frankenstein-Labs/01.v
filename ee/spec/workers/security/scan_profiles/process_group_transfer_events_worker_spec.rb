# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::ProcessGroupTransferEventsWorker, feature_category: :security_policy_management do
  let(:worker) { described_class.new }
  let(:group_transfer_event) do
    Groups::GroupTransferedEvent.new(data: {
      group_id: group_id,
      old_root_namespace_id: old_root_namespace_id,
      new_root_namespace_id: new_root_namespace_id
    })
  end

  let_it_be(:old_root_namespace) { create(:group) }
  let_it_be(:new_root_namespace) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: new_root_namespace) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:scan_profile1) { create(:security_scan_profile, namespace: root_group, name: "scan profile 1") }
  let_it_be(:scan_profile2) { create(:security_scan_profile, namespace: root_group, name: "scan profile 2") }

  let(:group_id) { subgroup.id }
  let(:old_root_namespace_id) { old_root_namespace.id }
  let(:new_root_namespace_id) { new_root_namespace.id }
  let(:cleanup_worker) { Security::ScanProfiles::CleanOldNamespaceConnectionsWorker }
  let(:delete_profiles_worker) { Security::ScanProfiles::DeleteScanProfilesWorker }

  subject(:perform) { worker.handle_event(group_transfer_event) }

  describe '#perform' do
    before do
      allow(cleanup_worker).to receive(:perform_async)
      allow(delete_profiles_worker).to receive(:perform_async)
    end

    context 'when root namespace has not changed' do
      let(:old_root_namespace_id) { new_root_namespace.id }

      it 'does not schedule any workers' do
        perform

        expect(cleanup_worker).not_to have_received(:perform_async)
        expect(delete_profiles_worker).not_to have_received(:perform_async)
      end
    end

    context 'when moved group no longer exists' do
      let(:group_id) { non_existing_record_id }

      it 'does not schedule any workers' do
        perform

        expect(cleanup_worker).not_to have_received(:perform_async)
        expect(delete_profiles_worker).not_to have_received(:perform_async)
      end
    end

    context 'when root namespace has changed and group exists' do
      context 'when group was a subgroup (moved between different root namespaces)' do
        it 'schedules cleanup worker to delete project connections' do
          perform

          expect(cleanup_worker).to have_received(:perform_async).with(subgroup.id, true)
        end

        it 'does not schedule delete profiles worker' do
          perform

          expect(delete_profiles_worker).not_to have_received(:perform_async)
        end
      end

      context 'when group was a root and is now a subgroup' do
        let_it_be(:new_parent) { create(:group) }

        let(:group_id) { root_group.id }
        let(:old_root_namespace_id) { root_group.id }
        let(:new_root_namespace_id) { new_parent.id }

        before do
          root_group.reload.update!(parent: new_parent)
        end

        it 'schedules delete profiles worker with profile ids' do
          perform

          expected_ids = [scan_profile1, scan_profile2].map(&:id)
          expect(delete_profiles_worker).to have_received(:perform_async) do |profile_ids, group_id|
            expect(profile_ids).to match_array(expected_ids)
            expect(group_id).to eq(root_group.id)
          end
        end

        it 'does not schedule cleanup worker' do
          perform

          expect(cleanup_worker).not_to have_received(:perform_async)
        end
      end
    end
  end
end
