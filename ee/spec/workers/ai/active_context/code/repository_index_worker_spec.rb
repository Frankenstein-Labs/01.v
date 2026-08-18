# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::RepositoryIndexWorker, :with_active_context_adapter_reset, feature_category: :global_search do
  let(:worker) { described_class.new }

  it_behaves_like 'active_context pause-controlled worker' do
    let(:worker_params) { [123] }
  end

  describe '#perform' do
    let_it_be_with_reload(:repository) { create(:ai_active_context_code_repository, state: :pending) }

    before do
      allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      allow(Ai::ActiveContext::Code::InitialIndexingService).to receive(:execute)
      allow(Ai::ActiveContext::Code::IncrementalIndexingService).to receive(:execute)
    end

    context 'when ActiveContext indexing is enabled' do
      context 'with a valid pending repository' do
        before do
          repository.pending!
        end

        it 'calls InitialIndexingService.execute with the repository' do
          worker.perform(repository.id)

          expect(Ai::ActiveContext::Code::InitialIndexingService).to have_received(:execute).with(repository)
          expect(Ai::ActiveContext::Code::IncrementalIndexingService).not_to have_received(:execute).with(repository)
        end
      end

      context 'with a valid ready repository' do
        before do
          repository.ready!
        end

        it 'calls IncrementalIndexingService.execute' do
          worker.perform(repository.id)

          expect(Ai::ActiveContext::Code::InitialIndexingService).not_to have_received(:execute)
          expect(Ai::ActiveContext::Code::IncrementalIndexingService).to have_received(:execute).with(repository)
        end
      end

      context 'with a valid repository that is not pending or ready' do
        before do
          repository.failed!
        end

        it 'does not call any indexing service' do
          expect(Ai::ActiveContext::Code::InitialIndexingService).not_to receive(:execute)
          expect(Ai::ActiveContext::Code::IncrementalIndexingService).not_to receive(:execute)

          worker.perform(repository.id)
        end
      end

      context 'with a non-existent repository' do
        it 'does not call IndexingService.execute' do
          worker.perform(999999)

          expect(Ai::ActiveContext::Code::InitialIndexingService).not_to have_received(:execute)
        end
      end
    end

    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
        repository.pending!
      end

      it 'does not call InitialIndexingService.execute' do
        worker.perform(repository.id)

        expect(Ai::ActiveContext::Code::InitialIndexingService).not_to have_received(:execute)
      end
    end

    describe 'parallel execution' do
      include ExclusiveLeaseHelpers

      let(:lease_key) { "Ai::ActiveContext::Code::RepositoryIndexWorker/#{repository.id}" }

      before do
        repository.pending!
        stub_exclusive_lease_taken(lease_key, timeout: described_class::LEASE_TTL)
      end

      context 'when the lock is locked' do
        it 'does not run service' do
          expect(worker).to receive(:in_lock)
            .with(lease_key,
              ttl: described_class::LEASE_TTL,
              retries: described_class::LEASE_RETRIES,
              sleep_sec: described_class::LEASE_TRY_AFTER)

          expect(Ai::ActiveContext::Code::InitialIndexingService).not_to receive(:execute)

          worker.perform(repository.id)
        end

        it 'schedules a new job' do
          expect(worker).to receive(:in_lock)
            .with(lease_key,
              ttl: described_class::LEASE_TTL,
              retries: described_class::LEASE_RETRIES,
              sleep_sec: described_class::LEASE_TRY_AFTER)
            .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

          expect(described_class).to receive(:perform_in)
            .with(described_class::RETRY_IN_IF_LOCKED, repository.id)

          worker.perform(repository.id)
        end
      end
    end
  end
end
