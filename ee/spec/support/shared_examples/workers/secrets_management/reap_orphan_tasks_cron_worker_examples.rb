# frozen_string_literal: true

# Drives the shared parts of the reap-orphan-tasks cron worker specs.
#
# Including specs must provide:
#   - `worker`                       (instance of the described worker)
#   - `deprovision_service_class`    (ProjectSecretsManagers::DeprovisionService / Group...)
#   - `build_parent`                 helper that creates a fresh parent (project / group)
#   - `build_task(parent:, action:, retry_count:, last_processed_at:)` helper
#     that creates a maintenance task on the given parent. The unique index
#     on `parent_id` forces one task per parent per spec.
RSpec.shared_examples 'a secrets manager reap orphan tasks cron worker' do
  describe '#perform' do
    let(:grace_period) { SecretsManagement::BaseReapOrphanTasksCronWorker::GRACE_PERIOD }
    let(:max_retries) { SecretsManagement::BaseMaintenanceTasksCronWorker::MAX_RETRIES }
    let(:past_grace) { (grace_period + 1.minute).ago }
    let(:inside_grace) { 1.minute.ago }
    # Trigger-created rows that the retry cron hasn't touched yet have NULL
    # `last_processed_at`. The reaper deliberately ignores those.
    let(:never_processed) { nil }

    let(:executed_tasks) { [] }

    before do
      allow_next_instance_of(deprovision_service_class) do |service|
        allow(service).to receive(:execute) do
          executed_tasks << service.maintenance_task.id
          ServiceResponse.success
        end
      end
    end

    context 'with a provision task at MAX_RETRIES past the grace period' do
      let!(:parent) { build_parent }
      let!(:task) do
        build_task(parent: parent, action: :provision, retry_count: max_retries,
          last_processed_at: past_grace)
      end

      it 'terminates it through the deprovision service regardless of parent state' do
        worker.perform

        expect(executed_tasks).to include(task.id)
      end
    end

    context 'with a deprovision task at MAX_RETRIES past the grace period' do
      let!(:parent) { build_parent }
      let!(:task) do
        build_task(parent: parent, action: :deprovision, retry_count: max_retries,
          last_processed_at: past_grace)
      end

      it 'terminates it through the deprovision service' do
        worker.perform

        expect(executed_tasks).to include(task.id)
      end
    end

    context 'with a task at MAX_RETRIES inside the grace period' do
      let!(:parent) { build_parent }
      let!(:task) do
        build_task(parent: parent, action: :deprovision, retry_count: max_retries,
          last_processed_at: inside_grace)
      end

      it 'leaves it alone (retry cron may still be acting on it)' do
        worker.perform

        expect(executed_tasks).not_to include(task.id)
      end
    end

    context 'with a task still inside the retry budget' do
      let!(:parent) { build_parent }
      let!(:task) do
        build_task(parent: parent, action: :deprovision, retry_count: max_retries - 1,
          last_processed_at: past_grace)
      end

      it 'leaves it alone' do
        worker.perform

        expect(executed_tasks).not_to include(task.id)
      end
    end

    context 'with a trigger-created task (NULL last_processed_at)' do
      let!(:parent) { build_parent }
      let!(:task) do
        build_task(parent: parent, action: :deprovision, retry_count: 0,
          last_processed_at: never_processed)
      end

      it 'leaves it alone (retry cron owns NULL last_processed_at rows)' do
        worker.perform

        expect(executed_tasks).not_to include(task.id)
      end
    end

    it 'logs a warning per reaped task with row identifiers' do
      parent = build_parent
      task = build_task(parent: parent, action: :deprovision, retry_count: max_retries,
        last_processed_at: past_grace)

      expect(Gitlab::AppLogger).to receive(:warn).with(
        a_hash_including(
          message: 'Reaping stuck secrets manager maintenance task',
          task_id: task.id,
          task_class: task.class.name,
          action: 'deprovision',
          retry_count: max_retries
        )
      )

      worker.perform
    end

    it 'isolates per-task failures so a bad row does not stall the batch' do
      parent_a = build_parent
      task_a = build_task(parent: parent_a, action: :deprovision, retry_count: max_retries,
        last_processed_at: past_grace)

      parent_b = build_parent
      task_b = build_task(parent: parent_b, action: :deprovision, retry_count: max_retries,
        last_processed_at: past_grace)

      allow_next_instance_of(deprovision_service_class) do |service|
        allow(service).to receive(:execute) do
          raise StandardError, 'boom' if service.maintenance_task.id == task_a.id

          executed_tasks << service.maintenance_task.id
          ServiceResponse.success
        end
      end

      expect(Gitlab::ErrorTracking).to receive(:track_exception)
        .with(instance_of(StandardError), a_hash_including(task_id: task_a.id))

      worker.perform

      expect(executed_tasks).to include(task_b.id)
    end

    context 'when the database is in read-only mode' do
      before do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
      end

      it 'is a no-op' do
        parent = build_parent
        task = build_task(parent: parent, action: :deprovision, retry_count: max_retries,
          last_processed_at: past_grace)

        worker.perform

        expect(executed_tasks).not_to include(task.id)
      end
    end
  end
end
