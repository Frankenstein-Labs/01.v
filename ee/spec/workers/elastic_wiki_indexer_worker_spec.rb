# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ElasticWikiIndexerWorker, feature_category: :global_search do
  describe '#perform' do
    subject(:worker) { described_class.new }

    let(:logger_double) { instance_double(Gitlab::Elasticsearch::Logger) }

    let_it_be(:project) { create(:project) }

    before do
      allow(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double.as_null_object)
    end

    context 'when ES is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'does not run Search::Elastic::Indexer and does not perform logging and metrics' do
        expect(Search::Elastic::Indexer).not_to receive(:new)
        expect(logger_double).not_to receive(:info)
        expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)

        expect(worker.perform(project.id, project.class.name)).to be true
      end
    end

    context 'when ES is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      context 'when container is Project' do
        context 'when elasticsearch is disabled for Project' do
          it 'does not remove the project but removes all associated documents from the index' do
            allow_next_found_instance_of(Project) do |project|
              expect(project).to receive(:use_elasticsearch?).and_return(false)
            end

            expect(ElasticDeleteProjectWorker).to receive(:perform_async)
              .with(project.id, project.es_id, delete_project: false)
            expect(Search::Elastic::Indexer).not_to receive(:new)
            expect(logger_double).not_to receive(:info)
            expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)
            expect(worker.perform(project.id, project.class.name)).to be true
          end
        end

        context 'when elasticsearch is enabled for Project' do
          context 'and options force is passed as true' do
            it 'runs Search::Elastic::Indexer with force and performs logging and metrics' do
              expect_next_instance_of(Search::Elastic::Indexer, project, { wiki: true, force: true }) do |indexer|
                expect(indexer).to receive(:run).and_return(true)
              end
              expect(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double.as_null_object)
              expect(logger_double).to receive(:info)
              expect(Gitlab::Metrics::GlobalSearchIndexingSlis).to receive(:record_apdex)
              worker.perform(project.id, project.class.name, { force: true })
            end
          end

          context 'and options is not passed' do
            it 'runs Search::Elastic::Indexer without force and performs logging and metrics' do
              expect_next_instance_of(Search::Elastic::Indexer, project, { wiki: true, force: false }) do |indexer|
                expect(indexer).to receive(:run).and_return(true)
              end
              expect(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double.as_null_object)
              expect(logger_double).to receive(:info)
              expect(Gitlab::Metrics::GlobalSearchIndexingSlis).to receive(:record_apdex)
              worker.perform(project.id, project.class.name)
            end
          end
        end
      end

      context 'when container is Group' do
        let_it_be(:group) { create(:group) }

        context 'when elasticsearch is disabled for Group' do
          it 'does not run Search::Elastic::Indexer and does not perform logging and metrics' do
            allow_next_found_instance_of(Group) do |group|
              expect(group).to receive(:use_elasticsearch?).and_return(false)
            end
            expect(Search::Wiki::ElasticDeleteGroupWikiWorker).to receive(:perform_async).with(group.id)
            expect(Search::Elastic::Indexer).not_to receive(:new)
            expect(logger_double).not_to receive(:info)
            expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)
            expect(worker.perform(group.id, group.class.name)).to be true
          end
        end

        context 'when elasticsearch is enabled for Group' do
          it 'runs Search::Elastic::Indexer and performs logging and metrics' do
            allow_next_found_instance_of(Group) do |group|
              expect(group).to receive(:use_elasticsearch?).and_return(true)
            end
            expect_next_instance_of(Search::Elastic::Indexer) do |indexer|
              expect(indexer).to receive(:run).and_return(true)
            end
            expect(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double.as_null_object)
            expect(logger_double).to receive(:info)
            expect(Gitlab::Metrics::GlobalSearchIndexingSlis).to receive(:record_apdex)
            worker.perform(group.id, group.class.name)
          end
        end
      end

      context 'when container is neither Group nor Project' do
        let_it_be(:user) { create(:user) }

        it 'does not run Search::Elastic::Indexer, performs error logging and does not perform metrics log' do
          expect(Search::Elastic::Indexer).not_to receive(:new)
          expect(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double.as_null_object)
          expect(logger_double).to receive(:error).with(container_id: user.id, container_type: user.class.name,
            message: 'ElasticWikiIndexerWorker only accepts Project and Group')
          expect(logger_double).not_to receive(:info)
          expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)
          expect(worker.perform(user.id, user.class.name)).to be true
        end
      end

      context 'when container can not be found' do
        let_it_be(:id) { non_existing_record_id }
        let_it_be(:es_id) do
          Search::Elastic::Helper.build_es_id(es_type: Project.es_type, target_id: non_existing_record_id)
        end

        it 'removes the project and all associated documents from the index' do
          expect(logger_double).to receive(:warn).with(container_id: id, container_type: Project.name,
            message: 'Container record not found')
          expect(ElasticDeleteProjectWorker).to receive(:perform_async).with(id, es_id, delete_project: true)
          expect(Search::Elastic::Indexer).not_to receive(:new)
          expect(logger_double).not_to receive(:info)
          expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)
          expect(worker.perform(id, Project.name)).to be true
        end
      end

      context 'when container_id is nil' do
        it 'does not run Search::Elastic::Indexer, performs error logging and does not perform metrics log' do
          expect(Search::Elastic::Indexer).not_to receive(:new)
          expect(logger_double).to receive(:error).with(message: 'container_id or container_type can not be nil',
            container_id: nil, container_type: Project.name)
          expect(logger_double).not_to receive(:info)
          expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)
          expect(worker.perform(nil, Project.name)).to be true
        end
      end
    end
  end
end
