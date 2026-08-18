# frozen_string_literal: true

# Drives the shared retry/cron behaviour for project + group SecretsManager
# maintenance tasks. The cron worker dispatches by `task.action`, so both
# action types are exercised here.
#
# Including specs must provide:
# - `task_factory`             -- factory name, e.g. :project_secrets_manager_maintenance_task
# - `provision_worker_class`   -- the worker class the cron re-enqueues for provision tasks
# - `deprovision_worker_class` -- the worker class the cron re-enqueues for deprovision tasks
# - `extra_attrs`              -- hash of additional factory attrs needed for a valid record
RSpec.shared_examples 'a secrets manager maintenance tasks cron worker' do
  let(:worker) { described_class.new }
  let(:provision_worker_spy) { class_spy(provision_worker_class) }
  let(:deprovision_worker_spy) { class_spy(deprovision_worker_class) }

  before do
    stub_const(provision_worker_class.name, provision_worker_spy)
    stub_const(deprovision_worker_class.name, deprovision_worker_spy)
  end

  describe '#perform' do
    subject(:run_worker) { worker.perform }

    context 'when there is a stale provision task' do
      let!(:stale_task) { create(task_factory, :stale, :provision, **extra_attrs) }

      it 'increments retry_count and re-enqueues the provision worker with the task id' do
        expect { run_worker }.to change { stale_task.reload.retry_count }.by(1)

        expect(provision_worker_spy).to have_received(:perform_async).with(stale_task.id)
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end

      it 'updates last_processed_at to the current time' do
        freeze_time do
          run_worker

          expect(stale_task.reload.last_processed_at).to be_within(1.second).of(Time.current)
        end
      end

      it 'logs a warning identifying the task' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          hash_including(
            message: 'Retrying failed secrets_manager maintenance task',
            task_id: stale_task.id,
            retry_count: 0
          )
        )

        run_worker
      end
    end

    context 'when there is a stale deprovision task' do
      let!(:stale_task) { create(task_factory, :stale, :deprovision, **extra_attrs) }

      it 'increments retry_count and re-enqueues the deprovision worker with the task id' do
        expect { run_worker }.to change { stale_task.reload.retry_count }.by(1)

        expect(deprovision_worker_spy).to have_received(:perform_async).with(stale_task.id)
        expect(provision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when a stale task has an unrecognized action' do
      # Defensive: the action enum only allows :provision / :deprovision,
      # but the cron's per-task isolation must surface unknown values
      # explicitly rather than silently no-op.
      let!(:stale_task) { create(task_factory, :stale, **extra_attrs) }

      before do
        allow_next_found_instance_of(stale_task.class) do |task|
          allow(task).to receive(:action).and_return('something_else')
        end
      end

      it 'tracks an ArgumentError and does not enqueue either worker' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(ArgumentError),
          hash_including(worker: described_class.name, task_id: stale_task.id)
        )

        run_worker

        expect(provision_worker_spy).not_to have_received(:perform_async)
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when there are no stale tasks' do
      it 'does not enqueue any workers' do
        run_worker

        expect(provision_worker_spy).not_to have_received(:perform_async)
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when task has reached max retries' do
      let!(:max_retried_task) do
        create(task_factory, :stale,
          retry_count: SecretsManagement::BaseMaintenanceTasksCronWorker::MAX_RETRIES,
          **extra_attrs
        )
      end

      it 'does not process the task' do
        expect { run_worker }.not_to change { max_retried_task.reload.retry_count }
        expect(provision_worker_spy).not_to have_received(:perform_async)
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when task is processing but not stale yet' do
      let!(:processing_task) { create(task_factory, :processing, **extra_attrs) }

      it 'does not process the task' do
        run_worker

        expect(provision_worker_spy).not_to have_received(:perform_async)
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when database is read-only' do
      let!(:stale_task) { create(task_factory, :stale, **extra_attrs) }

      before do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
      end

      it 'does not process tasks or enqueue workers' do
        expect { run_worker }.not_to change { stale_task.reload.retry_count }
        expect(provision_worker_spy).not_to have_received(:perform_async)
        expect(deprovision_worker_spy).not_to have_received(:perform_async)
      end
    end

    context 'when one task in the batch raises an error' do
      # Per-task isolation: a transient failure on one row (e.g. a Redis
      # blip on perform_async) should not abort the rest of the batch.
      # Both tasks must reference different parents because of the
      # uniqueness constraints on the maintenance task tables (project_id
      # / group_id unique, and (sm_id, action) unique). The factory
      # creates fresh parent + SM records when the association is
      # unspecified, so we deliberately skip `extra_attrs` here.
      let!(:bad_task)  { create(task_factory, :stale) }
      let!(:good_task) { create(task_factory, :stale) }

      before do
        # Tasks default to action :provision in the factories, so the cron
        # dispatches them to the provision worker.
        allow(provision_worker_spy).to receive(:perform_async) do |task_id|
          raise StandardError, 'redis down' if task_id == bad_task.id

          # Class spy default: no-op for any other id.
        end
      end

      it 'tracks the exception and continues processing the rest of the batch' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          hash_including(worker: described_class.name, task_id: bad_task.id)
        )

        run_worker

        expect(provision_worker_spy).to have_received(:perform_async).with(good_task.id)
      end
    end
  end
end
