# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::ReindexingTask, feature_category: :global_search do
  let(:helper) { Search::Elastic::Helper.new }

  before do
    allow(Search::Elastic::Helper).to receive(:default).and_return(helper)
  end

  describe 'relations' do
    it { is_expected.to have_many(:subtasks) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:max_slices_running) }
    it { is_expected.to validate_presence_of(:slice_multiplier) }
  end

  describe 'scopes' do
    describe '.old_indices_scheduled_for_deletion' do
      let_it_be(:success_task_with_deletion_date) do
        create(:elastic_reindexing_task, state: :success, delete_original_index_at: 1.day.ago)
      end

      let_it_be(:success_task_without_deletion_date) do
        create(:elastic_reindexing_task, state: :success, delete_original_index_at: nil)
      end

      let_it_be(:old_failure_task) do
        create(:elastic_reindexing_task, state: :failure,
          created_at: (described_class::DELETE_FAILED_INDEX_AFTER + 2.days).ago)
      end

      let_it_be(:recent_failure_task) do
        create(:elastic_reindexing_task, state: :failure, created_at: 1.day.ago)
      end

      let_it_be(:reindexing_task) do
        create(:elastic_reindexing_task, state: :reindexing, delete_original_index_at: 1.day.ago)
      end

      it 'returns success tasks with delete_original_index_at set and old failure tasks' do
        expect(described_class.old_indices_scheduled_for_deletion).to contain_exactly(
          success_task_with_deletion_date,
          old_failure_task,
          recent_failure_task
        )
      end
    end

    describe '.successful_indices_ready_for_cleanup' do
      let_it_be(:success_task_past_deletion) do
        create(:elastic_reindexing_task, state: :success, delete_original_index_at: 1.day.ago)
      end

      let_it_be(:success_task_future_deletion) do
        create(:elastic_reindexing_task, state: :success, delete_original_index_at: 1.day.from_now)
      end

      let_it_be(:success_task_deletion_cancelled) do
        create(:elastic_reindexing_task, state: :success, delete_original_index_at: nil)
      end

      it 'returns only successful tasks scheduled for deletion where deletion time has passed' do
        expect(described_class.successful_indices_ready_for_cleanup).to contain_exactly(success_task_past_deletion)
      end
    end

    describe '.failed_indices_ready_for_cleanup' do
      let_it_be(:new_failure_task) do
        create(:elastic_reindexing_task, state: :failure,
          created_at: (described_class::DELETE_FAILED_INDEX_AFTER - 2.days).ago)
      end

      let_it_be(:old_failure_task) do
        create(:elastic_reindexing_task, state: :failure,
          created_at: (described_class::DELETE_FAILED_INDEX_AFTER + 2.days).ago)
      end

      it 'returns only failed tasks scheduled for deletion which are old enough' do
        expect(described_class.failed_indices_ready_for_cleanup).to contain_exactly(old_failure_task)
      end
    end
  end

  it 'only allows one running task at a time' do
    expect { create(:elastic_reindexing_task, state: :success) }.not_to raise_error
    expect { create(:elastic_reindexing_task) }.not_to raise_error
    expect { create(:elastic_reindexing_task) }.to raise_error(/violates unique constraint/)
  end

  it 'sets in_progress flag' do
    task = create(:elastic_reindexing_task, state: :success)
    expect(task.in_progress).to be(false)

    task.update!(state: :reindexing)
    expect(task.in_progress).to be(true)
  end

  describe '.drop_old_indices!' do
    let(:task_1) do
      create(:elastic_reindexing_task, :with_subtask, state: :reindexing, delete_original_index_at: 1.day.ago)
    end

    let(:task_2) { create(:elastic_reindexing_task, :with_subtask, state: :success, delete_original_index_at: nil) }

    let(:task_3) do
      create(:elastic_reindexing_task, :with_subtask, state: :success, delete_original_index_at: 1.day.ago)
    end

    let(:task_4) do
      create(:elastic_reindexing_task, :with_subtask, state: :success, delete_original_index_at: 5.days.ago)
    end

    let(:task_5) do
      create(:elastic_reindexing_task, :with_subtask, state: :success, delete_original_index_at: 14.days.from_now)
    end

    let(:task_6) do
      create(:elastic_reindexing_task, :with_subtask, state: :failure, created_at: 31.days.ago)
    end

    let(:task_7) do
      create(:elastic_reindexing_task, :with_subtask, state: :failure, created_at: 2.days.ago)
    end

    let(:successful_tasks_for_deletion) { [task_3, task_4] }
    let(:failed_tasks_for_deletion) { [task_6] }
    let(:other_tasks) { [task_1, task_2, task_5, task_7] }

    it 'deletes the correct indices' do
      other_tasks.each do |task|
        expect(helper).not_to receive(:delete_index).with(index_name: task.subtasks.first.index_name_from)
        expect(helper).not_to receive(:delete_index).with(index_name: task.subtasks.first.index_name_to)
      end

      successful_tasks_for_deletion.each do |task|
        expect(helper).to receive(:delete_index).with(index_name: task.subtasks.first.index_name_from).and_return(true)
      end

      failed_tasks_for_deletion.each do |task|
        expect(helper).to receive(:delete_index).with(index_name: task.subtasks.first.index_name_to).and_return(true)
      end

      described_class.drop_old_indices!

      successful_tasks_for_deletion.each do |task|
        expect(task.reload.state).to eq('original_index_deleted')
      end

      failed_tasks_for_deletion.each do |task|
        expect(task.reload.state).to eq('failed_index_deleted')
      end
    end
  end

  describe '#target_classes' do
    let(:task) { described_class.new }

    it 'returns custom classes' do
      task.targets = %w[Issue Repository]

      expect(task.target_classes).to match_array([Issue, Repository])
    end

    it 'returns all classes when targets are empty' do
      expect(task.target_classes).to be(::Search::Elastic::Helper::INDEXED_CLASSES)
    end
  end

  describe '#delete_failed_index_at' do
    context 'when task state is failure' do
      it 'returns when the failed task would be deleted' do
        task = create(:elastic_reindexing_task, state: :failure)

        expect(task.delete_failed_index_at).to eq(task.created_at + described_class::DELETE_FAILED_INDEX_AFTER)
      end
    end

    context 'when task state is not failure' do
      it 'returns nil' do
        task = create(:elastic_reindexing_task, state: :success)

        expect(task.delete_failed_index_at).to be_nil
      end
    end
  end
end
