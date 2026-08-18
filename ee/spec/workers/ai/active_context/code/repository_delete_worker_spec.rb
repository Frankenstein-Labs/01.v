# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::RepositoryDeleteWorker, :with_active_context_adapter_reset, feature_category: :global_search do
  let(:worker) { described_class.new }

  it_behaves_like 'active_context pause-controlled worker' do
    let(:worker_params) { [123] }
  end

  describe '#perform' do
    let_it_be_with_reload(:repository) { create(:ai_active_context_code_repository, state: :pending_deletion) }

    before do
      allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      allow(Ai::ActiveContext::Code::Deleter).to receive(:run!)
    end

    context 'when ActiveContext indexing is enabled' do
      context 'with a valid pending_deletion repository' do
        before do
          repository.pending_deletion!
        end

        it 'calls Deleter.run! with the repository and marks it as deleted' do
          worker.perform(repository.id)

          expect(Ai::ActiveContext::Code::Deleter).to have_received(:run!).with(repository)
          expect(repository.reload.state).to eq('deleted')
        end
      end

      context 'when the project has been deleted' do
        before do
          repository.pending_deletion!
          repository.project.destroy!
        end

        it 'still marks the repository as deleted' do
          worker.perform(repository.id)

          expect(Ai::ActiveContext::Code::Deleter).to have_received(:run!)
          expect(repository.reload.state).to eq('deleted')
        end
      end

      context 'with a valid repository that is not pending_deletion' do
        before do
          repository.ready!
        end

        it 'does not call Deleter.run!' do
          expect(Ai::ActiveContext::Code::Deleter).not_to receive(:run!)

          worker.perform(repository.id)
        end
      end

      context 'with a non-existent repository' do
        it 'does not call Deleter.run!' do
          worker.perform(999999)

          expect(Ai::ActiveContext::Code::Deleter).not_to have_received(:run!)
        end
      end
    end

    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
        repository.pending_deletion!
      end

      it 'does not call Deleter.run!' do
        worker.perform(repository.id)

        expect(Ai::ActiveContext::Code::Deleter).not_to have_received(:run!)
      end
    end

    describe 'parallel execution' do
      include ExclusiveLeaseHelpers

      let(:lease_key) { "Ai::ActiveContext::Code::RepositoryDeleteWorker/#{repository.id}" }

      before do
        repository.pending_deletion!
        stub_exclusive_lease_taken(lease_key, timeout: described_class::LEASE_TTL)
      end

      context 'when the lock is locked' do
        it 'does not run deletion' do
          expect(worker).to receive(:in_lock)
            .with(lease_key,
              ttl: described_class::LEASE_TTL,
              retries: described_class::LEASE_RETRIES,
              sleep_sec: described_class::LEASE_TRY_AFTER)

          expect(Ai::ActiveContext::Code::Deleter).not_to receive(:run!)

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
