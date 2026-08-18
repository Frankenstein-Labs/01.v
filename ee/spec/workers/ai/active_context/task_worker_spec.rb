# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::TaskWorker, feature_category: :global_search do
  let_it_be(:connection) { create(:ai_active_context_connection, active: true) }
  let(:worker) { described_class.new }
  let(:logger) { instance_double(::Logger, info: nil) }
  let_it_be(:task_double_name) { 'Ai::ActiveContext::TaskDouble' }
  let_it_be(:task_double_class) do
    Class.new do
      def initialize(_task_record = nil); end

      def execute!; end

      def completed?
        true
      end
    end
  end

  it_behaves_like 'active_context pause-controlled worker' do
    let(:worker_params) { [] }
  end

  before do
    stub_const(task_double_name, task_double_class)
    ::ActiveContext::Task::Dictionary.reset!

    allow(::ActiveContext).to receive(:indexing?).and_return(true)
    allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
  end

  describe '#perform' do
    context 'when indexing is disabled' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(false)
      end

      it 'returns without processing tasks' do
        task = create(:ai_active_context_task, connection: connection, status: :pending)

        worker.perform

        expect(task.reload.status).to eq('pending')
      end
    end

    context 'when there are no processable tasks' do
      it 'completes without error' do
        expect { worker.perform }.not_to raise_error
      end

      it 'logs that there are no pending tasks' do
        worker.perform

        expect(logger).to have_received(:info).with(hash_including('message' => /No pending tasks to process/))
      end
    end

    context 'when there is a processable task' do
      let_it_be_with_reload(:task) do
        create(:ai_active_context_task, connection: connection, status: :pending, name: task_double_name)
      end

      it 'marks task as started and completed' do
        worker.perform

        expect(task.reload.status).to eq('completed')
        expect(task.started_at).not_to be_nil
        expect(task.completed_at).not_to be_nil

        expect(logger).to have_received(:info).with(hash_including('message' => /Starting task/))
        expect(logger).to have_received(:info).with(hash_including('message' => /Marking task .* as completed/))
      end
    end

    context 'when task is already in progress' do
      let_it_be_with_reload(:task) do
        create(:ai_active_context_task, connection: connection, status: :in_progress, started_at: 1.hour.ago,
          name: task_double_name)
      end

      it 'does not call mark_as_started!' do
        original_started_at = task.started_at

        worker.perform

        # Database reload loses nanosecond precision, so use millisecond tolerance
        expect(task.reload.started_at).to be_within(0.001.seconds).of(original_started_at)
      end

      it 'still processes the task' do
        worker.perform

        expect(task.reload.status).to eq('completed')
        expect(task.reload.completed_at).not_to be_nil
      end
    end

    context 'when a task has a pending dependency' do
      let_it_be_with_reload(:parent_task) do
        create(:ai_active_context_task, connection: connection, status: :pending, name: task_double_name)
      end

      let_it_be_with_reload(:child_task) do
        create(:ai_active_context_task, connection: connection, status: :pending, depends_on: parent_task,
          name: task_double_name)
      end

      it 'only processes parent task' do
        worker.perform

        expect(parent_task.reload.status).to eq('completed')
        expect(child_task.reload.status).to eq('pending')
      end
    end

    context 'when task dependency is completed' do
      let_it_be(:parent_task) do
        create(:ai_active_context_task, connection: connection, status: :completed, name: task_double_name)
      end

      let_it_be_with_reload(:child_task) do
        create(:ai_active_context_task, connection: connection, status: :pending, depends_on: parent_task,
          name: task_double_name)
      end

      it 'processes child task' do
        worker.perform

        expect(child_task.reload.status).to eq('completed')
      end
    end

    context 'when task execution fails' do
      let_it_be_with_reload(:task) do
        create(:ai_active_context_task, connection: connection, status: :pending, retries_left: 2,
          name: task_double_name)
      end

      before do
        allow_next_instance_of(Ai::ActiveContext::TaskDouble) do |instance|
          allow(instance).to receive(:execute!).and_raise(StandardError.new('Task failed'))
        end
      end

      it 'decreases retries' do
        worker.perform

        expect(task.reload.retries_left).to eq(1)
      end

      it 'does not mark task as failed when retries are available' do
        worker.perform

        expect(task.reload.status).not_to eq('failed')
      end

      it 'logs the failure' do
        worker.perform

        expect(logger).to have_received(:info).with(hash_including('message' => /Task .* failed:/))
      end
    end

    context 'when task execution fails with no retries left' do
      let_it_be_with_reload(:task) do
        create(:ai_active_context_task, connection: connection, status: :pending, retries_left: 1,
          name: task_double_name)
      end

      before do
        allow_next_instance_of(Ai::ActiveContext::TaskDouble) do |instance|
          allow(instance).to receive(:execute!).and_raise(StandardError.new('Final failure'))
        end
      end

      it 'marks task as failed' do
        worker.perform

        expect(task.reload.status).to eq('failed')
        expect(task.reload.retries_left).to eq(0)
      end

      it 'stores error message' do
        worker.perform

        expect(task.reload.error_message).to include('Final failure')
      end
    end

    context 'when task is incomplete' do
      let_it_be_with_reload(:task) do
        create(:ai_active_context_task, connection: connection, status: :pending, name: task_double_name)
      end

      before do
        allow_next_instance_of(Ai::ActiveContext::TaskDouble) do |instance|
          allow(instance).to receive(:completed?).and_return(false)
        end
        allow(described_class).to receive(:perform_in)
      end

      it 're-enqueues the worker' do
        worker.perform

        expect(described_class).to have_received(:perform_in).with(described_class::RE_ENQUEUE_DELAY)
      end

      it 'logs incomplete task' do
        worker.perform

        expect(logger).to have_received(:info)
          .with(hash_including('message' => /Task .* incomplete, re-enqueueing worker/))
      end
    end
  end
end
