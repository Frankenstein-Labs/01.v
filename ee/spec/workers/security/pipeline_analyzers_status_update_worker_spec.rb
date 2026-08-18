# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineAnalyzersStatusUpdateWorker, feature_category: :security_asset_inventories do
  let_it_be(:sast_scan) { create(:security_scan, scan_type: :sast) }
  let_it_be(:pipeline) { sast_scan.pipeline }

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(pipeline.id) }

    let(:analyzer_status_service) { instance_double(Security::AnalyzersStatus::UpdateService) }

    before do
      allow(Security::AnalyzersStatus::UpdateService).to receive(:new).with(pipeline)
        .and_return(analyzer_status_service)
      allow(analyzer_status_service).to receive(:execute)
    end

    describe 'when no such pipeline exists' do
      it 'does not call `Security::AnalyzerStatusUpdateService`' do
        described_class.new.perform(-1)

        expect(Security::AnalyzersStatus::UpdateService).not_to have_received(:new)
      end
    end

    describe 'when security_dashboard feature is not available' do
      it 'does not call `Security::AnalyzerStatusUpdateService`' do
        run_worker

        expect(Security::AnalyzersStatus::UpdateService).not_to have_received(:new)
      end
    end

    describe 'when security_dashboard feature is available' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      it 'calls `Security::AnalyzerStatusUpdateService`' do
        run_worker

        expect(Security::AnalyzersStatus::UpdateService).to have_received(:new).with(pipeline)
        expect(analyzer_status_service).to have_received(:execute)
      end

      describe 'parallel execution' do
        include ExclusiveLeaseHelpers

        let(:worker) { described_class.new }
        let(:root_namespace_id) { pipeline.project.root_namespace.id }
        let(:lease_key) { "security:pipeline_analyzers_status_update_worker:#{root_namespace_id}" }
        let(:lease_ttl) { 5.minutes }

        before do
          stub_const("#{described_class}::LEASE_TRY_AFTER", 0.001)
          stub_exclusive_lease_taken(lease_key, timeout: lease_ttl)
        end

        context 'when the lock is locked' do
          it 'does not run the service logic' do
            expect(worker).to receive(:in_lock)
              .with(lease_key,
                ttl: described_class::LEASE_TTL,
                retries: described_class::LEASE_RETRIES,
                sleep_sec: described_class::LEASE_TRY_AFTER)

            expect(Security::AnalyzersStatus::UpdateService).not_to receive(:new)
            expect(analyzer_status_service).not_to receive(:execute)

            worker.perform(pipeline.id)
          end

          it 'schedules a new job when lock fails' do
            expect(worker).to receive(:in_lock)
              .with(lease_key,
                ttl: described_class::LEASE_TTL,
                retries: described_class::LEASE_RETRIES,
                sleep_sec: described_class::LEASE_TRY_AFTER)
              .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

            expect(described_class).to receive(:perform_in)
              .with(described_class::RETRY_IN_IF_LOCKED, pipeline.id)

            worker.perform(pipeline.id)
          end
        end
      end
    end
  end
end
