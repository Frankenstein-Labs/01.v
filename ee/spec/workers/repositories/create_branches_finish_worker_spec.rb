# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Repositories::CreateBranchesFinishWorker, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :mirror, import_status: 'started') }
  let(:import_state) { project.import_state }
  let(:waiter_key) { Gitlab::JobWaiter.generate_key }
  let(:worker) { described_class.new }
  let(:cache_key) { format(described_class::ERRORS_CACHE_KEY, waiter_key: waiter_key) }
  let(:waiter) { instance_double(Gitlab::JobWaiter, jobs_remaining: 3, wait: nil, key: waiter_key) }

  describe '.sidekiq_options' do
    subject(:sidekiq_options) { worker.class.sidekiq_options }

    it 'has a status_expiration' do
      is_expected.to match(a_hash_including(
        'status_expiration' => Gitlab::Import::StuckImportJob::IMPORT_JOBS_EXPIRATION,
        'retry' => 6,
        'dead' => false
      ))
    end
  end

  describe '.add_error' do
    let(:branch_name) { 'branch' }
    let(:message) { 'message' }

    subject(:add_error) { described_class.add_error(waiter_key, branch_name, message) }

    it 'caches the error to redis' do
      expect(Gitlab::Cache::Import::Caching).to receive(:hash_add)
        .with(cache_key, branch_name, message)

      add_error
    end
  end

  describe '#perform' do
    context 'when project does not exist' do
      let(:job_args) { [] }

      it 'cleans up the waiter key' do
        expect(Gitlab::JobWaiter).to receive(:delete_key).with(waiter_key)
        expect(Gitlab::Cache::Import::Caching).to receive(:expire)
            .with(cache_key, Gitlab::Cache::Import::Caching::SHORTER_TIMEOUT)

        worker.perform(non_existing_record_id, waiter_key, 5)
      end
    end

    context 'when all jobs have completed' do
      subject(:perform) { worker.perform(project.id, waiter_key, 0) }

      it 'cleans up the waiter key' do
        expect(Gitlab::JobWaiter).to receive(:delete_key).with(waiter_key)

        perform
      end

      context 'with no failures' do
        it 'does not update import_state.last_error' do
          perform

          expect(import_state.reload.last_error).to be_nil
          expect(import_state.reload.status).to eq('finished')
        end

        it 'logs the mirror update finished with async_branch_creation: true' do
          allow(Gitlab::AppLogger).to receive(:info).and_call_original
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(message: /successfully finished/, async_branch_creation: true)
          )

          perform
        end

        it 'observes the mirror update duration metric' do
          histogram = instance_double(Prometheus::Client::Histogram)
          allow(Gitlab::Metrics).to receive(:histogram)
            .with(:gitlab_repository_mirror_update_duration_seconds, 'Mirror update duration', {}, anything)
            .and_return(histogram)
          expect(histogram).to receive(:observe).with({}, a_value >= 0)

          perform
        end
      end

      context 'with failures' do
        let(:error_message) { 'error' }
        let(:another_error_message) { 'other error' }

        before do
          Gitlab::Cache::Import::Caching.hash_add(cache_key, 'branch-a', error_message)
          Gitlab::Cache::Import::Caching.hash_add(cache_key, 'branch-b', another_error_message)
        end

        it 'writes failure summary to import_state.last_error' do
          perform

          expect(import_state.reload.last_error).to include(
            "#{error_message}\n\n#{another_error_message}"
          )
        end

        it 'expires the errors cache key' do
          expect(Gitlab::Cache::Import::Caching).to receive(:expire)
            .with(cache_key, Gitlab::Cache::Import::Caching::SHORTER_TIMEOUT)

          perform
        end
      end
    end

    context 'when branches exceeded the maximum limit' do
      let(:excess_branches_count) { 50 }

      subject(:perform) { worker.perform(project.id, waiter_key, 0, excess_branches_count) }

      context 'with no job failures' do
        it 'marks import as failed with excess branches message' do
          perform

          expect(import_state.reload.last_error).to include(
            "50 branches exceeded the limit"
          )
        end
      end

      context 'with job failures' do
        before do
          Gitlab::Cache::Import::Caching.hash_add(cache_key, 'branch-a', 'error creating branch')
        end

        it 'includes both job errors and excess branches message' do
          perform

          last_error = import_state.reload.last_error
          expect(last_error).to include('error creating branch')
          expect(last_error).to include('50 branches exceeded the limit')
        end
      end
    end

    context 'when jobs are still remaining' do
      before do
        allow(Gitlab::JobWaiter).to receive(:new).and_return(waiter)
      end

      it 'reschedules itself' do
        freeze_time do
          expect(described_class).to receive(:perform_in).with(
            described_class::POLL_INTERVAL,
            project.id, waiter_key, 3, 0, Time.current.to_i
          )

          worker.perform(project.id, waiter_key, 5)
        end
      end
    end

    context 'when timeout is reached' do
      let(:timeout_timer) { (described_class::TIMEOUT_DURATION + 1.second).ago.to_i }

      subject(:perform) { worker.perform(project.id, waiter_key, 3, 0, timeout_timer) }

      before do
        allow(Gitlab::JobWaiter).to receive(:new).and_return(waiter)
      end

      it 'cleans up the waiter key' do
        expect(Gitlab::JobWaiter).to receive(:delete_key).with(waiter_key)

        perform
      end

      it 'writes timeout message to import_state.last_error' do
        perform

        expect(import_state.reload.last_error).to eq(
          'Branch creation timed out'
        )
      end

      context 'and there were errors during branch creation' do
        let(:error_message) { 'a message' }

        before do
          Gitlab::Cache::Import::Caching.hash_add(cache_key, 'branch-b', error_message)
        end

        it 'writes failure summary to import_state.last_error' do
          perform

          expect(import_state.reload.last_error).to include(
              "#{error_message}\n\nBranch creation timed out"
            )
        end
      end

      it 'expires the errors cache key' do
        expect(Gitlab::Cache::Import::Caching).to receive(:expire)
          .with(cache_key, Gitlab::Cache::Import::Caching::SHORTER_TIMEOUT)

        perform
      end
    end
  end
end
