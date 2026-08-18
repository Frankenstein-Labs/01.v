# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RolloutWorker, feature_category: :global_search do
  subject(:perform_worker) { described_class.new.perform }

  let(:batch_size) { Gitlab::CurrentSettings.zoekt_rollout_batch_size }

  it 'has the `until_executed` deduplicate strategy with correct options' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
    expect(described_class.get_deduplication_options).to include({ if_deduplicated: :reschedule_once })
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

  it_behaves_like 'an idempotent worker' do
    context 'when worker does not run' do
      shared_examples 'no op' do
        it 'returns false and does not call Search::Zoekt::RolloutService' do
          expect(Search::Zoekt::RolloutService).not_to receive(:execute)
          expect(perform_worker).to be(false)
        end
      end

      context 'when setting zoekt_indexing_paused? is enabled' do
        before do
          allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return(true)
          allow(Gitlab::CurrentSettings).to receive(:zoekt_indexing_paused?).and_return(true)
        end

        it_behaves_like 'no op'
      end

      context 'when setting licensed_and_indexing_enabled? is false' do
        before do
          allow(Gitlab::CurrentSettings).to receive(:zoekt_indexing_paused?).and_return(false)
          allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return(false)
        end

        it_behaves_like 'no op'
      end
    end

    context 'when worker runs' do
      let(:reenqueue) { false }
      let(:changes) do
        {}
      end

      let(:result) { Search::Zoekt::RolloutService::Result.new('Message', changes, reenqueue) }

      before do
        allow(Gitlab::CurrentSettings).to receive(:zoekt_indexing_paused?).and_return(false)
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return(true)
      end

      it 'calls Search::Zoekt::RolloutService' do
        expect(Search::Zoekt::RolloutService).to receive(:execute).with(dry_run: false, batch_size: batch_size)
          .and_return(result)
        perform_worker
      end

      context 'when result has re_enqueue true' do
        let(:reenqueue) { true }
        let(:changes) do
          { success: [{ namespace_id: 1, replica_id: 1 }] }
        end

        it 'calls the worker again' do
          expect(Search::Zoekt::RolloutService).to receive(:execute).with(dry_run: false, batch_size: batch_size)
            .and_return(result)
          expect(described_class).to receive(:perform_async)
          perform_worker
        end
      end

      context 'when retry_count is less than MAX_RETRIES' do
        it 'calls the worker again with a delay' do
          expect(Search::Zoekt::RolloutService).to receive(:execute).with(dry_run: false, batch_size: batch_size)
            .and_return(result)
          expect(described_class).to receive(:perform_in)
          perform_worker
        end
      end

      context 'when retry_count is not less than MAX_RETRIES' do
        it 'does not calls the worker again' do
          expect(Search::Zoekt::RolloutService).to receive(:execute).with(dry_run: false, batch_size: batch_size)
            .and_return(result)
          expect(described_class).not_to receive(:perform_at)
          expect(described_class).not_to receive(:perform_in)
          expect(described_class).not_to receive(:perform_async)
          described_class.new.perform(5)
        end
      end
    end
  end
end
