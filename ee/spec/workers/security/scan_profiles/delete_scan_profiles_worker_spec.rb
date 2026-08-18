# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::DeleteScanProfilesWorker, feature_category: :security_policy_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:scan_profile1) { create(:security_scan_profile, namespace: namespace, name: "profile_1") }
    let_it_be(:scan_profile2) { create(:security_scan_profile, namespace: namespace, name: "profile_2") }
    let_it_be(:scan_profile3) { create(:security_scan_profile, namespace: namespace, name: "profile_3") }

    let(:scan_profile_ids) { [scan_profile1.id, scan_profile2.id, scan_profile3.id] }
    let(:namespace_id) { namespace.id }
    let(:delete_service) { Security::ScanProfiles::DeleteScanProfileService }
    let(:lease_key) { Security::ScanProfiles.update_lease_key(namespace_id) }

    subject(:perform) { worker.perform(scan_profile_ids, namespace_id) }

    before do
      allow(delete_service).to receive(:execute)
    end

    context 'when scan_profile_ids is not empty' do
      it 'calls DeleteScanProfileService for each scan profile id' do
        perform

        expect(delete_service).to have_received(:execute).with(scan_profile1.id)
        expect(delete_service).to have_received(:execute).with(scan_profile2.id)
        expect(delete_service).to have_received(:execute).with(scan_profile3.id)
      end

      it 'uses in_lock for processing' do
        expect(worker).to receive(:in_lock)
          .with(lease_key, ttl: described_class::LEASE_TTL, sleep_sec: described_class::LEASE_TRY_AFTER)
          .and_call_original

        perform
      end
    end

    context 'when namespace_id is nil' do
      let(:namespace_id) { nil }

      it 'does not use locking' do
        expect(worker).not_to receive(:in_lock)

        perform
      end

      it 'still calls DeleteScanProfileService for each scan profile id' do
        perform

        expect(delete_service).to have_received(:execute).with(scan_profile1.id)
        expect(delete_service).to have_received(:execute).with(scan_profile2.id)
        expect(delete_service).to have_received(:execute).with(scan_profile3.id)
      end
    end

    context 'when scan_profile_ids is empty' do
      let(:scan_profile_ids) { [] }

      it 'does not call DeleteScanProfileService' do
        perform

        expect(delete_service).not_to have_received(:execute)
      end

      it 'does not use locking' do
        expect(worker).not_to receive(:in_lock)

        perform
      end
    end

    describe 'parallel execution' do
      include ExclusiveLeaseHelpers

      let(:lease_ttl) { described_class::LEASE_TTL }

      context 'when namespace_id is present' do
        context 'when the same lease key has already been taken by an already running job' do
          before do
            stub_exclusive_lease_taken(lease_key, timeout: lease_ttl)
          end

          it 'raises FailedToObtainLockError when lock cannot be obtained' do
            expect { perform }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
          end
        end
      end

      context 'when namespace_id is nil' do
        let(:namespace_id) { nil }

        it 'does not attempt to obtain a lock' do
          expect(worker).not_to receive(:in_lock)

          perform
        end
      end
    end
  end
end
