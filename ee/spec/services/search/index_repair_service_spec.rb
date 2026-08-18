# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::IndexRepairService, feature_category: :global_search do
  let_it_be_with_reload(:project) { create(:project, :small_repo, :wiki_repo_with_page) }

  describe '.execute' do
    it 'creates a new instance and calls execute' do
      expect_next_instance_of(described_class, project: project, params: { force_repair_blobs: true }) do |instance|
        expect(instance).to receive(:execute)
      end
      described_class.execute(project, params: { force_repair_blobs: true })
    end
  end

  describe '#execute' do
    let(:logger) { instance_double(::Gitlab::Elasticsearch::Logger) }
    let(:client) { instance_double(::Gitlab::Search::Client) }
    let(:index_repair_counter) { instance_double(Prometheus::Client::Counter) }

    subject(:service) { described_class.new(project: project) }

    before do
      allow(::Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger)
      allow(::Gitlab::Search::Client).to receive(:new).and_return(client)
      allow(Gitlab::Metrics).to receive(:counter).and_call_original
      allow(Gitlab::Metrics).to receive(:counter).with(
        :search_advanced_index_repair_total,
        'Count of search index repair operations.'
      ).and_return(index_repair_counter)
      allow(project).to receive_messages(should_check_index_integrity?: true)
    end

    context 'when index_status is present' do
      before_all do
        create(:index_status, project: project)
      end

      context 'when index integrity check is not allowed on project' do
        before do
          allow(project).to receive(:should_check_index_integrity?).and_return(false)
          stub_projects_count(0)
          stub_commits_count(0)
          stub_blobs_count(0)
          stub_wikis_count(0)
        end

        it 'does not call CommitIndexerWorker or ElasticWikiIndexerWorker or Elastic::ProcessBookkeepingService' do
          expect(::Search::Elastic::CommitIndexerWorker).not_to receive(:perform_in)
          expect(ElasticWikiIndexerWorker).not_to receive(:perform_in)
          expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)
          expect(logger).not_to receive(:warn)
          expect(index_repair_counter).not_to receive(:increment)
          service.execute
        end
      end

      context 'when index integrity check is allowed on project' do
        include EE::GeoHelpers

        context 'when project is missing from the index' do
          before do
            stub_projects_count(0)
            stub_commits_count(1)
            stub_blobs_count(1)
            stub_wikis_count(1)
          end

          context 'for primary node' do
            before do
              stub_primary_node
            end

            it 'logs warning, increment the repair counter and calls Elastic::ProcessBookkeepingService' do
              expect(logger).to receive(:warn).with(
                {
                  message: 'project document missing from index',
                  class: described_class.to_s,
                  namespace_id: project.namespace_id,
                  root_namespace_id: project.root_namespace.id,
                  project_id: project.id
                }.stringify_keys
              )
              expect(index_repair_counter).to receive(:increment).with({ document_type: Project.es_type })
              expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(project)

              service.execute
            end
          end

          context 'for secondary node' do
            before do
              stub_secondary_node
            end

            it 'does not call Elastic::ProcessBookkeepingService' do
              expect(logger).not_to receive(:warn)
              expect(index_repair_counter).not_to receive(:increment)
              expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)

              service.execute
            end
          end

          context 'for org migration target node' do
            before do
              node = stub_org_migration_target_cell
              node.update!(selective_sync_type: 'organizations')
              node.organizations << project.organization
            end

            it 'does not call Elastic::ProcessBookkeepingService' do
              expect(logger).not_to receive(:warn)
              expect(index_repair_counter).not_to receive(:increment)
              expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)

              service.execute
            end
          end
        end

        context 'when project last commit is received as blank from Gitaly and repo documents are missing from index' do
          before do
            stub_projects_count(1)
            stub_commits_count(0)
            stub_blobs_count(0)
            stub_wikis_count(1)
            allow(project).to receive(:commit).with(project.repository.root_ref)
          end

          it 'does not call CommitIndexerWorker' do
            expect(logger).not_to receive(:warn)
            expect(index_repair_counter).not_to receive(:increment)
            expect(::Search::Elastic::CommitIndexerWorker).not_to receive(:perform_in)

            service.execute
          end
        end

        context 'when project last wiki commit is received as blank from Gitaly and wikis are missing from index' do
          before do
            stub_projects_count(1)
            stub_commits_count(1)
            stub_blobs_count(1)
            stub_wikis_count(0)
            allow(project).to receive_message_chain(:wiki, :repository, :root_ref)
            allow(project).to receive_message_chain(:wiki, :repository, :commit)
          end

          it 'does not call ElasticWikiIndexerWorker' do
            expect(logger).not_to receive(:warn)
            expect(index_repair_counter).not_to receive(:increment)
            expect(ElasticWikiIndexerWorker).not_to receive(:perform_in)

            service.execute
          end
        end

        context 'when last_commit from index_status does not match with project last commit from Gitaly' do
          before do
            stub_projects_count(1)
            stub_commits_count(1)
            stub_blobs_count(1)
            stub_wikis_count(1)
            allow(project).to receive_message_chain(:commit, :sha).and_return('new_commit_sha')
          end

          it 'calls Search::Elastic::CommitIndexerWorker' do
            expect(index_repair_counter).to receive(:increment).with({ document_type: Repository.es_type })
            expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_in).with(
              anything,
              project.id,
              { 'force' => true }
            )

            service.execute
          end
        end

        context 'when last_wiki_commit from index_status does not match with project last wiki commit from Gitaly' do
          before do
            stub_projects_count(1)
            stub_commits_count(1)
            stub_blobs_count(1)
            stub_wikis_count(1)
            allow(project).to receive_message_chain(:wiki, :repository, :root_ref)
            allow(project).to receive_message_chain(:wiki, :repository, :commit, :sha).and_return('new_commit_sha')
          end

          it 'calls ElasticWikiIndexerWorker' do
            expect(index_repair_counter).to receive(:increment).with({ document_type: Wiki.es_type })
            expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(
              anything,
              project.id,
              project.class.name,
              { 'force' => true }
            )

            service.execute
          end
        end

        context 'when commits is completely missing' do
          before do
            stub_projects_count(1)
            stub_commits_count(0)
            stub_blobs_count(1)
            stub_wikis_count(1)
          end

          it 'calls Search::Elastic::CommitIndexerWorker' do
            expect(index_repair_counter).to receive(:increment).with({ document_type: Repository.es_type })
            expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_in).with(
              anything,
              project.id,
              { 'force' => true }
            )

            service.execute
          end
        end

        context 'when wikis is completely missing' do
          before do
            stub_projects_count(1)
            stub_commits_count(1)
            stub_blobs_count(1)
            stub_wikis_count(0)
          end

          it 'calls ElasticWikiIndexerWorker' do
            expect(index_repair_counter).to receive(:increment).with({ document_type: Wiki.es_type })
            expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(
              anything,
              project.id,
              project.class.name,
              { 'force' => true }
            )

            service.execute
          end
        end

        context 'when blobs is completely missing' do
          before do
            stub_projects_count(1)
            stub_commits_count(1)
            stub_blobs_count(0)
            stub_wikis_count(1)
          end

          context 'when setting elasticsearch_code_scope is enabled' do
            before do
              stub_ee_application_setting(elasticsearch_code_scope: true)
            end

            it 'calls Search::Elastic::CommitIndexerWorker' do
              expect(logger).to receive(:warn).with(
                {
                  message: 'blob documents missing from index for project',
                  class: described_class.to_s,
                  namespace_id: project.namespace_id,
                  root_namespace_id: project.root_namespace.id,
                  project_id: project.id,
                  project_last_repository_updated_at: project.last_repository_updated_at,
                  index_status_last_commit: project.index_status&.last_commit,
                  index_status_indexed_at: project.index_status&.indexed_at,
                  repository_size: project.statistics&.repository_size
                }.stringify_keys
              )
              expect(index_repair_counter).to receive(:increment).with({ document_type: Repository.es_type })
              expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_in).with(
                anything,
                project.id,
                { 'force' => true }
              )

              service.execute
            end
          end

          context 'when setting elasticsearch_code_scope is disabled' do
            before do
              stub_ee_application_setting(elasticsearch_code_scope: false)
            end

            it 'does not calls Search::Elastic::CommitIndexerWorker' do
              expect(logger).not_to receive(:warn)
              expect(index_repair_counter).not_to receive(:increment)
              expect(Search::Elastic::CommitIndexerWorker).not_to receive(:perform_in)

              service.execute
            end
          end
        end

        context 'when force_repair_blobs is sent as true' do
          subject(:service) { described_class.new(project: project, params: { force_repair_blobs: true }) }

          before do
            stub_projects_count(1)
            stub_commits_count(1)
            stub_blobs_count(1)
            stub_wikis_count(1)
          end

          it 'calls Search::Elastic::CommitIndexerWorker' do
            expect(index_repair_counter).to receive(:increment).with({ document_type: Repository.es_type })
            expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_in).with(
              anything,
              project.id,
              { 'force' => true }
            )

            service.execute
          end
        end

        context 'when projects, commits, blobs and wikis all are missing' do
          before do
            stub_projects_count(0)
            stub_commits_count(0)
            stub_blobs_count(0)
            stub_wikis_count(0)
          end

          RSpec.shared_examples 'logs warning, increments counters and index everything' do
            it 'logs project document missing, increments counter and index everything' do
              expect(logger).to receive(:warn).with(
                {
                  message: 'project document missing from index',
                  class: described_class.to_s,
                  namespace_id: project.namespace_id,
                  root_namespace_id: project.root_namespace.id,
                  project_id: project.id
                }.stringify_keys
              )
              expect(index_repair_counter).to receive(:increment).with({ document_type: Project.es_type })
              expect(Elastic::ProcessBookkeepingService).to receive(:track!).with(project)
              expect(index_repair_counter).to receive(:increment).with({ document_type: Repository.es_type })
              expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_in).with(
                anything,
                project.id,
                { 'force' => true }
              )
              expect(index_repair_counter).to receive(:increment).with({ document_type: Wiki.es_type })
              expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(
                anything,
                project.id,
                project.class.name,
                { 'force' => true }
              )

              service.execute
            end
          end

          it_behaves_like 'logs warning, increments counters and index everything'

          context 'when application setting elasticsearch_code_scope is disabled' do
            before do
              stub_ee_application_setting(elasticsearch_code_scope: true)
            end

            it_behaves_like 'logs warning, increments counters and index everything'
          end
        end
      end
    end

    context 'when index_status is not present' do
      before do
        allow(project).to receive(:should_check_index_integrity?).and_return(true)
        stub_projects_count(1)
        stub_commits_count(1)
        stub_blobs_count(1)
        stub_wikis_count(1)
      end

      it 'calls for repository indexing' do
        expect(index_repair_counter).to receive(:increment).with({ document_type: Repository.es_type })
        expect(::Search::Elastic::CommitIndexerWorker).to receive(:perform_in)
        expect(index_repair_counter).to receive(:increment).with({ document_type: Wiki.es_type })
        expect(ElasticWikiIndexerWorker).to receive(:perform_in)
        expect(Elastic::ProcessBookkeepingService).not_to receive(:track!)

        service.execute
      end
    end

    def stub_blobs_count(count)
      allow(client).to receive(:count).with(
        index: Repository.index_name,
        routing: project.es_id,
        body: { query: { bool: { filter: [{ term: { type: 'blob' } }, { term: { project_id: project.id } }] } } }
      ).and_return({ 'count' => count })
    end

    def stub_commits_count(count)
      allow(client).to receive(:count).with(
        index: ::Elastic::Latest::CommitConfig.index_name,
        routing: project.es_id,
        body: { query: { bool: { filter: [{ term: { type: 'commit' } }, { term: { rid: project.id.to_s } }] } } }
      ).and_return({ 'count' => count })
    end

    def stub_projects_count(count)
      allow(client).to receive(:count).with(
        index: Project.index_name,
        routing: project.es_parent,
        body: { query: { bool: { filter: [{ term: { type: 'project' } }, { term: { id: project.id } }] } } }
      ).and_return({ 'count' => count })
    end

    def stub_wikis_count(count)
      allow(client).to receive(:count).with(
        index: Wiki.index_name,
        routing: "n_#{project.root_ancestor.id}",
        body: { query: { bool: { filter: [{ term: { type: 'wiki_blob' } }, { term: { project_id: project.id } }] } } }
      ).and_return({ 'count' => count })
    end
  end
end
