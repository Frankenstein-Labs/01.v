# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::MigrationCleanupCronWorker, feature_category: :global_search do
  let(:worker) { described_class.new }

  include_examples 'an idempotent worker'

  describe '#perform' do
    subject(:perform) { worker.perform }

    context 'when advanced search is not available', :without_license do
      it 'returns false without performing cleanup' do
        expect(Search::Elastic::MigrationCleanupService).not_to receive(:execute)

        expect(perform).to be(false)
      end
    end

    context 'when advanced search is available', :saas do
      context 'when elasticsearch indexing is not enabled' do
        before do
          stub_ee_application_setting(elasticsearch_indexing: false)
        end

        it 'returns false without performing cleanup' do
          expect(Search::Elastic::MigrationCleanupService).not_to receive(:execute)

          expect(perform).to be(false)
        end
      end

      context 'when elasticsearch indexing is enabled' do
        let(:cleanup_count) { 5 }

        before do
          stub_ee_application_setting(elasticsearch_indexing: true)
          allow(Search::Elastic::MigrationCleanupService).to receive(:execute)
            .with(dry_run: false).and_return(cleanup_count)
        end

        it 'calls the cleanup service with dry_run: false' do
          expect(Search::Elastic::MigrationCleanupService).to receive(:execute).with(dry_run: false)

          perform
        end

        it 'logs the total cleanup count as extra metadata' do
          expect(worker).to receive(:log_extra_metadata_on_done).with(:cleanup_total_count, cleanup_count)

          perform
        end

        it 'returns true after successful execution' do
          expect(perform).to be(true)
        end
      end
    end
  end
end
