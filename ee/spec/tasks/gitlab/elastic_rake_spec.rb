# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:elastic namespace rake tasks', :silence_stdout, feature_category: :global_search do
  let(:logger) { Logger.new(StringIO.new) }

  before do
    Rake.application.rake_require 'tasks/gitlab/elastic'

    allow(Search::RakeTask::Elastic).to receive(:stdout_logger).and_return(logger)
  end

  shared_examples 'rake task executor task' do |task|
    it 'calls rake task executor' do
      expect_next_instance_of(Search::RakeTaskExecutorService) do |instance|
        expect(instance).to receive(:execute).with(task)
      end

      run_rake_task("gitlab:elastic:#{task}")
    end
  end

  describe 'gitlab:elastic:index_group_entities' do
    include_examples 'rake task executor task', :index_group_entities
  end

  describe 'gitlab:elastic:enable_search_with_elasticsearch' do
    include_examples 'rake task executor task', :enable_search_with_elasticsearch
  end

  describe 'gitlab:elastic:disable_search_with_elasticsearch' do
    include_examples 'rake task executor task', :disable_search_with_elasticsearch
  end

  describe 'gitlab:elastic:index_projects' do
    include_examples 'rake task executor task', :index_projects
  end

  describe 'gitlab:elastic:index_projects_status' do
    include_examples 'rake task executor task', :index_projects_status
  end

  describe 'gitlab:elastic:index_groups_status' do
    include_examples 'rake task executor task', :index_groups_status
  end

  describe 'gitlab:elastic:index_snippets' do
    include_examples 'rake task executor task', :index_snippets
  end

  describe 'gitlab:elastic:index_users' do
    include_examples 'rake task executor task', :index_users
  end

  describe 'gitlab:elastic:index_work_items' do
    include_examples 'rake task executor task', :index_work_items
  end

  describe 'gitlab:elastic:index_namespaces' do
    include_examples 'rake task executor task', :index_namespaces
  end

  describe 'gitlab:elastic:index_group_wikis' do
    include_examples 'rake task executor task', :index_group_wikis
  end

  describe 'gitlab:elastic:index_vulnerabilities' do
    include_examples 'rake task executor task', :index_vulnerabilities
  end

  describe 'gitlab:elastic:index_sbom_occurrence_refs' do
    include_examples 'rake task executor task', :index_sbom_occurrence_refs
  end

  describe 'gitlab:elastic:create_empty_index' do
    include_examples 'rake task executor task', :create_empty_index
  end

  describe 'gitlab:elastic:delete_index' do
    include_examples 'rake task executor task', :delete_index
  end

  describe 'gitlab:elastic:recreate_index' do
    include_examples 'rake task executor task', :recreate_index
  end

  describe 'gitlab:elastic:reindex_cluster' do
    include_examples 'rake task executor task', :reindex_cluster
  end

  describe 'gitlab:elastic:clear_index_status' do
    include_examples 'rake task executor task', :clear_index_status
  end

  describe 'gitlab:elastic:projects_not_indexed' do
    include_examples 'rake task executor task', :projects_not_indexed
  end

  describe 'gitlab:elastic:groups_not_indexed' do
    include_examples 'rake task executor task', :groups_not_indexed
  end

  describe 'gitlab:elastic:mark_reindex_failed' do
    include_examples 'rake task executor task', :mark_reindex_failed
  end

  describe 'gitlab:elastic:list_pending_migrations' do
    include_examples 'rake task executor task', :list_pending_migrations

    context 'with elasticsearch_indexing disabled' do
      subject(:task) { run_rake_task('gitlab:elastic:list_pending_migrations') }

      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'outputs warning' do
        expect(logger).to receive(:warn).once.with(/Indexing for advanced search is turned off/)

        task
      end
    end
  end

  describe 'gitlab:elastic:estimate_cluster_size' do
    include_examples 'rake task executor task', :estimate_cluster_size
  end

  describe 'gitlab:elastic:estimate_shard_sizes' do
    include_examples 'rake task executor task', :estimate_shard_sizes
  end

  describe 'gitlab:elastic:pause_indexing' do
    include_examples 'rake task executor task', :pause_indexing
  end

  describe 'gitlab:elastic:resume_indexing' do
    include_examples 'rake task executor task', :resume_indexing
  end

  describe 'gitlab:elastic:info' do
    include_examples 'rake task executor task', :info
  end

  describe 'gitlab:elastic:index_and_search_validation' do
    it 'calls validate_index_and_search on Search::RakeTask::Elastic' do
      expect(Search::RakeTask::Elastic).to receive(:validate_index_and_search)

      run_rake_task('gitlab:elastic:index_and_search_validation')
    end
  end

  describe 'gitlab:elastic:index' do
    subject(:task) { run_rake_task('gitlab:elastic:index') }

    context 'with elasticsearch_indexing is disabled' do
      it 'does not enable `elasticsearch_indexing`' do
        expect { run_rake_task 'gitlab:elastic:index' }.not_to change {
          Gitlab::CurrentSettings.elasticsearch_indexing?
        }
      end
    end

    context 'with elasticsearch_indexing enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      context 'when on GitLab.com', :saas do
        it 'raises an error' do
          expect { task }.to raise_error('This task cannot be run on GitLab.com')
        end
      end

      it 'schedules Search::Elastic::TriggerIndexingWorker asynchronously' do
        expect(::Search::Elastic::TriggerIndexingWorker).to receive(:perform_in)
          .with(1.minute, Search::Elastic::TriggerIndexingWorker::INITIAL_TASK.to_s, { 'skip' => ['projects'] })

        task
      end

      it 'outputs warning if indexing is paused' do
        stub_ee_application_setting(elasticsearch_pause_indexing: true)

        expect(::Search::Elastic::TriggerIndexingWorker).to receive(:perform_in)
          .with(1.minute, Search::Elastic::TriggerIndexingWorker::INITIAL_TASK.to_s, { 'skip' => ['projects'] })
        expect(logger).to receive(:warn).with(/WARNING: Indexing for advanced search is paused/)

        task
      end
    end
  end
end
