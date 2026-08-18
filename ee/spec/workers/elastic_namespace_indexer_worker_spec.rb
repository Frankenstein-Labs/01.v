# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticNamespaceIndexerWorker, feature_category: :global_search do
  subject(:worker) { described_class.new }

  context 'when ES is disabled' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: false)
      stub_ee_application_setting(elasticsearch_limit_indexing: false)
    end

    it 'returns true' do
      expect(Elastic::ProcessInitialBookkeepingService).not_to receive(:backfill_projects!)
      expect(ElasticWikiIndexerWorker).not_to receive(:perform_async)
      expect(Elastic::ProcessBookkeepingService).not_to receive(:maintain_indexed_namespace_associations!)

      expect(worker.perform(1, 'index')).to be_truthy
    end
  end

  context 'when ES is enabled' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
      stub_ee_application_setting(elasticsearch_limit_indexing: true)
    end

    describe 'indexing and deleting', :elastic_helpers do
      let_it_be(:namespace) { create(:namespace) }
      let_it_be(:projects) { create_list(:project, 3, namespace: namespace) }

      context 'for :index' do
        it_behaves_like 'an idempotent worker' do
          let(:job_args) { [namespace.id, :index] }

          it 'indexes all projects belonging to the namespace' do
            expect(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(*projects)

            worker.perform(*job_args)
          end

          it 'calls maintain_indexed_namespace_associations! for non-group namespaces for work_items' do
            expect(Elastic::ProcessBookkeepingService).to receive(:maintain_indexed_namespace_associations!)

            worker.perform(*job_args)
          end
        end
      end

      context 'for :delete' do
        it_behaves_like 'an idempotent worker' do
          let(:job_args) { [namespace.id, :delete] }

          before do
            # avoid calls to Elasticsearch cluster
            allow(ElasticDeleteProjectWorker).to receive(:bulk_perform_async)
          end

          it 'deletes all projects belonging to the namespace' do
            args = projects.map { |project| [project.id, project.es_id, { delete_project: false }] }
            expect(ElasticDeleteProjectWorker).to receive(:bulk_perform_async).with(args)

            worker.perform(*job_args)
          end

          it 'does not enqueue Search::ElasticGroupAssociationDeletionWorker' do
            expect(Search::ElasticGroupAssociationDeletionWorker).not_to receive(:perform_async)

            worker.perform(*job_args)
          end
        end
      end

      context 'when namespace is group with hierarchy' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:sub_group) { create(:group, parent: parent_group) }
        let_it_be(:sub_child_group) { create(:group, parent: sub_group) }
        let_it_be(:another_group) { create(:group) }

        context 'for :index' do
          it_behaves_like 'an idempotent worker' do
            let(:job_args) { [parent_group.id, :index] }

            before do
              # avoid calls to Elasticsearch cluster
              allow(Elastic::ProcessBookkeepingService).to receive(:maintain_indexed_namespace_associations!)
              allow(ElasticWikiIndexerWorker).to receive(:perform_in)
            end

            it 'indexes all group wikis belonging to the namespace' do
              [parent_group, sub_group, sub_child_group].each do |group|
                expect(ElasticWikiIndexerWorker).to receive(:perform_in).with(
                  elastic_wiki_indexer_worker_random_delay_range, group.id, group.class.name, { 'force' => true })
              end

              worker.perform(*job_args)
            end

            it 'calls Elastic::ProcessBookkeepingService.maintain_indexed_namespace_associations!' do
              expect(Elastic::ProcessBookkeepingService).to receive(
                :maintain_indexed_namespace_associations!) do |*groups|
                expect(groups).to match_array([parent_group, sub_group, sub_child_group])
              end

              worker.perform(*job_args)
            end
          end
        end

        context 'for :delete' do
          it_behaves_like 'an idempotent worker' do
            let(:job_args) { [parent_group.id, :delete] }

            before do
              # avoid calls to Elasticsearch cluster
              allow(ElasticDeleteProjectWorker).to receive(:bulk_perform_async)
              allow(Search::Wiki::ElasticDeleteGroupWikiWorker).to receive(:perform_in)
              allow(Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_in)
            end

            it 'deletes all group wikis belonging to the namespace' do
              [parent_group, sub_group, sub_child_group].each do |group|
                expect(Search::Wiki::ElasticDeleteGroupWikiWorker).to receive(:perform_in).with(
                  elastic_delete_group_wiki_worker_random_delay_range,
                  group.id,
                  'namespace_routing_id' => parent_group.id
                )
              end

              worker.perform(*job_args)
            end

            it 'enqueues GroupAssociationDeletionWorker for a root group and its descendents' do
              [parent_group, sub_group, sub_child_group].each do |group|
                expect(Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_in).with(
                  elastic_group_association_deletion_worker_random_delay_range, group.id, parent_group.id)
              end

              worker.perform(*job_args)
            end
          end

          context 'when passed a sub group' do
            it 'enqueues Search::ElasticGroupAssociationDeletionWorker for a sub group and its descendents only' do
              [sub_group, sub_child_group].each do |group|
                expect(Search::ElasticGroupAssociationDeletionWorker).to receive(:perform_in).with(
                  elastic_group_association_deletion_worker_random_delay_range, group.id, parent_group.id)
              end

              worker.perform(sub_group.id, :delete)
            end
          end
        end
      end
    end
  end
end
