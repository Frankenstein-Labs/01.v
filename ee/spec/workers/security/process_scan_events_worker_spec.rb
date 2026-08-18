# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProcessScanEventsWorker, feature_category: :vulnerability_management do
  let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :test_observability) }
  let_it_be(:pipeline) { artifact.job.pipeline }

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(pipeline.id) }

    it 'calls `::Security::ProcessScanEventsService` with unknown event raising exception' do
      expect { run_worker }.to raise_error(
        ::Security::ProcessScanEventsService::ScanEventNotInAllowListError,
        "Event not in allow list 'dummy_event_for_testing_abcdefg'")
    end

    describe 'with mocked `::Security::ProcessScanEventsService' do
      before do
        allow(Security::ProcessScanEventsService).to receive(:execute)
      end

      it 'calls `::Security::ProcessScanEventsService`' do
        run_worker

        expect(Security::ProcessScanEventsService).to have_received(:execute)
      end
    end
  end
end
