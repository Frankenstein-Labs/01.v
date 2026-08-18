# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::DeleteScanProfileService, feature_category: :security_policy_management do
  describe '.execute' do
    let(:scan_profile_id) { 123 }
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute_class_method) { described_class.execute(scan_profile_id) }

    before do
      allow(described_class).to receive(:new).and_return(mock_service_object)
    end

    it 'instantiates the service object with scan_profile_id and calls execute', :aggregate_failures do
      execute_class_method

      expect(described_class).to have_received(:new).with(scan_profile_id: scan_profile_id)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:scan_profile) { create(:security_scan_profile, namespace: namespace) }
    let_it_be(:project1) { create(:project, group: namespace) }
    let_it_be(:project2) { create(:project, group: namespace) }
    let_it_be(:project3) { create(:project, group: namespace) }

    let(:scan_profile_id) { scan_profile.id }
    let(:service) { described_class.new(scan_profile_id: scan_profile_id) }

    subject(:execute) { service.execute }

    context 'when scan profile exists' do
      let!(:connection1) { create(:security_scan_profile_project, scan_profile: scan_profile, project: project1) }
      let!(:connection2) { create(:security_scan_profile_project, scan_profile: scan_profile, project: project2) }
      let!(:connection3) { create(:security_scan_profile_project, scan_profile: scan_profile, project: project3) }
      let!(:status1) { create(:scan_profile_project_status, scan_profile: scan_profile, project: project1) }
      let!(:status2) { create(:scan_profile_project_status, scan_profile: scan_profile, project: project2) }

      it 'deletes all profile connections, statuses, and the scan profile', :aggregate_failures do
        expect { execute }.to change { Security::ScanProfileProject.count }.by(-3)
          .and change { Security::ScanProfileProjectStatus.count }.by(-2)
          .and change { Security::ScanProfile.count }.by(-1)

        expect(Security::ScanProfile.exists?(scan_profile.id)).to be(false)
      end
    end

    context 'when scan profile has no connections' do
      it 'deletes the scan profile' do
        expect { execute }.to change { Security::ScanProfile.count }.by(-1)
      end
    end

    context 'when the scan profile is already soft-deleted' do
      let!(:connection1) { create(:security_scan_profile_project, scan_profile: scan_profile, project: project1) }

      before do
        # Re-find to avoid mutating the frozen let_it_be record; soft-delete sets
        # deleted_at and keeps the row.
        Security::ScanProfile.find(scan_profile.id).destroy!
      end

      it 'still hard-deletes the profile and its connections', :aggregate_failures do
        expect { execute }.to change { Security::ScanProfileProject.count }.by(-1)
          .and change { Security::ScanProfile.count }.by(-1)

        expect(Security::ScanProfile.exists?(scan_profile.id)).to be(false)
      end
    end

    context 'when scan profile does not exist or is nil' do
      where(:scan_profile_id) { [nil, non_existing_record_id] }

      with_them do
        it 'does not delete any connections or profiles' do
          expect { execute }.not_to change { Security::ScanProfile.count }
        end
      end
    end

    context 'with batch deleting behavior' do
      let!(:connection1) { create(:security_scan_profile_project, scan_profile: scan_profile, project: project1) }
      let!(:connection2) { create(:security_scan_profile_project, scan_profile: scan_profile, project: project2) }
      let!(:status1) { create(:scan_profile_project_status, scan_profile: scan_profile, project: project1) }
      let!(:status2) { create(:scan_profile_project_status, scan_profile: scan_profile, project: project2) }

      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it 'deletes connections and statuses in batches', :aggregate_failures do
        expect(Security::ScanProfileProject).to receive(:each_batch).with(of: 1).and_call_original
        expect(Security::ScanProfileProjectStatus).to receive(:each_batch).with(of: 1).and_call_original

        execute

        expect(Security::ScanProfileProject.for_scan_profile(scan_profile.id)).to be_empty
        expect(Security::ScanProfileProjectStatus.for_scan_profile(scan_profile.id)).to be_empty
      end
    end

    context 'when scan profile belongs to another namespace' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:other_scan_profile) { create(:security_scan_profile, namespace: other_namespace) }
      let_it_be(:other_project) { create(:project, group: other_namespace) }

      let!(:connection1) { create(:security_scan_profile_project, scan_profile: scan_profile, project: project1) }
      let!(:other_connection) do
        create(:security_scan_profile_project, scan_profile: other_scan_profile, project: other_project)
      end

      it 'only deletes connections for the specified scan profile' do
        execute

        expect(Security::ScanProfileProject.exists?(connection1.id)).to be(false)
        expect(Security::ScanProfileProject.exists?(other_connection.id)).to be(true)
      end
    end
  end
end
