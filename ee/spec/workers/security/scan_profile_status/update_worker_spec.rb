# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfileStatus::UpdateWorker, feature_category: :security_testing_configuration do
  let_it_be(:project) { create(:project, :small_repo) }

  let(:pipeline) { create(:ci_pipeline, project: project, ref: project.default_branch) }
  let(:worker) { described_class.new }

  describe '#perform' do
    subject(:perform) { worker.perform(pipeline.id) }

    context 'when pipeline exists and is on default branch' do
      it 'calls the update service' do
        expect_next_instance_of(Security::ScanProfileStatus::UpdateService, pipeline) do |service|
          expect(service).to receive(:execute)
        end

        perform
      end
    end

    context 'when pipeline does not exist' do
      it 'does nothing' do
        expect(Security::ScanProfileStatus::UpdateService).not_to receive(:new)

        worker.perform(non_existing_record_id)
      end
    end

    context 'when pipeline is not on the default branch' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }

      it 'does nothing' do
        expect(Security::ScanProfileStatus::UpdateService).not_to receive(:new)

        perform
      end
    end

    context 'when the lock cannot be obtained' do
      it 're-enqueues the job' do
        expect(worker).to receive(:in_lock)
          .with("security:scan_profile_status_update_worker:#{project.id}",
            ttl: described_class::LEASE_TTL,
            retries: described_class::LEASE_RETRIES,
            sleep_sec: described_class::LEASE_TRY_AFTER)
          .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

        expect(described_class).to receive(:perform_in)
          .with(described_class::RETRY_IN_IF_LOCKED, pipeline.id)

        perform
      end
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [pipeline.id] }

    before do
      stub_licensed_features(security_scan_profiles: true)
    end
  end
end
