# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::OrphanedRemediationsCleanupWorker, feature_category: :vulnerability_management, type: :job do
  let_it_be(:_remediation_with_finding) do
    create(:vulnerabilities_remediation, findings: create_list(:vulnerabilities_finding, 1))
  end

  let_it_be(:stats_key) do
    [
      ApplicationWorker::LOGGING_EXTRA_KEY,
      'vulnerabilities_orphaned_remediations_cleanup_worker',
      'stats'
    ].join('.')
  end

  let_it_be(:orphaned_remediations) do
    create_list(:vulnerabilities_remediation, 2, findings: [])
  end

  let(:service_double) { instance_double('Vulnerabilities::Remediations::BatchDestroyService', :execute) }
  let(:service_response) { ServiceResponse.success(payload: { rows_deleted: orphaned_remediations.count }) }

  before do
    allow(service_double).to receive(:execute).and_return(service_response)
  end

  shared_examples 'builds stats from the response' do |expected_stats|
    it 'includes the number of batches and rows deleted in the metadata' do
      expect { perform }.to change {
        worker.logging_extras[stats_key]
      }.from(nil).to(expected_stats)
    end
  end

  describe '.perform' do
    subject(:perform) { worker.perform }

    let(:worker) { described_class.new }

    it_behaves_like 'builds stats from the response', { batches: 1, rows_deleted: 2 }

    it 'sends remediations without findings to the BatchDestroyService' do
      expect(Vulnerabilities::Remediations::BatchDestroyService).to receive(:new) do |args|
        expect(args[:remediations].map(&:id)).to match_array(orphaned_remediations.map(&:id))
      end.and_return(service_double)

      perform
    end

    context 'when orphaned remediations span multiple batches' do
      let(:response) { ServiceResponse.success(payload: { rows_deleted: 1 }) }

      before do
        stub_const("#{described_class}::BATCH_SIZE", 1)
      end

      it_behaves_like 'builds stats from the response', { batches: 2, rows_deleted: 2 }

      it 'sends each batch to BatchDestroyService' do
        expect(Vulnerabilities::Remediations::BatchDestroyService).to receive(:new)
          .twice
          .and_return(service_double)

        perform
      end

      context 'when a batch raise an exception' do
        let(:expected_metadata) { { batches: 1, rows_deleted: 1 } }

        let(:service_double) { instance_double('Vulnerabilities::Remediations::BatchDestroyService', :execute) }
        let(:failing_double) { instance_double('Vulnerabilities::Remediations::BatchDestroyService', :execute) }

        before do
          allow(service_double).to receive(:execute).and_return(ServiceResponse.success(payload: { rows_deleted: 1 }))
          allow(failing_double).to receive(:execute).and_raise(ActiveRecord::QueryCanceled)
        end

        it 'still logs the metadata' do
          expect(Vulnerabilities::Remediations::BatchDestroyService).to receive(:new).once.and_return(service_double)
          expect(Vulnerabilities::Remediations::BatchDestroyService).to receive(:new).once.and_return(failing_double)

          expect { perform }.to raise_error(ActiveRecord::QueryCanceled)
          expect(worker.logging_extras[stats_key]).to eq expected_metadata
        end
      end
    end
  end
end
