# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::RakeTaskExecutorService, :elastic_helpers, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double(Logger) }
  let(:service) { described_class.new(logger: logger) }

  before do
    allow(logger).to receive(:info)
  end

  describe '#execute' do
    it 'raises an exception when unknown task is provided' do
      expect { service.execute(:foo) }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the task is not implemented' do
      stub_const('::Search::RakeTaskExecutorService::TASKS', [:foo])

      expect { service.execute(:foo) }.to raise_error(NotImplementedError)
    end

    described_class::TASKS.each do |task|
      it "executes #{task} task" do
        expect(service).to receive(task).and_return(true)

        service.execute(task)
      end
    end
  end

  describe '#create_empty_index' do
    before do
      es_helper.delete_index
      es_helper.delete_standalone_indices
      es_helper.delete_migrations_index
    end

    it 'creates the default index' do
      expect { service.execute(:create_empty_index) }.to change { es_helper.index_exists? }.from(false).to(true)
    end

    context 'when SKIP_ALIAS environment variable is set' do
      before do
        stub_env('SKIP_ALIAS', '1')
      end

      after do
        es_client.cat.indices(index: "#{es_helper.target_name}-*", h: 'index').split("\n").each do |index_name|
          es_client.indices.delete(index: index_name)
        end
      end

      it 'does not alias the new index' do
        expect { service.execute(:create_empty_index) }
          .not_to change { es_helper.alias_exists?(name: es_helper.target_name) }
      end

      it 'does not create the migrations index if it does not exist' do
        migration_index_name = es_helper.migrations_index_name
        es_helper.delete_index(index_name: migration_index_name)

        expect { service.execute(:create_empty_index) }
          .not_to change { es_helper.migrations_index_exists? }
      end

      it 'does not create standalone indices' do
        service.execute(:create_empty_index)

        Search::Elastic::Helper::ES_SEPARATE_CLASSES.each do |class_name|
          proxy = get_class_proxy(class_name: class_name, use_separate_indices: true)

          expect(es_helper.alias_exists?(name: proxy.index_name)).to be(false), "#{proxy.index_name} shouldn't exist"
        end
      end
    end

    it 'creates the migrations index if it does not exist' do
      migration_index_name = es_helper.migrations_index_name
      es_helper.delete_index(index_name: migration_index_name)

      expect { service.execute(:create_empty_index) }
        .to change { es_helper.migrations_index_exists? }.from(false).to(true)
    end

    it 'creates standalone indices' do
      service.execute(:create_empty_index)

      Search::Elastic::Helper::ES_SEPARATE_CLASSES.each do |class_name|
        proxy = get_class_proxy(class_name: class_name, use_separate_indices: true)

        expect(es_helper.index_exists?(index_name: proxy.index_name)).to be(true), "#{proxy.index_name} shouldn't exist"
      end
    end

    it 'marks all migrations as completed' do
      expect(Elastic::DataMigrationService).to receive(:mark_all_as_completed!).and_call_original

      service.execute(:create_empty_index)
      refresh_index!

      migrations = Elastic::DataMigrationService.migrations.map(&:version)
      expect(Elastic::MigrationRecord.load_versions(completed: true)).to eq(migrations)
    end
  end

  describe '#delete_index', :elastic_clean do
    let(:helper) { ::Search::Elastic::Helper.default }

    subject(:delete_index) { service.execute(:delete_index) }

    before do
      allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
    end

    it 'removes the index' do
      expect { delete_index }.to change { es_helper.index_exists? }.from(true).to(false)
    end

    context 'when delete_index returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_index).and_return(false)

        expect(logger).to receive(:info).with(%r{Index/alias '#{helper.target_name}' was not found})

        delete_index
      end
    end

    context 'when delete_standalone_indices returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_standalone_indices).and_return([['projects-123', 'projects', false]])

        expect(logger).to receive(:info).with(/Index 'projects-123' with alias 'projects' was not found/)

        delete_index
      end
    end

    it 'removes the migrations index' do
      expect { delete_index }.to change { es_helper.migrations_index_exists? }.from(true).to(false)
    end

    context 'when delete_migrations_index returns false' do
      it 'logs that the index was not found' do
        allow(helper).to receive(:delete_migrations_index).and_return(false)

        expect(logger).to receive(:info).with(%r{Index/alias '#{es_helper.migrations_index_name}' was not found})

        delete_index
      end
    end

    context 'when the index does not exist' do
      it 'does not error' do
        expect { service.execute(:delete_index) }.not_to raise_error
        expect { service.execute(:delete_index) }.not_to raise_error
      end
    end
  end

  describe '#index_snippets' do
    it 'indexes snippets' do
      expect(Snippet).to receive(:es_import)
      expect(logger).to receive(:info).with(/Indexing snippets/).twice

      service.execute(:index_snippets)
    end
  end

  describe '#pause_indexing' do
    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      settings.update!(elasticsearch_pause_indexing: indexing_paused)
    end

    context 'when indexing is already paused' do
      let(:indexing_paused) { true }

      it 'does not do anything' do
        expect(settings).not_to receive(:update!)
        expect(logger).to receive(:info).with(/Pausing indexing.../)
        expect(logger).to receive(:info).with(/Indexing is already paused/)

        expect { service.execute(:pause_indexing) }.not_to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end

    context 'when indexing is running' do
      let(:indexing_paused) { false }

      it 'pauses indexing' do
        expect(logger).to receive(:info).with(/Pausing indexing.../)
        expect(logger).to receive(:info).with(/Indexing is now paused/)

        expect { service.execute(:pause_indexing) }.to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end
  end

  describe '#resume_indexing' do
    let(:settings) { ::Gitlab::CurrentSettings }
    let(:indexing_paused) { true }
    let(:indexing_enabled) { true }

    before do
      settings.update!(elasticsearch_pause_indexing: indexing_paused,
        elasticsearch_indexing: indexing_enabled)
      allow(::Search::Elastic::ReindexingTask).to receive(:running?).and_return(false)
      allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])
    end

    context 'when indexing is disabled' do
      let(:indexing_enabled) { false }

      it 'does not resume indexing and logs an error' do
        expect(logger).to receive(:info).with(/Resuming indexing.../)
        expect(logger).to receive(:error).with(/Cannot resume indexing: Indexing is disabled/)

        expect { service.execute(:resume_indexing) }.not_to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end

    context 'when a reindexing task is in progress' do
      before do
        allow(::Search::Elastic::ReindexingTask).to receive(:running?).and_return(true)
      end

      it 'does not resume indexing and logs an error' do
        expect(logger).to receive(:info).with(/Resuming indexing.../)
        expect(logger).to receive(:error).with(/Cannot resume indexing: A reindexing task is currently in progress/)

        expect { service.execute(:resume_indexing) }.not_to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end

    context 'when a migration is running that requires paused indexing' do
      let(:migration) { ::Elastic::DataMigrationService.migrations.first }

      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([migration])
        allow(migration).to receive_messages(running?: true, pause_indexing?: true)
      end

      it 'does not resume indexing and logs an error' do
        expect(logger).to receive(:info).with(/Resuming indexing.../)
        expect(logger).to receive(:error)
          .with(/Cannot resume indexing: A migration is running that requires indexing to be paused/)

        expect { service.execute(:resume_indexing) }.not_to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end

    context 'when a migration is running but does not require paused indexing' do
      let(:migration) { ::Elastic::DataMigrationService.migrations.first }

      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([migration])
        allow(migration).to receive_messages(running?: true, pause_indexing?: false)
      end

      it 'resumes indexing successfully' do
        expect(logger).to receive(:info).with(/Resuming indexing.../)
        expect(logger).to receive(:info).with(/Indexing is now running/)

        expect { service.execute(:resume_indexing) }.to change {
          settings.reload.elasticsearch_pause_indexing
        }.from(true).to(false)
      end
    end

    context 'when indexing is already running' do
      let(:indexing_paused) { false }

      it 'does not do anything' do
        expect(logger).to receive(:info).with(/Resuming indexing.../)
        expect(logger).to receive(:info).with(/Indexing is already running/)

        expect { service.execute(:resume_indexing) }.not_to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end

    context 'when indexing is not running' do
      it 'resumes indexing' do
        expect(logger).to receive(:info).with(/Resuming indexing.../)
        expect(logger).to receive(:info).with(/Indexing is now running/)

        expect { service.execute(:resume_indexing) }.to change {
          settings.reload.elasticsearch_pause_indexing
        }
      end
    end
  end

  describe '#pause_advanced_search_indexing' do
    let(:settings) { ::Gitlab::CurrentSettings }

    context 'when advanced search indexing is already paused' do
      before do
        settings.update!(elasticsearch_advanced_search_pause_indexing: true)
      end

      it 'does not change the setting and logs a message' do
        expect(settings).not_to receive(:update!)
        expect(logger).to receive(:info).with(/Advanced search indexing is already paused/)

        expect { service.execute(:pause_advanced_search_indexing) }.not_to change {
          settings.reload.elasticsearch_advanced_search_pause_indexing
        }
      end
    end

    context 'when advanced search indexing is running' do
      before do
        settings.update!(elasticsearch_advanced_search_pause_indexing: false)
      end

      it 'pauses advanced search indexing' do
        expect(logger).to receive(:info).with(/Advanced search indexing is now paused/)

        expect { service.execute(:pause_advanced_search_indexing) }.to change {
          settings.reload.elasticsearch_advanced_search_pause_indexing
        }.from(false).to(true)
      end
    end
  end

  describe '#resume_advanced_search_indexing' do
    let(:settings) { ::Gitlab::CurrentSettings }

    context 'when advanced search indexing is paused' do
      before do
        settings.update!(elasticsearch_advanced_search_pause_indexing: true)
      end

      it 'resumes advanced search indexing' do
        expect(logger).to receive(:info).with(/Advanced search indexing is now running/)

        expect { service.execute(:resume_advanced_search_indexing) }.to change {
          settings.reload.elasticsearch_advanced_search_pause_indexing
        }.from(true).to(false)
      end
    end

    context 'when advanced search indexing is already running' do
      before do
        settings.update!(elasticsearch_advanced_search_pause_indexing: false)
      end

      it 'does not change the setting and logs a message' do
        expect(settings).not_to receive(:update!)
        expect(logger).to receive(:info).with(/Advanced search indexing is already running/)

        expect { service.execute(:resume_advanced_search_indexing) }.not_to change {
          settings.reload.elasticsearch_advanced_search_pause_indexing
        }
      end
    end
  end

  describe '#estimate_cluster_size' do
    before do
      create(:namespace_root_storage_statistics, repository_size: 1.megabyte, wiki_size: 30.megabytes)
      create(:namespace_root_storage_statistics, repository_size: 10.megabytes, wiki_size: 20.megabytes)
      create(:namespace_root_storage_statistics, repository_size: 30.megabytes, wiki_size: 10.megabytes)
    end

    context 'when elasticsearch_code_scope is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_code_scope: true)
      end

      it 'outputs estimates including code index size' do
        expect(logger).to receive(:info).with("This GitLab instance repository size is 41 MiB and wiki size is 60 MiB.")
        expect(logger).to receive(:info)
          .with("The gitlab-test index size will be 20.5 MiB and gitlab-test-wikis index size will be 30 MiB.")
        expect(logger).to receive(:info).with("By our estimates, your cluster size will be at least 50.5 MiB.")

        service.execute(:estimate_cluster_size)
      end
    end

    context 'when elasticsearch_code_scope is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_code_scope: false)
      end

      it 'outputs estimates excluding code index size' do
        expect(logger).to receive(:info).with("This GitLab instance repository size is 0 B and wiki size is 60 MiB.")
        output_msg = "Code search (elasticsearch_code_scope) is disabled in Advanced Search. " \
          "The gitlab-test index will not be populated with code."
        expect(logger).to receive(:info).with(output_msg)
        expect(logger).to receive(:info)
          .with("The gitlab-test index size will be 0 B and gitlab-test-wikis index size will be 30 MiB.")
        expect(logger).to receive(:info).with("By our estimates, your cluster size will be at least 30 MiB.")

        service.execute(:estimate_cluster_size)
      end
    end
  end

  describe '#estimate_shard_sizes' do
    # DB_CLASSES = [Note, MergeRequest, User, Project, WorkItem, Vulnerability, Vulnerabilities::Read,
    #               Sbom::OccurrenceRef, Group]
    let(:db_counts) { [400, 1500, 10_000_000, 4_000, 5_000, 6_000, 6_000, 2_000, 3_000] }

    before do
      allow(logger).to receive(:info)
      allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
      allow(::Gitlab::Database::Count).to receive(:approximate_counts).with(described_class::DB_CLASSES)
        .and_return(Hash[described_class::DB_CLASSES.zip(db_counts)])

      allow(Namespace::RootStorageStatistics).to receive(:sum).with(:repository_size).and_return(1000.gigabytes)
      allow(Namespace::RootStorageStatistics).to receive(:sum).with(:wiki_size).and_return(10.gigabytes)
    end

    it 'outputs shard size estimates' do
      expected_notes = <<~ESTIMATE.chomp
        - gitlab-test-notes:
          recommended shards: 5
          recommended replicas: 1
          document count: 400
      ESTIMATE

      expected_merge_requests = <<~ESTIMATE.chomp
        - gitlab-test-merge_requests:
          recommended shards: 5
          recommended replicas: 1
          document count: 1,500
      ESTIMATE

      expected_users = <<~ESTIMATE.chomp
        - gitlab-test-users:
          recommended shards: 5
          recommended replicas: 1
          document count: 10,000,000
      ESTIMATE

      expected_projects = <<~ESTIMATE.chomp
        - gitlab-test-projects:
          recommended shards: 5
          recommended replicas: 1
          document count: 4,000
      ESTIMATE

      expected_work_items = <<~ESTIMATE.chomp
        - gitlab-test-work_items:
          recommended shards: 5
          recommended replicas: 1
          document count: 5,000
      ESTIMATE

      expected_vulnerabilities = <<~ESTIMATE.chomp
        - gitlab-test-vulnerabilities:
          recommended shards: 5
          recommended replicas: 1
          document count: 6,000
      ESTIMATE

      expected_vulnerability_reads = <<~ESTIMATE.chomp
        - gitlab-test-vulnerability_reads:
          recommended shards: 5
          recommended replicas: 1
          document count: 6,000
      ESTIMATE

      expected_sbom_occurrence_refs = <<~ESTIMATE.chomp
        - gitlab-test-sbom_occurrence_refs:
          recommended shards: 5
          recommended replicas: 1
          document count: 2,000
      ESTIMATE

      expected_groups = <<~ESTIMATE.chomp
        - gitlab-test-groups:
          recommended shards: 5
          recommended replicas: 1
          document count: 3,000
      ESTIMATE

      expected_main_index = <<~ESTIMATE.chomp
        - gitlab-test:
          recommended shards: 16
          recommended replicas: 1
      ESTIMATE

      expected_commits = <<~ESTIMATE.chomp
        - gitlab-test-commits:
          recommended shards: 10
          recommended replicas: 1
      ESTIMATE

      expected_wikis = <<~ESTIMATE.chomp
        - gitlab-test-wikis:
          recommended shards: 5
          recommended replicas: 1
      ESTIMATE

      expect(logger).to receive(:info).with(/#{expected_notes}/)
      expect(logger).to receive(:info).with(/#{expected_merge_requests}/)
      expect(logger).to receive(:info).with(/#{expected_users}/)
      expect(logger).to receive(:info).with(/#{expected_projects}/)
      expect(logger).to receive(:info).with(/#{expected_work_items}/)
      expect(logger).to receive(:info).with(/#{expected_vulnerabilities}/)
      expect(logger).to receive(:info).with(/#{expected_vulnerability_reads}/)
      expect(logger).to receive(:info).with(/#{expected_sbom_occurrence_refs}/)
      expect(logger).to receive(:info).with(/#{expected_groups}/)
      expect(logger).to receive(:info).with(/#{expected_main_index}/)
      expect(logger).to receive(:info).with(/#{expected_commits}/)
      expect(logger).to receive(:info).with(/#{expected_wikis}/)

      service.execute(:estimate_shard_sizes)
    end
  end

  describe '#mark_reindex_failed' do
    context 'when there is a running reindex job' do
      before do
        Search::Elastic::ReindexingTask.create!
      end

      it 'marks the current reindex job as failed' do
        expect(logger).to receive(:info).with(/Marked the current reindexing job as failed/)

        expect { service.execute(:mark_reindex_failed) }
          .to change { Search::Elastic::ReindexingTask.running? }.from(true).to(false)
      end

      it 'prints a message after marking it as failed' do
        expect(logger).to receive(:info).with(/Marked the current reindexing job as failed/)

        service.execute(:mark_reindex_failed)
      end
    end

    context 'when no running reindex job' do
      it 'just prints a message' do
        expect(logger).to receive(:info).with(/Did not find the current running reindexing job/)

        service.execute(:mark_reindex_failed)
      end
    end
  end

  describe '#list_pending_migrations' do
    let(:helper) { es_helper }

    before do
      allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive(:ping?).and_return(true)
    end

    context 'when there are pending migrations' do
      let(:pending_migrations) { ::Elastic::DataMigrationService.migrations.last(2) }
      let(:pending_migration1) { pending_migrations.first }
      let(:pending_migration2) { pending_migrations.second }

      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return(pending_migrations)
      end

      it 'outputs pending migrations' do
        expect(logger).to receive(:info).with(/Pending Migrations/)
        expect(logger).to receive(:info).with(/#{pending_migration1.name}/)
        expect(logger).to receive(:info).with(/#{pending_migration2.name}/)

        service.execute(:list_pending_migrations)
      end

      context 'when search service unreachable' do
        before do
          allow(helper).to receive(:ping?).and_return(false)
        end

        it 'outputs an error' do
          expect(logger).to receive(:info).with(/Pending Migrations/)
          expect(logger).to receive(:error).with(/Unable to connect to search cluster to retrieve data./)

          service.execute(:list_pending_migrations)
        end
      end
    end

    context 'when there is no pending migrations' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])
      end

      it 'outputs message there are no pending migrations' do
        expect(logger).to receive(:info).with(/Pending Migrations/)
        expect(logger).to receive(:info).with(/There are no pending migrations./)

        service.execute(:list_pending_migrations)
      end
    end

    context 'when pending migrations are obsolete' do
      let(:obsolete_pending_migration) { ::Elastic::DataMigrationService.migrations.first }

      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([obsolete_pending_migration])
        allow(obsolete_pending_migration).to receive(:obsolete?).and_return(true)
      end

      it 'outputs that the pending migration is obsolete' do
        expect(logger).to receive(:info).with(/Pending Migrations/)
        expect(logger).to receive(:warn).with(/#{obsolete_pending_migration.name} \[Obsolete\]/)

        service.execute(:list_pending_migrations)
      end
    end
  end

  describe '#enable_search_with_elasticsearch' do
    subject(:task) { service.execute(:enable_search_with_elasticsearch) }

    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      settings.update!(elasticsearch_search: es_enabled)
    end

    context 'when enabling elasticsearch with setting initially off' do
      let(:es_enabled) { false }

      it 'enables elasticsearch' do
        expect(logger).to receive(:info).with(/Setting `elasticsearch_search` has been enabled/)

        expect { task }.to change { settings.elasticsearch_search }.from(false).to(true)
      end
    end

    context 'when enabling elasticsearch with setting initially on' do
      let(:es_enabled) { true }

      it 'does nothing when elasticsearch is already enabled' do
        expect(logger).to receive(:info).with(/Setting `elasticsearch_search` was already enabled/)

        expect { task }.not_to change { settings.elasticsearch_search }
      end
    end
  end

  describe '#index_projects_status' do
    subject(:task) { service.execute(:index_projects_status) }

    let_it_be(:project) { create(:project) }
    let_it_be(:project_no_repository) { create(:project) }
    let_it_be(:project_empty_repository) { create(:project, :empty_repo) }

    context 'when elasticsearch is not enabled for any of the projects' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      it 'returns a warning message' do
        expected = <<~STD_OUT.chomp
          Advanced search is not enabled for any of the projects.
        STD_OUT

        expect(logger).to receive(:warn).with(expected)

        task
      end
    end

    context 'when some projects missing from index' do
      before do
        create(:index_status, project: project)
      end

      it 'displays completion percentage' do
        expected = <<~STD_OUT.chomp
          Indexing is 33.33% complete (1/3 projects). Considers only code, commits, and wikis.
        STD_OUT

        expect(logger).to receive(:info).with(expected)

        task
      end

      context 'when elasticsearch_limit_indexing? is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        it 'only displays non-indexed projects that are setup for indexing' do
          create(:elasticsearch_indexed_project, project: project_no_repository)

          expected = <<~STD_OUT.chomp
            Indexing is 0.00% complete (0/1 projects). Considers only code, commits, and wikis.
          STD_OUT

          expect(logger).to receive(:info).with(expected)

          task
        end
      end
    end

    context 'when all projects are indexed' do
      before do
        create(:index_status, project: project)
        create(:index_status, project: project_no_repository)
        create(:index_status, project: project_empty_repository)
      end

      it 'displays that all projects are indexed' do
        expected = <<~STD_OUT.chomp
          Indexing is 100.00% complete (3/3 projects). Considers only code, commits, and wikis.
        STD_OUT

        expect(logger).to receive(:info).with(expected)

        task
      end

      context 'when elasticsearch_limit_indexing? is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        it 'only displays non-indexed projects that are setup for indexing' do
          create(:elasticsearch_indexed_project, project: project_empty_repository)

          expected = <<~STD_OUT.chomp
            Indexing is 100.00% complete (1/1 projects). Considers only code, commits, and wikis.
          STD_OUT

          expect(logger).to receive(:info).with(expected)

          task
        end
      end
    end
  end

  describe '#index_groups_status' do
    subject(:task) { service.execute(:index_groups_status) }

    let_it_be(:group) { create(:group, :wiki_repo) }
    let_it_be(:_) { create(:group, :wiki_repo) }

    context 'when elasticsearch is not enabled for any of the groups' do
      before do
        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      it 'returns a warning message' do
        expected = <<~STD_OUT.chomp
          Advanced search is not enabled for any of the groups.
        STD_OUT

        expect(logger).to receive(:warn).with(expected)

        task
      end
    end

    it 'returns the percentage of groups indexed' do
      create(:group_index_status, group: group)
      expected = <<~STD_OUT.chomp
        Indexing is 50.00% complete (1/2 groups). Considers only group wikis.
      STD_OUT

      expect(logger).to receive(:info).with(expected)

      task
    end
  end

  describe '#index_users' do
    let_it_be(:users) { create_list(:user, 3) }

    subject(:task) { service.execute(:index_users) }

    it 'queues jobs for all users' do
      expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!) do |*args|
        expect(args).to match_array(users)
      end
      expect(logger).to receive(:info).with(/Indexing users/).twice

      task
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_users) }

      create_list(:user, 5)

      expect { service.execute(:index_users) }.to issue_same_number_of_queries_as(control)
    end
  end

  describe '#index_namespaces' do
    let_it_be(:groups) { create_list(:group, 3) }

    subject(:task) { service.execute(:index_namespaces) }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it 'indexes namespaces' do
      expect(ElasticNamespaceIndexerWorker).to receive(:bulk_perform_async_with_contexts)
        .with(match_array(groups), { arguments_proc: kind_of(Proc), context_proc: kind_of(Proc) })

      task
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { task }

      create_list(:group, 3)

      expect { service.execute(:index_namespaces) }.to issue_same_number_of_queries_as(control)
    end
  end

  describe '#index_projects' do
    let_it_be(:projects) { create_list(:project, 3, :in_group) }

    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it 'queues jobs for each project batch' do
      expect(logger).to receive(:info).with(/Enqueuing projects/)
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(*projects)

      service.execute(:index_projects)
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      allow(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!)

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_projects) }

      create(:project, :in_group)
      create(:project_namespace, parent: create(:group))
      create(:project)

      expect { service.execute(:index_projects) }.to issue_same_number_of_queries_as(control)
    end

    context 'with limited indexing enabled' do
      before do
        create :elasticsearch_indexed_project, project: projects.first
        create :elasticsearch_indexed_namespace, namespace: projects.last.namespace

        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      context 'when elasticsearch_indexing is disabled' do
        before do
          stub_ee_application_setting(elasticsearch_indexing: false)
        end

        it 'outputs a warning' do
          expect(logger).to receive(:warn).with(/WARNING: Setting `elasticsearch_indexing` is disabled/)
          expect(logger).to receive(:info).with(/Enqueuing projects/)

          service.execute(:index_projects)
        end
      end

      it 'queues jobs for all projects' do
        expect(logger).to receive(:info).with(/Enqueuing projects/)
        expect(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(*projects)

        service.execute(:index_projects)
      end
    end
  end

  describe '#index_work_items', :elastic do
    let_it_be(:work_item) { create(:work_item) }

    it 'calls track! for work_items' do
      expect(logger).to receive(:info).with(/Indexing work_items/).twice
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!).with(work_item)

      service.execute(:index_work_items)
    end

    it 'avoids N+1 queries', :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_work_items) }

      create_list(:work_item, 3)

      expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!)

      expect { service.execute(:index_work_items) }.to issue_same_number_of_queries_as(control).or_fewer
    end

    context 'with limited indexing enabled' do
      let_it_be(:group1) { create(:group) }
      let_it_be(:group2) { create(:group) }
      let_it_be(:group3) { create(:group) }
      let_it_be(:work_item_1) { create(:work_item, namespace: group1) }
      let_it_be(:_work_item_2) { create(:work_item, namespace: group2) }
      let_it_be(:work_item_3) { create(:work_item, namespace: group3) }

      before do
        create(:elasticsearch_indexed_namespace, namespace: group1)
        create(:elasticsearch_indexed_namespace, namespace: group3)

        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      it 'does not call track! for work_items that should not be indexed' do
        expect(logger).to receive(:info).with(/Indexing work_items/).twice
        expect(Elastic::ProcessBookkeepingService).to receive(:track!) do |*work_items|
          expect(work_items).to match_array([work_item_1, work_item_3])
        end
        service.execute(:index_work_items)
      end
    end

    context 'with group_level_only parameter' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:user) { create(:user) }
      let_it_be(:group_work_item) { create(:work_item, namespace: group, project: nil, author: user) }
      let_it_be(:project_work_item) { create(:work_item, namespace: project.project_namespace, project: project) }

      context 'when group_level_only is false (default)' do
        it 'indexes all work items (both group-level and project-level)' do
          expect(logger).to receive(:info).with(/Indexing work_items/).twice
          received_items = []
          expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!).at_least(:once) do |*work_items|
            received_items.concat(work_items)
          end

          service.execute(:index_work_items)

          expect(received_items).to include(group_work_item, project_work_item)
        end
      end

      context 'when group_level_only is true' do
        it 'indexes only group-level work items', :aggregate_failures do
          expect(logger).to receive(:info).with(/Indexing work_items/).twice
          received_items = []
          expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!).at_least(:once) do |*work_items|
            received_items.concat(work_items)
          end

          service.send(:index_work_items, group_level_only: true)

          expect(received_items).to include(group_work_item)
          expect(received_items).not_to include(project_work_item)
        end
      end
    end
  end

  describe '#projects_not_indexed' do
    let_it_be(:project) { create(:project) }
    let_it_be(:project_no_repository) { create(:project) }
    let_it_be(:project_empty_repository) { create(:project, :empty_repo) }

    subject(:projects_not_indexed) { service.execute(:projects_not_indexed) }

    context 'when projects missing from index' do
      it 'displays non-indexed projects' do
        expect(logger).to receive(:warn)
          .with("Project '#{project.full_path}' (ID: #{project.id}) isn't indexed.")
        expect(logger).to receive(:warn)
          .with("Project '#{project_no_repository.full_path}' (ID: #{project_no_repository.id}) isn't indexed.")
        expect(logger).to receive(:warn)
          .with("Project '#{project_empty_repository.full_path}' (ID: #{project_empty_repository.id}) isn't indexed.")
        expect(logger).to receive(:info).with("3 out of 3 non-indexed projects shown.")

        projects_not_indexed
      end

      context 'when projects missing are more than MAX_RECORDS_TO_DISPLAY' do
        before do
          stub_const("#{described_class}::MAX_RECORDS_TO_DISPLAY", 1)
        end

        it 'displays only MAX_RECORDS_TO_DISPLAY non-indexed projects' do
          expect(logger).to receive(:warn).with(/Project '.*' \(ID: [0-9].*\) isn't indexed/)
          expect(logger).to receive(:info).with("1 out of 3 non-indexed projects shown.")

          projects_not_indexed
        end

        context 'and SHOW_ALL env var is set to true' do
          before do
            stub_env("SHOW_ALL", true)
          end

          it 'displays all non-indexed projects' do
            expect(logger).to receive(:warn)
              .with("Project '#{project.full_path}' (ID: #{project.id}) isn't indexed.")
            expect(logger).to receive(:warn)
              .with("Project '#{project_no_repository.full_path}' (ID: #{project_no_repository.id}) isn't indexed.")
            expect(logger).to receive(:warn)
              .with("Project '#{project_empty_repository.full_path}' " \
                "(ID: #{project_empty_repository.id}) isn't indexed.")
            expect(logger).to receive(:info).with("3 out of 3 non-indexed projects shown.")

            projects_not_indexed
          end
        end
      end
    end

    context 'when all projects are indexed' do
      before do
        [project, project_no_repository, project_empty_repository].each do |p|
          create(:index_status, project: p)
        end
      end

      it 'displays that all projects are indexed' do
        expect(logger).to receive(:info).with(/All project repository data is currently indexed/)

        projects_not_indexed
      end
    end
  end

  describe '#groups_not_indexed' do
    let_it_be(:group) { create(:group, :wiki_repo) }
    let_it_be(:group2) { create(:group, :wiki_repo) }

    subject(:groups_not_indexed) { service.execute(:groups_not_indexed) }

    context 'when groups missing from index' do
      it 'displays non-indexed groups' do
        expect(logger).to receive(:warn).with("Group '#{group.full_path}' (ID: #{group.id}) isn't indexed.")
        expect(logger).to receive(:warn).with("Group '#{group2.full_path}' (ID: #{group2.id}) isn't indexed.")
        expect(logger).to receive(:info).with('2 out of 2 non-indexed groups shown.')

        groups_not_indexed
      end

      context 'when groups missing are more than MAX_RECORDS_TO_DISPLAY' do
        before do
          stub_const("#{described_class}::MAX_RECORDS_TO_DISPLAY", 1)
        end

        it 'displays only MAX_RECORDS_TO_DISPLAY non-indexed groups' do
          expect(logger).to receive(:warn).with(/Group '.*' \(ID: [0-9].*\) isn't indexed/)
          expect(logger).to receive(:info).with('1 out of 2 non-indexed groups shown.')

          groups_not_indexed
        end

        context 'and SHOW_ALL env var is set to true' do
          before do
            stub_env('SHOW_ALL', true)
          end

          it 'displays all non-indexed groups' do
            expect(logger).to receive(:warn).with("Group '#{group.full_path}' (ID: #{group.id}) isn't indexed.")
            expect(logger).to receive(:warn).with("Group '#{group2.full_path}' (ID: #{group2.id}) isn't indexed.")
            expect(logger).to receive(:info).with('2 out of 2 non-indexed groups shown.')

            groups_not_indexed
          end
        end
      end
    end

    context 'when all groups are indexed' do
      before do
        [group, group2].each { |g| create(:group_index_status, group: g) }
      end

      it 'displays that all groups are indexed' do
        expect(logger).to receive(:info).with(/All group repository data is currently indexed/)

        groups_not_indexed
      end
    end
  end

  describe '#index_group_wikis' do
    let(:group1) { create(:group) }
    let(:group2) { create(:group) }
    let(:group3) { create(:group) }
    let(:subgrp) { create(:group, parent: group1) }
    let(:wiki1) { create(:group_wiki, group: group1) }
    let(:wiki2) { create(:group_wiki, group: group2) }
    let(:wiki3) { create(:group_wiki, group: group3) }
    let(:wiki4) { create(:group_wiki, group: subgrp) }

    subject(:index_group_wikis) { service.execute(:index_group_wikis) }

    context 'when on GitLab.com', :saas do
      it 'raises an error' do
        expect { index_group_wikis }.to raise_error('This task cannot be run on GitLab.com')
      end
    end

    context 'with limited indexing disabled' do
      before do
        [wiki1, wiki2, wiki3, wiki4].each do |w|
          w.create_page('index_page', 'Bla bla term')
          w.index_wiki_blobs
        end
      end

      it 'calls ElasticWikiIndexerWorker for groups' do
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group1.id, group1.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group2.id, group2.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group3.id, group3.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(subgrp.id, subgrp.class.name, 'force' => true)

        index_group_wikis
      end
    end

    context 'with limited indexing enabled' do
      before do
        create(:elasticsearch_indexed_namespace, namespace: group1)
        create(:elasticsearch_indexed_namespace, namespace: group3)

        stub_ee_application_setting(elasticsearch_limit_indexing: true)

        [wiki1, wiki2, wiki3, wiki4].each do |w|
          w.create_page('index_page', 'Bla bla term')
          w.index_wiki_blobs
        end
      end

      it 'calls ElasticWikiIndexerWorker for groups which has elasticsearch enabled' do
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group1.id, group1.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(group3.id, group3.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(subgrp.id, subgrp.class.name, 'force' => true)
        expect(ElasticWikiIndexerWorker).not_to receive(:perform_async)
          .with group2.id, group2.class.name, 'force' => true

        index_group_wikis
      end
    end
  end

  describe '#index_group_entities' do
    subject(:index_group_entities) { service.execute(:index_group_entities) }

    context 'when on GitLab.com', :saas do
      it 'raises an error' do
        expect { index_group_entities }.to raise_error('This task cannot be run on GitLab.com')
      end
    end

    it 'calls other tasks in order' do
      expect(service).to receive(:index_work_items).with(group_level_only: true).ordered
      expect(service).to receive(:index_group_wikis).ordered

      index_group_entities
    end
  end

  describe '#index_vulnerabilities' do
    let_it_be(:vulnerability_read) { create(:vulnerability_read) }

    context 'when elasticsearch indexing is not allowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexHelper)
          .to receive(:indexing_allowed?).and_return(false)
      end

      it 'skips indexing and logs warning' do
        expect(logger).to receive(:info).with('Indexing vulnerabilities...')
        expect(logger).to receive(:info).with(/Skipping vulnerability indexing/)
        expect(::Vulnerabilities::Read).not_to receive(:all)

        service.execute(:index_vulnerabilities)
      end
    end

    shared_examples 'it performs indexing' do
      it 'calls track! for vulnerabilities' do
        expect(logger).to receive(:info).with(/Indexing vulnerabilities/).twice
        expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!).with(vulnerability_read)

        service.execute(:index_vulnerabilities)
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { service.execute(:index_vulnerabilities) }

        create_list(:vulnerability_read, 3)

        expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!)

        expect { service.execute(:index_vulnerabilities) }.to issue_same_number_of_queries_as(control).or_fewer
      end
    end

    context 'when elasticsearch indexing is allowed' do
      before do
        allow(::Search::Elastic::VulnerabilityIndexHelper)
          .to receive(:indexing_allowed?).and_return(true)
      end

      it_behaves_like 'it performs indexing'
    end
  end

  describe '#index_sbom_occurrence_refs' do
    let_it_be(:occurrence_ref) { create(:sbom_occurrence_ref) }

    context 'when elasticsearch indexing is not allowed' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'skips indexing and logs a message' do
        expect(logger).to receive(:info).with('Indexing SBOM occurrence refs...')
        expect(logger).to receive(:info).with(/Skipping SBOM occurrence ref indexing/)
        expect(::Sbom::OccurrenceRef).not_to receive(:each_batch)

        service.execute(:index_sbom_occurrence_refs)
      end
    end

    context 'when elasticsearch indexing is allowed' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
        set_elasticsearch_migration_to(:create_sbom_occurrence_refs_index, including: true)
      end

      it 'tracks the refs with the initial bookkeeping service' do
        expect(logger).to receive(:info).with(/Indexing SBOM occurrence refs/).twice
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!)
        expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!) do |*args|
          expect(args).to contain_exactly(occurrence_ref)
        end

        service.execute(:index_sbom_occurrence_refs)
      end

      context 'when limited indexing is enabled and the project is not indexed' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        it 'does not track the refs' do
          expect(::Elastic::ProcessInitialBookkeepingService).to receive(:track!) do |*args|
            expect(args).to be_empty
          end

          service.execute(:index_sbom_occurrence_refs)
        end
      end

      it 'avoids N+1 queries', :use_sql_query_cache do
        allow(::Elastic::ProcessInitialBookkeepingService).to receive(:track!)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          service.execute(:index_sbom_occurrence_refs)
        end

        create_list(:sbom_occurrence_ref, 3)

        expect { service.execute(:index_sbom_occurrence_refs) }
          .to issue_same_number_of_queries_as(control).or_fewer
      end
    end
  end

  describe '#clear_index_status' do
    it 'deletes all records for Elastic::GroupIndexStatus and IndexStatus tables' do
      expect(Elastic::GroupIndexStatus).to receive(:delete_all)
      expect(IndexStatus).to receive(:delete_all)

      expect(logger).to receive(:info).with(/Index status has been reset/)

      service.execute(:clear_index_status)
    end
  end

  describe '#info', :elastic do
    let(:helper) { es_helper }
    let(:settings) { ::Gitlab::CurrentSettings }

    subject(:info) { service.execute(:info) }

    before do
      settings.update!(elasticsearch_search: true, elasticsearch_indexing: true)

      allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
      allow(helper).to receive_messages(ping?: true, get_meta: { 'created_by' => '123' })
    end

    it 'outputs GitLab version' do
      expect(logger).to receive(:info).with(/GitLab version:\s+\d+\.\d+\.\d+/)

      info
    end

    it 'outputs server version' do
      expect(logger).to receive(:info).with(/Server version:\s+\d+.\d+.\d+/)

      info
    end

    it 'outputs server distribution' do
      expect(logger).to receive(:info).with(/Server distribution:\s+\w+/)

      info
    end

    context 'for yes/no settings' do
      it 'outputs Indexing enabled as yes when indexing is enabled' do
        allow(settings).to receive(:elasticsearch_indexing?).and_return(true)

        expect(logger).to receive(:info).with(/Indexing enabled:\s+yes/)

        info
      end

      it 'outputs Indexing enabled as no when indexing is disabled' do
        expect(logger).to receive(:info).with(/Indexing enabled:\s+no/)
        allow(settings).to receive(:elasticsearch_indexing?).and_return(false)

        info
      end

      it 'outputs Search enabled as yes when search is enabled' do
        allow(settings).to receive(:elasticsearch_search?).and_return(true)

        expect(logger).to receive(:info).with(/Search enabled:\s+yes/)

        info
      end

      it 'outputs Search enabled as no when search is disabled' do
        allow(settings).to receive(:elasticsearch_search?).and_return(false)

        expect(logger).to receive(:info).with(/Search enabled:\s+no/)

        info
      end

      it 'outputs Code search enabled as yes when code search is enabled' do
        allow(settings).to receive(:elasticsearch_code_scope?).and_return(true)

        expect(logger).to receive(:info).with(/Code search enabled:\s+yes/)

        info
      end

      it 'outputs Code search enabled as no when code search is disabled' do
        allow(settings).to receive(:elasticsearch_code_scope?).and_return(false)

        expect(logger).to receive(:info).with(/Code search enabled:\s+no/)

        info
      end

      it 'outputs Requeue Indexing workers as yes when requeue workers is enabled' do
        allow(settings).to receive(:elasticsearch_requeue_workers?).and_return(true)

        expect(logger).to receive(:info).with(/Requeue Indexing workers:\s+yes/)

        info
      end

      it 'outputs Requeue Indexing workers as no when requeue workers is disabled' do
        allow(settings).to receive(:elasticsearch_requeue_workers?).and_return(false)

        expect(logger).to receive(:info).with(/Requeue Indexing workers:\s+no/)

        info
      end

      it 'outputs Pause advanced search indexing as yes when advanced search indexing is paused' do
        allow(settings).to receive(:advanced_search_indexing_paused?).and_return(true)

        expect(logger).to receive(:info).with(/Pause advanced search indexing:\s+yes/)

        info
      end

      it 'outputs Pause advanced search indexing as no when advanced search indexing is not paused' do
        allow(settings).to receive(:advanced_search_indexing_paused?).and_return(false)

        expect(logger).to receive(:info).with(/Pause advanced search indexing:\s+no/)

        info
      end

      it 'outputs Pause search cluster indexing as yes when cluster pause indexing is enabled' do
        allow(settings).to receive(:elasticsearch_pause_indexing?).and_return(true)

        expect(logger).to receive(:info).with(/Pause search cluster indexing:\s+yes/)

        info
      end

      it 'outputs Pause search cluster indexing as no when cluster pause indexing is disabled' do
        allow(settings).to receive(:elasticsearch_pause_indexing?).and_return(false)

        expect(logger).to receive(:info).with(/Pause search cluster indexing:\s+no/)

        info
      end

      it 'outputs Indexing restrictions enabled as yes when limit indexing is enabled' do
        allow(settings).to receive(:elasticsearch_limit_indexing?).and_return(true)

        expect(logger).to receive(:info).with(/Indexing restrictions enabled:\s+yes/)

        info
      end

      it 'outputs Indexing restrictions enabled as no when limit indexing is disabled' do
        allow(settings).to receive(:elasticsearch_limit_indexing?).and_return(false)

        expect(logger).to receive(:info).with(/Indexing restrictions enabled:\s+no/)

        info
      end
    end

    it 'outputs indexing and search settings' do
      expected_regex = [
        /File size limit:\s+#{settings.elasticsearch_indexed_file_size_limit_kb} KiB/,
        /Index version:\s+\d+/,
        /Indexing number of shards:\s+\d+/,
        /Max code indexing concurrency:\s+#{settings.elasticsearch_max_code_indexing_concurrency}/,
        /Prefix:\s+#{settings.elasticsearch_prefix}/,
        /Client adapter:\s+#{settings.elasticsearch_client_adapter}/
      ]

      expected_regex.each do |expected|
        expect(logger).to receive(:info).with(expected)
      end

      info
    end

    it 'outputs prefix' do
      expect(logger).to receive(:info).with(/Prefix:\s+gitlab/)

      info
    end

    it 'outputs client adapter' do
      expect(logger).to receive(:info).with(/Client adapter:\s+typhoeus/)

      info
    end

    it 'outputs file size limit' do
      expect(logger).to receive(:info).with(/File size limit:\s+\d+ KiB/)

      info
    end

    it 'outputs index version' do
      expect(logger).to receive(:info).with(/Index version:\s+\d+/)

      info
    end

    it 'outputs indexing number of shards' do
      expect(logger).to receive(:info).with(/Indexing number of shards:\s+\d+/)

      info
    end

    it 'outputs max code indexing concurrency' do
      expect(logger).to receive(:info).with(/Max code indexing concurrency:\s+\d+/)

      info
    end

    it 'outputs queue sizes' do
      allow(Elastic::ProcessInitialBookkeepingService).to receive(:queue_size).and_return(100)
      allow(Elastic::ProcessBookkeepingService).to receive(:queue_size).and_return(200)
      allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
        .with('Search::Elastic::CommitIndexerWorker')
        .and_return(75)

      expect(logger).to receive(:info).with(/Initial queue:\s+100/)
      expect(logger).to receive(:info).with(/Incremental queue:\s+200/)
      expect(logger).to receive(:info).with(/Concurrency limit code queue:\s+75/)

      info
    end

    describe 'pending migration status' do
      it 'outputs pending migrations' do
        pending_migration = ::Elastic::DataMigrationService.migrations.last
        obsolete_migration = ::Elastic::DataMigrationService.migrations.first
        allow(pending_migration).to receive(:completed?).and_return(false)
        allow(obsolete_migration).to receive_messages(completed?: false, obsolete?: true)
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations)
          .and_return([pending_migration, obsolete_migration])

        expect(logger).to receive(:info).with(/Pending Migrations/)
        expect(logger).to receive(:info).with(/#{pending_migration.name}/)
        expect(logger).to receive(:warn).with(/#{obsolete_migration.name} \[Obsolete\]/)

        info
      end

      context 'when search service is unreachable' do
        before do
          allow(helper).to receive(:ping?).and_return(false)
        end

        it 'outputs an error' do
          expect(logger).to receive(:info).with(/Pending Migrations/)
          expect(logger).to receive(:error).with(/Unable to connect to search cluster to retrieve data/)

          info
        end
      end
    end

    describe 'current migration status' do
      it 'outputs current migration' do
        migration = ::Elastic::DataMigrationService.migrations.last
        allow(migration).to receive_messages(started?: true, load_state: { test: 'value' })
        allow(Elastic::MigrationRecord).to receive(:current_migration).and_return(migration)

        expected_regex = [
          /Name:\s+#{migration.name}/,
          /Started:\s+yes/,
          /Halted:\s+no/,
          /Failed:\s+no/,
          /Obsolete:\s+no/,
          /Current state:\s+{"test":"value"}/
        ]

        # avoid printing pending migrations
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])

        expected_regex.each do |expected|
          expect(logger).to receive(:info).with(expected)
        end

        info
      end

      context 'when there is no current migration' do
        it 'outputs a message stating no current migration' do
          expect(logger).to receive(:info).with(/Current Migration/)
          expect(logger).to receive(:info).with(/There is no current migration/)

          info
        end
      end

      context 'when search service is unreachable' do
        before do
          allow(helper).to receive(:ping?).and_return(false)
        end

        it 'outputs an error' do
          expect(logger).to receive(:info).with(/Current Migration/)
          expect(logger).to receive(:error).with(/Unable to connect to search cluster to retrieve data/)

          info
        end
      end
    end

    describe 'current reindexing tasks status' do
      it 'outputs current reindexing task' do
        task = create(:elastic_reindexing_task, targets: [Project, Issue])

        expect(logger).to receive(:info).with(/Current Zero-downtime Reindexing Tasks/)
        expect(logger).to receive(:info)
          .with(/Reindexing task started at: #{task.created_at} with targets: \[Project, Issue\]/)

        info
      end

      context 'when there is no current reindexing task' do
        it 'outputs a message stating no current reindexing task' do
          expect(logger).to receive(:info).with(/Current Zero-downtime Reindexing Tasks/)
          expect(logger).to receive(:info).with(/There is no current reindexing task/)

          info
        end
      end

      context 'when an error occurs while retrieving reindexing task data' do
        before do
          allow(::Search::Elastic::ReindexingTask).to receive(:current).and_raise(StandardError.new('Database error'))
        end

        it 'outputs an error' do
          expect(logger).to receive(:info).with(/Current Zero-downtime Reindexing Tasks/)
          expect(logger).to receive(:error)
            .with(/An exception occurred during the retrieval of the data: StandardError: Database error/)

          info
        end
      end
    end

    describe 'index settings' do
      let(:helper) { es_helper }
      let(:setting) do
        ::Elastic::IndexSetting.new(number_of_replicas: 1, number_of_shards: 8, alias_name: 'gitlab-test')
      end

      before do
        allow(::Search::Elastic::Helper).to receive(:default).and_return(helper)
        allow(::Elastic::IndexSetting).to receive(:every_alias).and_return([setting])
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])
        allow(helper).to receive(:migrations_index_name).and_return(helper.migrations_index_name)
      end

      it 'outputs failed index setting' do
        allow(helper.client).to receive(:indices).and_raise(Timeout::Error)

        expect(logger).to receive(:error).with(/failed to load indices for gitlab-test/)

        info
      end

      it 'outputs index settings' do
        allow(helper).to receive(:documents_count).and_return(1000)

        indices = instance_double(Elasticsearch::API::Indices::IndicesClient)
        allow(helper.client).to receive(:indices).and_return(indices)
        allow(indices).to receive(:stats).with(index: setting.alias_name).and_return({
          "indices" => {
            "index" => {
              "primaries" => {
                "docs" => {
                  "count" => 1000
                }
              }
            }
          }
        })
        allow(indices).to receive(:get_settings).with(index: setting.alias_name).and_return({
          setting.alias_name => {
            "settings" => {
              "index" => {
                "number_of_shards" => 5,
                "number_of_replicas" => 1,
                "refresh_interval" => '2s',
                "blocks" => {
                  "write" => 'true'
                }
              }
            }
          }
        })

        expected_regex = [/#{setting.alias_name}:/,
          /document_count: 1000/,
          /number_of_shards: 5/,
          /number_of_replicas: 1/,
          /refresh_interval: 2s/]

        expected_regex.each do |expected|
          expect(logger).to receive(:info).with(expected)
        end
        expect(logger).to receive(:error).with(/blocks.write: yes/)

        info
      end

      context 'when an index has a pending create-index migration' do
        before do
          allow(::Elastic::DataMigrationService).to receive(:pending_create_index_target_classes)
            .and_return(Set[::Vulnerabilities::Read])
          allow(helper).to receive(:klass_to_alias_name)
            .with(klass: ::Vulnerabilities::Read)
            .and_return(setting.alias_name)
        end

        it 'logs an informational yellow message and skips index settings retrieval' do
          expect(logger).to receive(:info).with(/index not yet created \(pending migration\)/)
          expect(helper.client).not_to receive(:indices)

          info
        end
      end
    end

    context 'when the search client throws an error' do
      it 'logs an error message and does not raise an error' do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_raise(StandardError)

        expect(logger).to receive(:error).with(/An exception occurred during the retrieval of the data/).at_least(:once)
        expect { info }.not_to raise_error
      end
    end
  end

  describe '#disable_search_with_elasticsearch' do
    let(:settings) { ::Gitlab::CurrentSettings }

    subject(:disable_search_with_elasticsearch) { service.execute(:disable_search_with_elasticsearch) }

    context 'when elasticsearch_search is enabled' do
      it 'disables `elasticsearch_search`' do
        settings.update!(elasticsearch_search: true)

        expect { disable_search_with_elasticsearch }
          .to change { Gitlab::CurrentSettings.elasticsearch_search? }.from(true).to(false)
      end
    end

    context 'when elasticsearch_search is not enabled' do
      it 'does nothing' do
        settings.update!(elasticsearch_search: false)

        expect { disable_search_with_elasticsearch }.not_to change { Gitlab::CurrentSettings.elasticsearch_search? }
      end
    end
  end

  describe '#reindex_cluster' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    subject(:reindex_cluster) { service.execute(:reindex_cluster) }

    it 'creates a reindexing task and queues the cron worker' do
      expect(::Search::Elastic::ReindexingTask).to receive(:create!)
      expect(::Search::Elastic::ClusterReindexingCronWorker).to receive(:perform_async)

      expect(logger).to receive(:info).with(/Reindexing job was successfully scheduled/)

      reindex_cluster
    end

    context 'when elasticsearch_indexing is false' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'does nothing and logs an warning' do
        expect(::Search::Elastic::ClusterReindexingCronWorker).not_to receive(:perform_async)

        expect(logger).to receive(:warn).with(/Setting `elasticsearch_indexing` is disabled/)

        reindex_cluster
      end
    end

    context 'when a reindexing task is in progress' do
      it 'logs an error' do
        ::Search::Elastic::ReindexingTask.create!

        expect(::Search::Elastic::ClusterReindexingCronWorker).not_to receive(:perform_async)

        expect(logger).to receive(:error).with(/There is another task in progress. Please wait for it to finish/)

        reindex_cluster
      end
    end
  end

  describe '#recreate_index' do
    subject(:recreate_index) { service.execute(:recreate_index) }

    it 'calls delete_index and create_empty_index' do
      expect(service).to receive(:delete_index).ordered
      expect(service).to receive(:create_empty_index).ordered

      recreate_index
    end
  end

  describe '#clear_reindex_status' do
    subject(:clear_reindex_status) { service.execute(:clear_reindex_status) }

    it 'calls deletes all reindex records' do
      create(:elastic_reindexing_task)

      expect { clear_reindex_status }.to change { ::Search::Elastic::ReindexingTask.count }.from(1).to(0)
    end
  end

  describe '#clear_tracking_queues' do
    subject(:clear_tracking_queues) { service.execute(:clear_tracking_queues) }

    it 'clears all tracking queues' do
      expect(::Elastic::ProcessBookkeepingService).to receive(:clear_tracking!)
      expect(::Elastic::ProcessInitialBookkeepingService).to receive(:clear_tracking!)
      expect(logger).to receive(:info).with(/All indexing queues have been cleared/)

      clear_tracking_queues
    end
  end

  describe '#index_and_search_validation' do
    subject(:index_and_search_validation) { service.execute(:index_and_search_validation) }

    before do
      allow(::Search::ClusterHealthCheck::IndexValidationService).to receive(:execute).and_return(validation_result)
    end

    context 'when validation succeeds' do
      let(:validation_result) { true }

      it 'logs success message' do
        expect(logger).to receive(:info).with(/Running index and search validation/)
        expect(logger).to receive(:info).with(/Index and search validation completed successfully/)

        index_and_search_validation
      end

      it 'calls the IndexValidationService with logger parameter' do
        expect(::Search::ClusterHealthCheck::IndexValidationService).to receive(:execute).with(logger: logger)

        index_and_search_validation
      end
    end

    context 'when validation fails' do
      let(:validation_result) { false }

      it 'logs error message' do
        expect(logger).to receive(:info).with(/Running index and search validation/)
        expect(logger).to receive(:error).with(/Index and search validation failed/)

        index_and_search_validation
      end

      it 'calls the IndexValidationService with logger parameter' do
        allow(logger).to receive(:error)
        expect(::Search::ClusterHealthCheck::IndexValidationService).to receive(:execute).with(logger: logger)

        index_and_search_validation
      end
    end
  end

  def get_class_proxy(class_name:, use_separate_indices:)
    type_class(class_name) || ::Elastic::Latest::ApplicationClassProxy.new(class_name,
      use_separate_indices: use_separate_indices)
  end

  def type_class(class_name)
    [::Search::Elastic::Types, class_name].join('::').safe_constantize
  end
end
