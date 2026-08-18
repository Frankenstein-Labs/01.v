# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ascp::CreateScanService, feature_category: :static_application_security_testing do
  include ExclusiveLeaseHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, maintainer_of: project) }

  let(:commit_sha) { 'abc123def456' }
  let(:scan_type) { 'full' }
  let(:additional_params) { {} }
  let(:params) { { commit_sha: commit_sha, scan_type: scan_type, **additional_params } }

  subject(:result) { described_class.new(current_user: user, project: project, params: params).execute }

  before do
    stub_licensed_features(security_dashboard: true)
  end

  describe '#execute' do
    context 'when user does not have permission' do
      let_it_be(:user) { create(:user, guest_of: project) }

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to eq('Insufficient permissions')
      end

      it 'does not create a scan' do
        expect { result }.not_to change { Security::Ascp::Scan.count }
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to eq('Insufficient permissions')
      end

      it 'does not create a scan' do
        expect { result }.not_to change { Security::Ascp::Scan.count }
      end
    end

    context 'when creating a full scan' do
      it 'creates a scan with correct attributes' do
        expect { result }.to change { Security::Ascp::Scan.count }.by(1)
        expect(result).to be_success

        scan = result.payload[:scan]
        expect(scan).to have_attributes(
          project: project,
          commit_sha: commit_sha,
          scan_type: 'full',
          scan_sequence: 1
        )
      end
    end

    context 'when existing scans exist' do
      let_it_be(:existing_scan) { create(:security_ascp_scan, project: project, scan_sequence: 5) }

      it 'increments scan_sequence from the maximum' do
        expect(result).to be_success
        expect(result.payload[:scan].scan_sequence).to eq(6)
      end
    end

    context 'when creating an incremental scan with base_scan_id' do
      let_it_be(:base_scan) { create(:security_ascp_scan, :full, project: project) }

      let(:scan_type) { 'incremental' }
      let(:additional_params) { { base_scan_id: base_scan.id, base_commit_sha: 'base123' } }

      it 'resolves the base scan and creates an incremental scan' do
        expect(result).to be_success

        scan = result.payload[:scan]
        expect(scan).to have_attributes(
          scan_type: 'incremental',
          base_scan: base_scan,
          base_commit_sha: 'base123'
        )
      end
    end

    context 'when base_scan_id references a scan from a different project' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_scan) { create(:security_ascp_scan, :full, project: other_project) }

      let(:scan_type) { 'incremental' }
      let(:additional_params) { { base_scan_id: other_scan.id, base_commit_sha: 'base123' } }

      it 'returns an error because the base scan is not found in the project' do
        expect(result).to be_error
        expect(result.message).to include("Base scan can't be blank")
      end
    end

    context 'when base_scan_id does not exist' do
      let(:scan_type) { 'incremental' }
      let(:additional_params) { { base_scan_id: non_existing_record_id, base_commit_sha: 'base123' } }

      it 'returns an error because the base scan is not found' do
        expect(result).to be_error
        expect(result.message).to include("Base scan can't be blank")
      end
    end

    context 'when save fails due to validation' do
      let(:params) { { scan_type: 'full' } } # missing commit_sha

      it 'returns an error response' do
        expect(result).to be_error
        expect(result.message).to include("Commit sha can't be blank")
      end
    end

    describe 'scheduling ASCP component association' do
      context 'when the feature flag is enabled' do
        it 'enqueues the association worker on success' do
          expect(Vulnerabilities::UpdateAscpAssociationsWorker).to receive(:perform_async).with(project.id)

          expect(result).to be_success
        end
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(ascp_component_vulnerability_association: false)
        end

        it 'does not enqueue the association worker' do
          expect(Vulnerabilities::UpdateAscpAssociationsWorker).not_to receive(:perform_async)

          expect(result).to be_success
        end
      end

      context 'when the scan fails to save' do
        let(:params) { { scan_type: 'full' } } # missing commit_sha

        it 'does not enqueue the association worker' do
          expect(Vulnerabilities::UpdateAscpAssociationsWorker).not_to receive(:perform_async)

          expect(result).to be_error
        end
      end
    end

    describe 'exclusive locking' do
      let(:service) { described_class.new(current_user: user, project: project, params: params) }

      context 'when the lock is not being held' do
        it 'runs the critical section of the code in lock' do
          expect_to_obtain_exclusive_lease("ascp:scan_sequence:#{project.id}")

          service.execute
        end
      end

      context 'when the lock is already being held' do
        before do
          stub_const("#{described_class}::LOCK_RETRIES", 0)
          stub_exclusive_lease_taken("ascp:scan_sequence:#{project.id}")
        end

        it 'does not create a record' do
          expect { service.execute }.not_to change { Security::Ascp::Scan.count }
        end

        it 'returns an error response' do
          result = service.execute

          expect(result).to be_error
          expect(result.message).to include('Failed to obtain lock for scan creation')
        end
      end
    end
  end
end
