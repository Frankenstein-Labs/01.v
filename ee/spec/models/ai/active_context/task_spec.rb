# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Task, feature_category: :global_search do
  let_it_be(:connection) { create(:ai_active_context_connection) }

  describe 'associations' do
    it { is_expected.to belong_to(:connection).class_name('Ai::ActiveContext::Connection') }
    it { is_expected.to belong_to(:depends_on).class_name('Ai::ActiveContext::Task').optional }
  end

  describe 'validations' do
    describe 'name' do
      it { is_expected.to validate_presence_of(:name) }
      it { is_expected.to validate_length_of(:name).is_at_most(255) }
    end

    describe 'status' do
      it { is_expected.to validate_presence_of(:status) }
    end

    describe 'retries_left' do
      let(:task) { build(:ai_active_context_task, connection: connection) }

      it { is_expected.to validate_numericality_of(:retries_left).is_greater_than_or_equal_to(0) }

      context 'when retries_left is 0' do
        before do
          task.retries_left = 0
        end

        it 'is valid when status is failed' do
          task.status = 'failed'
          expect(task).to be_valid
        end

        it 'is invalid when status is not failed' do
          task.status = 'pending'
          expect(task).not_to be_valid
          expect(task.errors[:retries_left]).to include('can only be 0 when status is failed')
        end
      end
    end

    describe 'params' do
      it { is_expected.to allow_value({}).for(:params) }
      it { is_expected.to allow_value({ field: 'test', dimensions: 512 }).for(:params) }

      describe 'batch_size validation' do
        it { is_expected.to allow_value({ batch_size: 100 }).for(:params) }
        it { is_expected.to allow_value({ batch_size: 1 }).for(:params) }
        it { is_expected.not_to allow_value({ batch_size: 0 }).for(:params) }
        it { is_expected.not_to allow_value({ batch_size: -1 }).for(:params) }
        it { is_expected.not_to allow_value({ batch_size: 'invalid' }).for(:params) }
      end
    end
  end

  describe 'scopes' do
    describe '.processable' do
      let_it_be(:pending_no_deps) { create(:ai_active_context_task, connection: connection, status: :pending) }
      let_it_be(:completed_task) { create(:ai_active_context_task, connection: connection, status: :completed) }
      let_it_be(:pending_with_completed_dep) do
        create(:ai_active_context_task, connection: connection, status: :pending, depends_on: completed_task)
      end

      let_it_be(:pending_with_pending_dep) do
        create(:ai_active_context_task, connection: connection, status: :pending, depends_on: pending_no_deps)
      end

      let_it_be(:in_progress_task) { create(:ai_active_context_task, connection: connection, status: :in_progress) }
      let_it_be(:failed_task) { create(:ai_active_context_task, connection: connection, status: :failed) }

      it 'returns pending/in_progress tasks with no dependencies or completed dependencies' do
        processable = described_class.processable

        expect(processable).to include(pending_no_deps, pending_with_completed_dep, in_progress_task)
        expect(processable).not_to include(completed_task, pending_with_pending_dep, failed_task)
      end

      it 'orders by created_at' do
        expect(described_class.processable.to_a).to eq([pending_no_deps, pending_with_completed_dep, in_progress_task])
      end
    end

    describe '.with_active_connection' do
      let_it_be(:inactive_connection) { create(:ai_active_context_connection, active: false) }
      let_it_be(:task_active) { create(:ai_active_context_task, connection: connection) }
      let_it_be(:task_inactive) { create(:ai_active_context_task, connection: inactive_connection) }

      it 'returns only tasks with active connections' do
        expect(described_class.with_active_connection).to include(task_active)
        expect(described_class.with_active_connection).not_to include(task_inactive)
      end
    end

    describe '.pending_or_in_progress' do
      let!(:task_pending) { create(:ai_active_context_task, connection: connection) }
      let!(:task_in_progress) { create(:ai_active_context_task, :in_progress, connection: connection) }
      let!(:task_failed) { create(:ai_active_context_task, :failed, connection: connection) }
      let!(:task_completed) { create(:ai_active_context_task, :completed, connection: connection) }

      it 'returns only the pending and in-progress tasks' do
        tasks = described_class.pending_or_in_progress
        expect(tasks.map(&:status)).to match_array(%w[pending in_progress])
      end
    end

    describe '.by_name' do
      let!(:task1) { create(:ai_active_context_task, name: "Task 1", connection: connection) }
      let!(:task2) { create(:ai_active_context_task, name: "Task 2", connection: connection) }

      it 'returns only the tasks matching the specified name' do
        expect(described_class.by_name("Task 1")).to eq([task1])
      end
    end
  end

  describe '.current' do
    let_it_be(:inactive_connection) { create(:ai_active_context_connection, active: false) }

    context 'when there are processable tasks' do
      let_it_be(:older_task) { create(:ai_active_context_task, connection: connection, status: :pending) }
      let_it_be(:newer_task) { create(:ai_active_context_task, connection: connection, status: :pending) }

      it 'returns the oldest processable task' do
        expect(described_class.current).to eq(older_task)
      end
    end

    context 'when processable task has inactive connection' do
      let_it_be(:task) { create(:ai_active_context_task, connection: inactive_connection, status: :pending) }

      it 'returns nil' do
        expect(described_class.current).to be_nil
      end
    end

    context 'when there are no processable tasks' do
      let_it_be(:completed_task) { create(:ai_active_context_task, connection: connection, status: :completed) }
      let_it_be(:failed_task) { create(:ai_active_context_task, connection: connection, status: :failed) }

      it 'returns nil' do
        expect(described_class.current).to be_nil
      end
    end
  end

  describe '#mark_as_started!' do
    let(:task) { create(:ai_active_context_task, connection: connection, status: :pending) }

    it 'updates status to in_progress and sets started_at' do
      freeze_time do
        expect { task.mark_as_started! }
          .to change { task.status }.from('pending').to('in_progress')
          .and change { task.started_at }.from(nil).to(Time.zone.now)
      end
    end
  end

  describe '#mark_as_completed!' do
    let(:task) { create(:ai_active_context_task, connection: connection, status: :in_progress) }

    it 'updates status to completed and sets completed_at' do
      freeze_time do
        expect { task.mark_as_completed! }
          .to change { task.status }.from('in_progress').to('completed')
          .and change { task.completed_at }.from(nil).to(Time.zone.now)
      end
    end
  end

  describe '#mark_as_failed!' do
    let(:error) { StandardError.new('Something went wrong') }
    let(:task) { create(:ai_active_context_task, connection: connection) }

    it 'updates the status to failed and sets error_message' do
      expect { task.mark_as_failed!(error) }
        .to change { task.status }.from('pending').to('failed')
        .and change { task.error_message }.from(nil).to('StandardError: Something went wrong')
    end

    it 'truncates long error messages' do
      long_error = StandardError.new('x' * 2000)
      task.mark_as_failed!(long_error)

      expect(task.error_message.length).to be <= 1024
    end

    context 'with dependent tasks' do
      let!(:dependent_task) { create(:ai_active_context_task, connection: connection, depends_on: task) }
      let!(:nested_dependent) { create(:ai_active_context_task, connection: connection, depends_on: dependent_task) }

      it 'recursively fails all dependent tasks' do
        task.mark_as_failed!(error)

        expect(task.reload.status).to eq('failed')
        expect(dependent_task.reload.status).to eq('failed')
        expect(dependent_task.error_message).to eq("Dependency '#{task.name}' failed")
        expect(nested_dependent.reload.status).to eq('failed')
        expect(nested_dependent.error_message).to eq("Dependency '#{dependent_task.name}' failed")
      end

      it 'recursively fails tree with multiple branches' do
        # Task 1 (fails) -> Task 2 and Task 5
        # |-- Task 2     -> Task 3 and Task 4
        # |-- Task 5     -> Task 6
        task2 = create(:ai_active_context_task, connection: connection, depends_on: task, name: 'Task 2')
        task3 = create(:ai_active_context_task, connection: connection, depends_on: task2, name: 'Task 3')
        task4 = create(:ai_active_context_task, connection: connection, depends_on: task2, name: 'Task 4')
        task5 = create(:ai_active_context_task, connection: connection, depends_on: task, name: 'Task 5')
        task6 = create(:ai_active_context_task, connection: connection, depends_on: task5, name: 'Task 6')

        task.mark_as_failed!(error)

        expect(task.reload.status).to eq('failed')
        expect(task2.reload.status).to eq('failed')
        expect(task3.reload.status).to eq('failed')
        expect(task4.reload.status).to eq('failed')
        expect(task5.reload.status).to eq('failed')
        expect(task6.reload.status).to eq('failed')
      end

      it 'does not fail already completed dependents' do
        dependent_task.update!(status: :completed)

        task.mark_as_failed!(error)

        expect(dependent_task.reload.status).to eq('completed')
        expect(nested_dependent.reload.status).to eq('pending')
      end

      it 'sets retries_left to 0 for all dependent tasks' do
        task.mark_as_failed!(error)

        expect(dependent_task.reload.retries_left).to eq(0)
        expect(nested_dependent.reload.retries_left).to eq(0)
      end

      it 'fails all dependents atomically within a transaction' do
        # Verify that recursively_fail_dependents! is wrapped in a transaction
        expect(task.class).to receive(:transaction).and_call_original

        task.mark_as_failed!(error)
      end
    end
  end

  describe '#decrease_retries!' do
    let(:error) { StandardError.new('something went wrong') }

    context 'when retries are available' do
      let(:task) { create(:ai_active_context_task, connection: connection, retries_left: 3) }

      it 'decreases retries_left by 1' do
        expect { task.decrease_retries!(error) }.to change { task.retries_left }.from(3).to(2)
      end
    end

    context 'when no retries are left' do
      let(:task) { create(:ai_active_context_task, connection: connection, retries_left: 1) }

      it 'marks the task as failed' do
        task.decrease_retries!(error)

        expect(task.status).to eq('failed')
        expect(task.retries_left).to eq(0)
        expect(task.error_message).to include(error.message)
      end
    end
  end
end
