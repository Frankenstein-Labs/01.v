# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::RakeTask::Zoekt, :silence_stdout, feature_category: :global_search do
  let(:stdout_logger) { instance_double(Logger) }
  let(:task_executor_service) { instance_double(Search::Zoekt::RakeTaskExecutorService) }

  before do
    allow(described_class).to receive(:stdout_logger).and_return(stdout_logger)
    allow(task_executor_service).to receive(:execute)
    allow(Search::Zoekt::RakeTaskExecutorService).to receive(:new).and_return(task_executor_service)
    allow(stdout_logger).to receive(:info)
    # Stub internal methods to prevent actual system behavior
    allow(described_class).to receive(:clear_screen)
    allow(described_class).to receive(:sleep)
  end

  describe '.info' do
    before do
      # Make run_with_interval yield once and then raise Interrupt to stop the loop
      allow(described_class).to receive(:run_with_interval).and_call_original
      allow(described_class).to receive(:loop) do |&block|
        block.call
        raise Interrupt
      end
    end

    it 'creates task executor with extended_mode: true when watch_interval is nil' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: stdout_logger, options: { extended_mode: true })
        .and_return(task_executor_service)

      described_class.info(name: 'test', watch_interval: nil)
    end

    it 'creates task executor with extended_mode: false when interval is present' do
      allow(Gitlab::Utils).to receive(:to_boolean).and_return(false)

      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: stdout_logger, options: { extended_mode: false })
        .and_return(task_executor_service)

      described_class.info(name: 'test', watch_interval: '5', extended: 'false')
    end

    it 'executes the info task' do
      expect(task_executor_service).to receive(:execute).with(:info)

      described_class.info(name: 'test')
    end

    it 'does not enter the loop when watch_interval is nil' do
      expect(described_class).not_to receive(:loop)

      described_class.info(name: 'test', watch_interval: nil)
    end

    it 'enters the loop when watch_interval is positive' do
      expect(described_class).to receive(:loop)

      described_class.info(name: 'test', watch_interval: '5')
    end
  end

  describe '.health' do
    before do
      # Make run_with_interval yield once and then raise Interrupt to stop the loop
      allow(described_class).to receive(:run_with_interval).and_call_original
      allow(described_class).to receive(:loop) do |&block|
        block.call
        raise Interrupt
      end
    end

    it 'creates task executor with empty options when watch_interval is nil' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: stdout_logger, options: {})
        .and_return(task_executor_service)

      described_class.health(name: 'test', watch_interval: nil)
    end

    it 'creates task executor with empty options when watch_interval is zero' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: stdout_logger, options: {})
        .and_return(task_executor_service)

      described_class.health(name: 'test', watch_interval: '0')
    end

    it 'creates task executor with watch_mode options when interval is positive' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: stdout_logger, options: { watch_mode: true, watch_interval: 5 })
        .and_return(task_executor_service)

      described_class.health(name: 'test', watch_interval: '5')
    end

    it 'executes the health task' do
      expect(task_executor_service).to receive(:execute).with(:health)

      described_class.health(name: 'test')
    end

    it 'does not enter the loop when watch_interval is nil' do
      expect(described_class).not_to receive(:loop)

      described_class.health(name: 'test', watch_interval: nil)
    end

    it 'enters the loop when watch_interval is positive' do
      expect(described_class).to receive(:loop)

      described_class.health(name: 'test', watch_interval: '5')
    end
  end

  describe '.index' do
    context 'when indexing succeeds' do
      before do
        allow(task_executor_service).to receive(:execute).with(:index).and_return(true)
      end

      it 'does not abort' do
        expect(described_class).not_to receive(:abort)

        described_class.index
      end
    end

    context 'when indexing fails' do
      before do
        allow(task_executor_service).to receive(:execute).with(:index).and_return(false)
      end

      it 'aborts with error message' do
        expect(described_class).to receive(:abort).with('Failed to index')

        described_class.index
      end
    end
  end

  describe '.disable' do
    context 'when disabling succeeds' do
      before do
        allow(task_executor_service).to receive(:execute).with(:disable).and_return(true)
      end

      it 'does not abort' do
        expect(described_class).not_to receive(:abort)

        described_class.disable
      end
    end

    context 'when disabling fails' do
      before do
        allow(task_executor_service).to receive(:execute).with(:disable).and_return(false)
      end

      it 'aborts with error message' do
        expect(described_class).to receive(:abort).with('Failed to disable')

        described_class.disable
      end
    end
  end

  describe '.pause_indexing' do
    context 'when pausing succeeds' do
      before do
        allow(task_executor_service).to receive(:execute).with(:pause_indexing).and_return(true)
      end

      it 'does not abort' do
        expect(described_class).not_to receive(:abort)

        described_class.pause_indexing
      end
    end

    context 'when pausing fails' do
      before do
        allow(task_executor_service).to receive(:execute).with(:pause_indexing).and_return(false)
      end

      it 'aborts with error message' do
        expect(described_class).to receive(:abort).with('Failed to pause indexing')

        described_class.pause_indexing
      end
    end
  end

  describe '.resume_indexing' do
    context 'when resuming succeeds' do
      before do
        allow(task_executor_service).to receive(:execute).with(:resume_indexing).and_return(true)
      end

      it 'does not abort' do
        expect(described_class).not_to receive(:abort)

        described_class.resume_indexing
      end
    end

    context 'when resuming fails' do
      before do
        allow(task_executor_service).to receive(:execute).with(:resume_indexing).and_return(false)
      end

      it 'aborts with error message' do
        expect(described_class).to receive(:abort).with('Failed to resume indexing')

        described_class.resume_indexing
      end
    end
  end

  describe '.estimate_storage' do
    it 'executes the estimate_storage task' do
      expect(task_executor_service).to receive(:execute).with(:estimate_storage)

      described_class.estimate_storage
    end
  end

  describe '.reindex_projects' do
    context 'when reindexing succeeds' do
      before do
        allow(task_executor_service).to receive(:execute).with(:reindex_projects).and_return(true)
      end

      it 'does not abort' do
        expect(described_class).not_to receive(:abort)

        described_class.reindex_projects
      end
    end

    context 'when reindexing fails' do
      before do
        allow(task_executor_service).to receive(:execute).with(:reindex_projects).and_return(false)
      end

      it 'aborts with error message' do
        expect(described_class).to receive(:abort).with('Failed to reindex projects')

        described_class.reindex_projects
      end
    end
  end

  describe '.reindex_failed_projects' do
    context 'when no project_ids are provided' do
      before do
        allow(task_executor_service).to receive(:execute).with(:reindex_failed_projects).and_return(true)
      end

      it 'creates task executor with project_ids: nil and does not abort', :aggregate_failures do
        expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
          .with(logger: stdout_logger, options: { project_ids: nil })
          .and_return(task_executor_service)
        expect(described_class).not_to receive(:abort)

        described_class.reindex_failed_projects
      end
    end

    context 'when project_ids are provided' do
      before do
        allow(task_executor_service).to receive(:execute).with(:reindex_failed_projects).and_return(true)
      end

      it 'creates task executor with the given project_ids and does not abort', :aggregate_failures do
        expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
          .with(logger: stdout_logger, options: { project_ids: [1, 2, 3] })
          .and_return(task_executor_service)
        expect(described_class).not_to receive(:abort)

        described_class.reindex_failed_projects(project_ids: [1, 2, 3])
      end
    end

    context 'when reindexing fails' do
      before do
        allow(task_executor_service).to receive(:execute).with(:reindex_failed_projects).and_return(false)
      end

      it 'aborts with error message' do
        expect(described_class).to receive(:abort).with('Failed to reindex failed projects')

        described_class.reindex_failed_projects
      end
    end
  end
end
