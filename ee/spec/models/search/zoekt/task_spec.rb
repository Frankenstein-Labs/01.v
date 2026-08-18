# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Task, feature_category: :global_search do
  subject(:task) { create(:zoekt_task) }

  describe 'relations' do
    it { is_expected.to belong_to(:node).inverse_of(:tasks) }
    it { is_expected.to belong_to(:zoekt_repository).inverse_of(:tasks) }
  end

  describe 'attribute :retries_left' do
    subject(:task) { build(:zoekt_task) }

    it 'has a default value of 3' do
      expect(task.retries_left).to eq(3)
    end
  end

  describe 'scopes' do
    describe '.with_project' do
      let_it_be(:task) { create(:zoekt_task) }

      it 'eager loads the project and avoids N+1 queries' do
        task = described_class.with_project.first
        recorder = ActiveRecord::QueryRecorder.new { task.zoekt_repository.project }
        expect(recorder.count).to be_zero
      end
    end

    describe '.preload_namespace_settings' do
      let_it_be(:task) { create(:zoekt_task) }

      it 'eager loads the namespace_settings and avoids N+1 queries' do
        task = described_class.preload_namespace_settings.first
        recorder = ActiveRecord::QueryRecorder.new do
          task.zoekt_repository.project.namespace.namespace_settings
          task.zoekt_repository.project.namespace.namespace_settings_with_ancestors_inherited_settings
        end
        expect(recorder.count).to be_zero
      end
    end

    describe '.perform_now' do
      let_it_be(:task) { create(:zoekt_task, perform_at: 1.day.ago) }
      let_it_be(:task2) { create(:zoekt_task, perform_at: 1.day.from_now) }

      it 'returns only tasks whose perform_at is older than the current time' do
        results = described_class.perform_now
        expect(results).to include task
        expect(results).not_to include task2
      end
    end

    describe '.pending_or_processing' do
      let_it_be(:task) { create(:zoekt_task, :done) }
      let_it_be(:task2) { create(:zoekt_task, :pending) }
      let_it_be(:task3) { create(:zoekt_task, :processing) }
      let_it_be(:task4) { create(:zoekt_task, :orphaned) }
      let_it_be(:task5) { create(:zoekt_task, :failed) }

      it 'returns only tasks whose perform_at is older than the current time' do
        results = described_class.pending_or_processing
        expect(results).to include task2, task3
        expect(results).not_to include task, task4, task5
      end
    end

    describe '.processing_queue' do
      let_it_be(:task) { create(:zoekt_task, perform_at: 1.day.ago) }
      let_it_be(:task2) { create(:zoekt_task, perform_at: 1.day.from_now) }
      let_it_be(:task3) { create(:zoekt_task, :done, perform_at: 1.day.ago) }
      let_it_be(:task4) { create(:zoekt_task, :processing, perform_at: 1.day.ago) }

      it 'returns only pending or processing tasks where perform_at is older than current time' do
        results = described_class.processing_queue
        expect(results).to include task, task4
        expect(results).not_to include task2, task3
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation' do
      before do
        task.project_identifier = nil
      end

      it 'sets project_identifier' do
        expect(task.project_identifier).to be_nil
        task.validate!
        expect(task.project_identifier).not_to be_nil
        expect(task.project_identifier).to eq(task.zoekt_repository.project_identifier)
      end
    end
  end

  describe '.with_project' do
    it 'eager loads the zoekt_repositories and projects' do
      create(:zoekt_task)
      task = described_class.with_project.first
      recorder = ActiveRecord::QueryRecorder.new { task.zoekt_repository.project }

      expect(recorder.count).to be_zero
      expect(task.association(:zoekt_repository).loaded?).to be(true)
    end
  end

  describe '.each_task_for_processing' do
    let_it_be(:project_with_repo_1) { create(:project) }
    let_it_be(:project_with_repo_2) { create(:project) }
    let_it_be(:project_with_repo_3) { create(:project) }

    it 'returns tasks sorted by performed_at and unique by project and moves the task to processing' do
      task_1 = create(:zoekt_task, project: project_with_repo_1, perform_at: 1.minute.ago)
      task_2 = create(:zoekt_task, project: project_with_repo_2, perform_at: 3.minutes.ago)
      task_with_same_project = create(:zoekt_task, project: project_with_repo_2, perform_at: 5.minutes.ago)
      task_in_future = create(:zoekt_task, project: project_with_repo_3, perform_at: 3.minutes.from_now)

      tasks = []
      described_class.each_task_for_processing(limit: 10) { |task| tasks << task }

      expect(tasks.all? { |task| task.reload.processing? }).to be true
      expect(tasks).not_to include(task_2, task_in_future)
      expect(tasks).to contain_exactly(task_with_same_project, task_1)
    end

    context 'with orphaned task' do
      let_it_be(:orphaned_indexing_task) { create(:zoekt_task) }
      let_it_be(:orphaned_delete_task) { create(:zoekt_task, task_type: :delete_repo) }

      before do
        orphaned_indexing_task.zoekt_repository.project.destroy!
        orphaned_delete_task.zoekt_repository.project.destroy!
      end

      it 'marks indexing tasks as orphaned' do
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.to change { orphaned_indexing_task.reload.state }.from('pending').to('orphaned')
        expect(orphaned_delete_task.reload.state).to eq('processing')
      end
    end

    context 'with failed repo task' do
      let_it_be_with_reload(:failed_repo_indexing_task) { create(:zoekt_task, project: project_with_repo_1) }
      let_it_be_with_reload(:failed_repo_delete_task) do
        create(:zoekt_task, task_type: :delete_repo, project: project_with_repo_2)
      end

      before do
        failed_repo_indexing_task.zoekt_repository.failed!
        failed_repo_delete_task.zoekt_repository.failed!
      end

      it 'marks indexing tasks as skipped' do
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.to change { failed_repo_indexing_task.reload.state }.from('pending').to('skipped')
        expect(failed_repo_delete_task.reload).to be_processing
      end
    end

    context 'with pending_deletion repo task' do
      let_it_be_with_reload(:pending_deletion_repo_indexing_task) do
        create(:zoekt_task, project: project_with_repo_1)
      end

      let_it_be_with_reload(:pending_deletion_repo_delete_task) do
        create(:zoekt_task, task_type: :delete_repo, project: project_with_repo_2)
      end

      before do
        pending_deletion_repo_indexing_task.zoekt_repository.pending_deletion!
        pending_deletion_repo_delete_task.zoekt_repository.pending_deletion!
      end

      it 'marks indexing tasks as skipped and processes delete tasks' do
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.to change { pending_deletion_repo_indexing_task.reload.state }.from('pending').to('skipped')
        expect(pending_deletion_repo_delete_task.reload).to be_processing
      end

      it 'updates repository states correctly' do
        # Repository state should remain pending_deletion for indexing task since it's skipped
        # Delete task repository state should not be changed here since it's processed normally
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.not_to change { pending_deletion_repo_indexing_task.zoekt_repository.reload.state }

        expect(pending_deletion_repo_indexing_task.zoekt_repository.reload).to be_pending_deletion
      end
    end

    context 'with failed zoekt task' do
      it 'does not mark tasks as processing even with retries left' do
        # Create a failed task that still has retries left
        failed_task = create(:zoekt_task,
          project: project_with_repo_1,
          perform_at: 1.minute.ago,
          state: :failed,
          retries_left: 2)

        # Run the task processing
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.not_to change { failed_task.reload.state }.from('failed')
      end

      it 'does not mark tasks as processing with no retries left' do
        # Create a failed task with no retries left
        failed_task = create(:zoekt_task,
          project: project_with_repo_1,
          perform_at: 1.minute.ago,
          state: :failed,
          retries_left: 0)

        # Run the task processing
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.not_to change { failed_task.reload.state }.from('failed')
      end
    end

    context 'with missing gitaly repo' do
      let_it_be(:project_without_repo) { create(:project) }
      let_it_be(:task_with_empty_repo) { create(:zoekt_task, project: project_without_repo) }
      let_it_be(:delete_task_with_empty_repo) do
        create(:zoekt_task, task_type: :delete_repo, project: project_without_repo)
      end

      it 'processes the tasks as normal' do
        expect do
          described_class.each_task_for_processing(limit: 10) { |t| t }
        end.to change { task_with_empty_repo.reload.state }.from('pending').to('processing')
        expect(delete_task_with_empty_repo.reload).to be_pending
        expect(task_with_empty_repo.zoekt_repository.reload).not_to be_ready
      end
    end
  end

  describe '.update_task_states' do
    let_it_be(:skipped_tasks) { create_list(:zoekt_task, 3, :pending) }
    let_it_be(:orphaned_tasks) { create_list(:zoekt_task, 2, :pending) }
    let_it_be(:valid_tasks) { create_list(:zoekt_task, 4, :pending) }
    let_it_be(:done_tasks) { create_list(:zoekt_task, 2, :pending) }

    let(:states) do
      {
        skipped: skipped_tasks.map(&:id),
        orphaned: orphaned_tasks.map(&:id),
        valid: valid_tasks.map(&:id),
        done: done_tasks.map(&:id)
      }
    end

    it 'updates tasks to their appropriate states' do
      freeze_time do
        expect do
          described_class.update_task_states(states: states)
        end.to change { skipped_tasks.map { |t| t.reload.skipped? }.all? }.from(false).to(true)
          .and change { orphaned_tasks.map { |t| t.reload.orphaned? }.all? }.from(false).to(true)
          .and change { valid_tasks.map { |t| t.reload.processing? }.all? }.from(false).to(true)
          .and change { done_tasks.map { |t| t.reload.done? }.all? }.from(false).to(true)

        # Check that updated_at was set for all tasks
        skipped_tasks.each { |t| expect(t.reload.updated_at).to eq(Time.current) }
        orphaned_tasks.each { |t| expect(t.reload.updated_at).to eq(Time.current) }
        valid_tasks.each { |t| expect(t.reload.updated_at).to eq(Time.current) }
        done_tasks.each { |t| expect(t.reload.updated_at).to eq(Time.current) }

        # Only done tasks should cause their repositories to be marked as ready
        done_repo_ids = done_tasks.map { |t| t.zoekt_repository.id }
        expect(Search::Zoekt::Repository.id_in(done_repo_ids).all?(&:ready?)).to be true
      end
    end
  end

  describe '.determine_task_state' do
    let_it_be(:project) { create(:project) }

    context 'for delete_repo task' do
      let(:task) { create(:zoekt_task, task_type: :delete_repo, project: project) }

      it 'returns :valid regardless of repository state' do
        task.zoekt_repository.pending_deletion!
        expect(described_class.determine_task_state(task)).to eq(:valid)
      end
    end

    context 'for index_repo task' do
      let(:task) { create(:zoekt_task, project: project) }

      context 'when repository is pending_deletion' do
        before do
          task.zoekt_repository.pending_deletion!
        end

        it 'returns :skipped' do
          expect(described_class.determine_task_state(task)).to eq(:skipped)
        end
      end

      context 'when repository is failed' do
        before do
          task.zoekt_repository.failed!
        end

        it 'returns :skipped' do
          expect(described_class.determine_task_state(task)).to eq(:skipped)
        end
      end

      context 'when project does not exist' do
        before do
          allow(task.zoekt_repository).to receive(:project).and_return(nil)
        end

        it 'returns :orphaned' do
          expect(described_class.determine_task_state(task)).to eq(:orphaned)
        end
      end

      context 'when project repo does not exist' do
        before do
          allow(project).to receive(:repo_exists?).and_return(false)
        end

        it 'returns :valid' do
          expect(described_class.determine_task_state(task)).to eq(:valid)
        end
      end

      context 'when project repo exists and repository is ready' do
        before do
          task.zoekt_repository.ready!
          allow(project).to receive(:repo_exists?).and_return(true)
        end

        it 'returns :valid' do
          expect(described_class.determine_task_state(task)).to eq(:valid)
        end
      end
    end
  end

  describe 'sliding_list partitioning' do
    let(:partition_manager) { Gitlab::Database::Partitioning::PartitionManager.new(described_class) }

    describe 'next_partition_if callback' do
      let(:active_partition) { described_class.partitioning_strategy.active_partition }

      subject(:value) { described_class.partitioning_strategy.next_partition_if.call(active_partition) }

      context 'when the partition is empty' do
        it { is_expected.to be(false) }
      end

      context 'when the partition has records' do
        before do
          create(:zoekt_task, state: :pending)
          create(:zoekt_task, state: :done)
          create(:zoekt_task, state: :failed)
        end

        it { is_expected.to be(false) }

        context 'when the first record of the partition is older than PARTITION_DURATION' do
          before do
            described_class.first.update!(created_at: (described_class::PARTITION_DURATION + 1.day).ago)
          end

          it { is_expected.to be(true) }
        end
      end
    end

    describe 'detach_partition_if callback' do
      let(:active_partition) { described_class.partitioning_strategy.active_partition }

      subject(:value) { described_class.partitioning_strategy.detach_partition_if.call(active_partition) }

      context 'when the partition contains pending records' do
        let!(:task) { create(:zoekt_task, state: :pending) }

        it { is_expected.to be(false) }
      end

      context 'when the partition is empty' do
        it { is_expected.to be(true) }
      end

      context 'when the partition contains processing records' do
        let!(:task) { create(:zoekt_task, state: :processing) }

        it { is_expected.to be(false) }
      end

      context 'when the newest record of the partition is older than PARTITION_CLEANUP_THRESHOLD' do
        let_it_be(:created_at) { (described_class::PARTITION_CLEANUP_THRESHOLD + 1.day).ago }

        let_it_be(:task_failed) { create(:zoekt_task, state: :failed, created_at: created_at) }
        let_it_be(:task_done) { create(:zoekt_task, state: :done, created_at: created_at) }
        let_it_be(:task_orphaned) { create(:zoekt_task, state: :orphaned, created_at: created_at) }

        context 'when the partition does not contain pending or processing records' do
          it { is_expected.to be(true) }
        end

        context 'when there are pending or processing records' do
          let_it_be(:task_pending) { create(:zoekt_task, state: :pending, created_at: created_at) }

          it { is_expected.to be(false) }
        end

        context 'when there are pending or processing records for orphaned node' do
          let_it_be(:task_pending) do
            create(:zoekt_task, state: :pending, created_at: created_at, zoekt_node_id: non_existing_record_id)
          end

          it { is_expected.to be(true) }
        end
      end
    end
  end
end
