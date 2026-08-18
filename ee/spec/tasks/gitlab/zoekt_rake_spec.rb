# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:zoekt namespace rake tasks', :silence_stdout, feature_category: :global_search do
  before do
    Rake.application.rake_require 'tasks/gitlab/zoekt'
  end

  shared_examples 'rake task executor task' do |task|
    it 'calls rake task executor' do
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(task)
      end

      run_rake_task("gitlab:zoekt:#{task}")
    end
  end

  describe 'gitlab:zoekt:info' do
    include_examples 'rake task executor task', :info
  end

  describe 'gitlab:zoekt:health' do
    before do
      # Stub internal methods to prevent actual system behavior in tests
      allow(Search::RakeTask::Zoekt).to receive(:clear_screen)
      allow(Search::RakeTask::Zoekt).to receive(:sleep)
      # Mock the loop to prevent infinite loops in watch mode tests
      allow(Search::RakeTask::Zoekt).to receive(:loop) do |&block|
        block.call
        raise Interrupt
      end
    end

    it 'calls task executor without watch mode when no interval is provided' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: an_instance_of(Logger), options: {})
        .and_return(instance_double(Search::Zoekt::RakeTaskExecutorService, execute: nil))

      run_rake_task('gitlab:zoekt:health')
    end

    it 'calls task executor with watch_mode when interval is provided' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: an_instance_of(Logger), options: { watch_mode: true, watch_interval: 10 })
        .and_return(instance_double(Search::Zoekt::RakeTaskExecutorService, execute: nil))

      run_rake_task('gitlab:zoekt:health', '10')
    end

    it 'handles zero interval as no watch mode' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: an_instance_of(Logger), options: {})
        .and_return(instance_double(Search::Zoekt::RakeTaskExecutorService, execute: nil))

      run_rake_task('gitlab:zoekt:health', '0')
    end

    it 'handles negative interval as no watch mode' do
      expect(Search::Zoekt::RakeTaskExecutorService).to receive(:new)
        .with(logger: an_instance_of(Logger), options: {})
        .and_return(instance_double(Search::Zoekt::RakeTaskExecutorService, execute: nil))

      run_rake_task('gitlab:zoekt:health', '-5')
    end
  end

  describe 'gitlab:zoekt:install' do
    context 'when no arguments are provided' do
      it 'raises error' do
        expect { run_rake_task('gitlab:zoekt:install') }.to raise_error(/Please specify the directory/)
      end
    end

    context 'when arguments are provided' do
      context 'when make is not found' do
        before do
          allow(Gitlab::Utils).to receive(:which).and_return(nil)
        end

        it 'raises error' do
          expect { run_rake_task('gitlab:zoekt:install', '/test/dir') }.to raise_error(/Couldn't find a 'make' binary/)
        end
      end

      context 'when make is found' do
        before do
          allow(Gitlab::Utils).to receive(:which).and_return('gmake')
          allow(main_object).to receive(:run_command!).with(%w[gmake build-unified])
          allow(Dir).to receive(:chdir).with('/test/dir').and_yield
        end

        context 'when repo arg is not provided' do
          it 'calls checkout_or_clone_version with default repo' do
            expect(main_object).to receive(:checkout_or_clone_version)
                                     .with(version: Rails.root.join('GITLAB_ZOEKT_VERSION').read.chomp,
                                       repo: 'https://gitlab.com/gitlab-org/gitlab-zoekt-indexer.git',
                                       target_dir: '/test/dir',
                                       clone_opts: %w[--depth 1]
                                     )

            run_rake_task('gitlab:zoekt:install', '/test/dir')
          end
        end

        context 'when repo arg is also provided' do
          it 'calls checkout_or_clone_version with given repo' do
            expect(main_object).to receive(:checkout_or_clone_version)
                                     .with(version: Rails.root.join('GITLAB_ZOEKT_VERSION').read.chomp,
                                       repo: 'repo',
                                       target_dir: '/test/dir',
                                       clone_opts: %w[--depth 1]
                                     )

            run_rake_task('gitlab:zoekt:install', '/test/dir', 'repo')
          end
        end
      end
    end
  end

  describe 'watch functionality in rake task' do
    it 'executes the rake task normally without watch mode when no interval is provided' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info")
    end

    it 'executes the rake task normally when interval is zero' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info", "0")
    end

    it 'executes the rake task normally when interval is negative' do
      # We expect the task executor to be called directly
      expect_next_instance_of(Search::Zoekt::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(:info)
      end

      run_rake_task("gitlab:zoekt:info", "-1")
    end
  end

  describe 'gitlab:zoekt:index' do
    it 'calls Search::RakeTask::Zoekt.index' do
      expect(Search::RakeTask::Zoekt).to receive(:index)

      run_rake_task('gitlab:zoekt:index')
    end
  end

  describe 'gitlab:zoekt:disable' do
    it 'calls Search::RakeTask::Zoekt.disable' do
      expect(Search::RakeTask::Zoekt).to receive(:disable)

      run_rake_task('gitlab:zoekt:disable')
    end
  end

  describe 'gitlab:zoekt:pause_indexing' do
    it 'calls Search::RakeTask::Zoekt.pause_indexing' do
      expect(Search::RakeTask::Zoekt).to receive(:pause_indexing)

      run_rake_task('gitlab:zoekt:pause_indexing')
    end
  end

  describe 'gitlab:zoekt:resume_indexing' do
    it 'calls Search::RakeTask::Zoekt.resume_indexing' do
      expect(Search::RakeTask::Zoekt).to receive(:resume_indexing)

      run_rake_task('gitlab:zoekt:resume_indexing')
    end
  end

  describe 'gitlab:zoekt:estimate_storage' do
    it 'calls Search::RakeTask::Zoekt.estimate_storage' do
      expect(Search::RakeTask::Zoekt).to receive(:estimate_storage)

      run_rake_task('gitlab:zoekt:estimate_storage')
    end
  end

  describe 'gitlab:zoekt:reindex_projects' do
    it 'calls Search::RakeTask::Zoekt.reindex_projects' do
      expect(Search::RakeTask::Zoekt).to receive(:reindex_projects)

      run_rake_task('gitlab:zoekt:reindex_projects')
    end
  end

  describe 'gitlab:zoekt:reindex_failed_projects' do
    it 'calls Search::RakeTask::Zoekt.reindex_failed_projects with project_ids: nil when no args given' do
      expect(Search::RakeTask::Zoekt).to receive(:reindex_failed_projects).with(project_ids: nil)

      run_rake_task('gitlab:zoekt:reindex_failed_projects')
    end

    it 'calls Search::RakeTask::Zoekt.reindex_failed_projects with parsed project_ids when args given' do
      expect(Search::RakeTask::Zoekt).to receive(:reindex_failed_projects).with(project_ids: [1, 2, 3])

      run_rake_task('gitlab:zoekt:reindex_failed_projects', '1\,2\,3')
    end
  end
end
