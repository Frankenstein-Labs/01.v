# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoToReindexEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node, schema_version: 2) }
  let_it_be(:index) { create(:zoekt_index, node: node) }

  let(:event) { Search::Zoekt::RepoToReindexEvent.new(data: {}) }
  let(:node_scoped_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: node.id }) }

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when zoekt is disabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return false
      end

      it 'does not create any reindexing tasks' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Task.count }
      end
    end

    context 'when event has no zoekt_node_id' do
      it 'does not process any repositories' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Task.count }
      end
    end

    context 'when zoekt is enabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
      end

      context 'with repositories needing reindexing within batch size' do
        it 'creates force_index_repo tasks for repositories with schema version mismatch without re-emitting event' do
          batch_size = 2
          test_node = create(:zoekt_node, schema_version: 2)
          test_index = create(:zoekt_index, node: test_node)
          test_event = Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: test_node.id })

          # Create repositories with different schema version than the node
          create_list(:zoekt_repository, batch_size, :ready, zoekt_index: test_index, schema_version: 1)
          stub_const("#{described_class}::LIMIT", batch_size)

          expect(Gitlab::EventStore).not_to receive(:publish)

          expect do
            consume_event(subscriber: described_class, event: test_event)
          end.to change { Search::Zoekt::Task.count }.from(0).to(batch_size)
          expect(Search::Zoekt::Task.force_index_repo.count).to eq(batch_size)
        end
      end

      context 'with more repositories than batch size needing reindexing' do
        let_it_be(:test_node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:test_index) { create(:zoekt_index, node: test_node) }
        let(:test_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: test_node.id }) }

        before do
          stub_const("#{described_class}::LIMIT", 2)
          # Create 5 repositories with different schema version than the node
          create_list(:zoekt_repository, 5, :ready, zoekt_index: test_index, schema_version: 1)
        end

        it 'processes batch size without scheduling another event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          expect { consume_event(subscriber: described_class, event: test_event) }
            .to change { Search::Zoekt::Task.count }.by(2)
        end
      end

      context 'when repositories have pending or processing tasks' do
        let_it_be(:test_node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:test_index) { create(:zoekt_index, node: test_node) }
        let(:test_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: test_node.id }) }

        before do
          stub_const("#{described_class}::LIMIT", 3)
        end

        context 'when some repositories have pending force_index_repo tasks and others do not' do
          before do
            # Create repository with pending force_index_repo task (should be skipped)
            repository_with_task = create(:zoekt_repository, :ready, zoekt_index: test_index, schema_version: 1)
            create(:zoekt_task, :pending, :force_index_repo, zoekt_repository: repository_with_task)

            # Create repositories without tasks (should be processed)
            create_list(:zoekt_repository, 2, :ready, zoekt_index: test_index, schema_version: 1)
          end

          it 'creates tasks only for repositories without pending force_index_repo tasks' do
            expect do
              consume_event(subscriber: described_class, event: test_event)
            end.to change { Search::Zoekt::Task.count }.by(2) # 3 total slots - 1 existing task = 2 new tasks
          end
        end

        context 'when a repository has a pending index_repo task but no pending force_index_repo task' do
          before do
            repository = create(:zoekt_repository, :ready, zoekt_index: test_index, schema_version: 1)
            create(:zoekt_task, :pending, :index_repo, zoekt_repository: repository)
          end

          it 'still creates a force_index_repo task for that repository' do
            expect do
              consume_event(subscriber: described_class, event: test_event)
            end.to change { Search::Zoekt::Task.force_index_repo.count }.by(1)
          end
        end

        context 'when all available slots are filled with existing force_index_repo tasks' do
          before do
            repositories = create_list(:zoekt_repository, 3, :ready, zoekt_index: test_index, schema_version: 1)
            repositories.each { |repo| create(:zoekt_task, :pending, :force_index_repo, zoekt_repository: repo) }
          end

          it 'does not create any new tasks when all slots are filled' do
            expect do
              consume_event(subscriber: described_class, event: test_event)
            end.not_to change { Search::Zoekt::Task.count }
          end
        end
      end

      context 'when no repositories need reindexing' do
        before do
          node = create(:zoekt_node, schema_version: 1)
          index = create(:zoekt_index, node: node)

          # Create repositories with same schema version as the node (no reindexing needed)
          create_list(:zoekt_repository, 3, :ready, zoekt_index: index, schema_version: 1)
        end

        it 'does not create any tasks and does not re-emit event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          expect do
            consume_event(subscriber: described_class, event: event)
          end.not_to change { Search::Zoekt::Task.count }
        end
      end

      context 'when all reindexing is completed' do
        let_it_be(:test_node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:test_index) { create(:zoekt_index, node: test_node) }
        let(:test_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: test_node.id }) }

        before do
          # Create repositories that need reindexing but have no pending/processing tasks
          create_list(:zoekt_repository, 2, :ready, zoekt_index: test_index, schema_version: 1)
          stub_const("#{described_class}::LIMIT", 5)
        end

        it 'processes tasks without re-emitting event' do
          expect(Gitlab::EventStore).not_to receive(:publish)

          expect { consume_event(subscriber: described_class, event: test_event) }
            .to change { Search::Zoekt::Task.count }.by(2)
        end
      end

      context 'when repositories have matching schema versions' do
        before do
          node = create(:zoekt_node, schema_version: 1)
          index = create(:zoekt_index, node: node)

          # Create repositories with same schema version as node (no reindexing needed)
          create_list(:zoekt_repository, 2, :ready, zoekt_index: index, schema_version: 1)
        end

        it 'does not create any tasks' do
          expect do
            consume_event(subscriber: described_class, event: event)
          end.not_to change { Search::Zoekt::Task.count }
        end
      end

      context 'with node-scoped events' do
        let_it_be(:node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:other_node) { create(:zoekt_node, schema_version: 2) }
        let_it_be(:index) { create(:zoekt_index, node: node) }
        let_it_be(:other_index) { create(:zoekt_index, node: other_node) }

        before do
          stub_const("#{described_class}::LIMIT", 5)
        end

        context 'when processing repositories for a specific node' do
          before do
            # Create repositories needing reindexing on both nodes
            create_list(:zoekt_repository, 2, :ready, zoekt_index: index, schema_version: 1)
            create_list(:zoekt_repository, 3, :ready, zoekt_index: other_index, schema_version: 1)
          end

          it 'only processes repositories for the specified node' do
            expect do
              consume_event(subscriber: described_class, event: node_scoped_event)
            end.to change { Search::Zoekt::Task.count }.by(2)

            # Verify tasks were created only for the specified node's repositories
            created_tasks = Search::Zoekt::Task.all
            expect(created_tasks.map(&:zoekt_node_id).uniq).to eq([node.id])
          end
        end

        context 'when specified node has repositories with pending force_index_repo tasks' do
          before do
            # Create repository with pending force_index_repo task (should be skipped)
            repository = create(:zoekt_repository, :ready, zoekt_index: index, schema_version: 1)
            create(:zoekt_task, :pending, :force_index_repo, zoekt_repository: repository)

            # Create additional repository without task (should be processed)
            create(:zoekt_repository, :ready, zoekt_index: index, schema_version: 1)

            # Create repositories on other node that could be processed
            create_list(:zoekt_repository, 2, :ready, zoekt_index: other_index, schema_version: 1)
          end

          it 'processes available repos for the specified node, skipping those with pending force_index_repo tasks' do
            expect do
              consume_event(subscriber: described_class, event: node_scoped_event)
            end.to change { Search::Zoekt::Task.count }.by(1) # 5 total - 1 existing = 4, but only 1 repo without task
          end
        end

        context 'when specified node has no repositories needing reindexing' do
          before do
            # Create repositories with matching schema versions on the specified node
            create_list(:zoekt_repository, 2, :ready, zoekt_index: index, schema_version: 2)

            # Create repositories needing reindexing on other node
            create_list(:zoekt_repository, 3, :ready, zoekt_index: other_index, schema_version: 1)
          end

          it 'does not create any tasks' do
            expect do
              consume_event(subscriber: described_class, event: node_scoped_event)
            end.not_to change { Search::Zoekt::Task.count }
          end
        end

        context 'when node ID does not exist' do
          let(:invalid_node_event) { Search::Zoekt::RepoToReindexEvent.new(data: { zoekt_node_id: 99999 }) }

          before do
            create_list(:zoekt_repository, 2, :ready, zoekt_index: index, schema_version: 1)
          end

          it 'does not create any tasks' do
            expect do
              consume_event(subscriber: described_class, event: invalid_node_event)
            end.not_to change { Search::Zoekt::Task.count }
          end
        end
      end
    end
  end
end
