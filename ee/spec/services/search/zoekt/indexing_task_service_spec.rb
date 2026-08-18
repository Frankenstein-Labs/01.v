# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexingTaskService, feature_category: :global_search do
  let_it_be(:ns) { create(:group) }
  let_it_be(:project) { create(:project, namespace: ns) }
  let_it_be(:node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: ns) }
  let_it_be_with_reload(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: node)
  end

  describe '.execute' do
    let(:service) { described_class.new(project.id, :index_repo) }

    it 'executes the task' do
      expect(described_class).to receive(:new).with(project.id, :index_repo).and_return(service)
      expect(service).to receive(:execute)
      described_class.execute(project.id, :index_repo)
    end
  end

  describe '#execute' do
    context 'when a watermark is exceeded' do
      let(:service) { described_class.new(project.id, task_type) }
      let(:task_type) { :index_repo }

      before do
        allow(Search::Zoekt::Router).to receive(:fetch_indices_for_indexing)
          .with(project.id, root_namespace_id: zoekt_enabled_namespace.root_namespace_id)
          .and_return(zoekt_index)

        allow(zoekt_index).to receive(:find_each).and_yield(zoekt_index)
      end

      context 'on low watermark' do
        before do
          allow(zoekt_index).to receive(:low_watermark_exceeded?).and_return(true)
        end

        context 'with initial indexing' do
          it 'creates Search::Zoekt::Task record for initial indexing' do
            expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
          end
        end

        context 'with force reindexing' do
          let(:task_type) { :force_index_repo }

          context 'when a repo does not exist' do
            it 'creates Search::Zoekt::Task record for initial indexing' do
              expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
            end
          end

          context 'when a repo already exists' do
            let_it_be(:repo_state) { ::Search::Zoekt::Repository.states.fetch(:pending) }
            let_it_be(:zoekt_repo) do
              create(:zoekt_repository, project: project, zoekt_index: zoekt_index, state: repo_state)
            end

            context 'and is ready' do
              let_it_be(:repo_state) { ::Search::Zoekt::Repository.states.fetch(:ready) }

              it 'creates Search::Zoekt::Task record for initial indexing' do
                expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
              end
            end

            context 'and is not ready' do
              let_it_be(:repo_state) { ::Search::Zoekt::Repository.states.fetch(:orphaned) }

              it 'creates Search::Zoekt::Task record for initial indexing' do
                expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
              end
            end
          end
        end

        context 'with incremental indexing' do
          before do
            create(:zoekt_repository, project: project, zoekt_index: zoekt_index, state: :ready)
          end

          it 'allows incremental indexing' do
            expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
          end
        end
      end

      context 'on high watermark' do
        before do
          allow(zoekt_index).to receive(:high_watermark_exceeded?).and_return(true)
        end

        it 'creates Search::Zoekt::Task record' do
          expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
        end
      end
    end

    context 'when task_type is delete_repo' do
      let(:service) { described_class.new(project.id, :delete_repo) }

      it 'creates Search::Zoekt::Task record' do
        expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
      end
    end

    context 'when task_type is not delete_repo' do
      let(:task_type) { 'index_repo' }
      let(:service) { described_class.new(project.id, task_type) }
      let_it_be(:_) { create(:application_setting) }

      context 'when zoekt_force_reindexing_percentage is set to 100%' do
        before do
          stub_ee_application_setting(zoekt_force_reindexing_percentage: 100.0)
        end

        it 'replaces the task type to force_index_repo' do
          expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
            .and change { Search::Zoekt::Repository.count }.by(1)

          repo = Search::Zoekt::Repository.find_by(project: project, zoekt_index: zoekt_index)
          expect(repo.tasks.last).to be_force_index_repo
        end
      end

      context 'when zoekt_force_reindexing_percentage is set to 0%' do
        before do
          stub_ee_application_setting(zoekt_force_reindexing_percentage: 0.0)
        end

        it 'does not force reindex' do
          expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
            .and change { Search::Zoekt::Repository.count }.by(1)

          repo = Search::Zoekt::Repository.find_by(project: project, zoekt_index: zoekt_index)
          expect(repo.tasks.last).to be_index_repo
        end
      end

      context 'when index is orphaned' do
        before do
          zoekt_index.orphaned!
        end

        it 'does not do anything' do
          expect { service.execute }.not_to change { Search::Zoekt::Task.count }
        end
      end

      context 'when index is pending deletion' do
        before do
          zoekt_index.pending_deletion!
        end

        it 'does not do anything' do
          expect { service.execute }.not_to change { Search::Zoekt::Task.count }
        end
      end
    end
  end
end
