# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::NodeSelector, feature_category: :global_search do
  let_it_be(:node1) { create(:zoekt_node) }
  let_it_be(:node2) { create(:zoekt_node) }
  let_it_be(:node3) { create(:zoekt_node) }

  describe '.for_project' do
    let_it_be(:project) { create(:project) }
    let_it_be(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: project.root_ancestor) }
    let_it_be_with_reload(:replica) do
      create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace, state: :ready)
    end

    let_it_be(:index1) do
      create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, node: node1)
    end

    let_it_be(:index2) do
      create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, node: node2)
    end

    subject(:nodes) { described_class.for_project(project) }

    it 'returns nodes for the project' do
      expect(nodes).to contain_exactly(node1, node2)
    end
  end

  describe '.for_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group.root_ancestor) }
    let_it_be_with_reload(:replica) do
      create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace, state: :ready)
    end

    let_it_be(:index1) do
      create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, node: node1)
    end

    let_it_be(:index2) do
      create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, node: node2)
    end

    subject(:nodes) { described_class.for_group(group) }

    it 'returns nodes for the group' do
      expect(nodes).to contain_exactly(node1, node2)
    end
  end

  describe '.for_global' do
    subject(:nodes) { described_class.for_global }

    before do
      allow(Search::Zoekt::Node).to receive_message_chain(:for_search, :searchable).and_return(
        Search::Zoekt::Node.id_in([node1.id, node2.id])
      )
    end

    it 'returns all online search nodes' do
      expect(nodes).to contain_exactly(node1, node2)
    end
  end

  describe '#nodes' do
    context 'when search level is global' do
      subject(:nodes) { described_class.new(enabled_namespace: nil, search_level: :global, root_ancestor: nil).nodes }

      before do
        allow(Search::Zoekt::Node).to receive_message_chain(:for_search, :searchable).and_return(
          Search::Zoekt::Node.id_in([node1.id, node2.id])
        )
      end

      it 'returns all online search nodes' do
        expect(nodes).to contain_exactly(node1, node2)
      end
    end

    context 'when search level is project' do
      let_it_be(:project) { create(:project) }
      let_it_be(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: project.root_ancestor) }
      let_it_be_with_reload(:replica) do
        create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace, state: :ready)
      end

      let_it_be(:index1) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, node: node1)
      end

      let_it_be(:index2) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, node: node2)
      end

      subject(:nodes) do
        described_class.new(
          enabled_namespace: enabled_namespace,
          search_level: :project,
          root_ancestor: project.root_ancestor
        ).nodes
      end

      it 'returns nodes for the selected replica' do
        expect(nodes).to contain_exactly(node1, node2)
      end

      context 'when there are multiple replicas' do
        let_it_be(:replica2) { create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace, state: :ready) }
        let_it_be(:index3) do
          create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica2, node: node3)
        end

        before do
          # Mock ReplicaSelector to return the first replica with its nodes
          selector_result = Search::Zoekt::ReplicaSelector::Result.new(
            replica: replica,
            nodes: [node1, node2]
          )
          allow_next_instance_of(Search::Zoekt::ReplicaSelector) do |instance|
            allow(instance).to receive(:select).and_return(selector_result)
          end
        end

        it 'returns only nodes from the selected replica' do
          expect(nodes).to contain_exactly(node1, node2)
          expect(nodes).not_to include(node3)
        end
      end

      context 'with caching', :use_clean_rails_redis_caching do
        it 'caches the node IDs' do
          # First call - should cache
          first_result = described_class.new(
            enabled_namespace: enabled_namespace,
            search_level: :project,
            root_ancestor: project.root_ancestor
          ).nodes
          expect(first_result).to contain_exactly(node1, node2)

          # Second call - should use cache (not call pick_for_search again)
          second_result = described_class.new(
            enabled_namespace: enabled_namespace,
            search_level: :project,
            root_ancestor: project.root_ancestor
          ).nodes
          expect(second_result).to contain_exactly(node1, node2)
        end

        it 'provides sticky sessions by returning the same nodes' do
          nodes1 = described_class.new(
            enabled_namespace: enabled_namespace,
            search_level: :project,
            root_ancestor: project.root_ancestor
          ).nodes
          nodes2 = described_class.new(
            enabled_namespace: enabled_namespace,
            search_level: :project,
            root_ancestor: project.root_ancestor
          ).nodes
          nodes3 = described_class.new(
            enabled_namespace: enabled_namespace,
            search_level: :project,
            root_ancestor: project.root_ancestor
          ).nodes

          expect(nodes1.pluck(:id)).to eq(nodes2.pluck(:id))
          expect(nodes2.pluck(:id)).to eq(nodes3.pluck(:id))
        end

        it 'refreshes cache if a cached node goes offline' do
          # First call - cache node1 and node2
          first_result = described_class.new(
            enabled_namespace: enabled_namespace,
            search_level: :project,
            root_ancestor: project.root_ancestor
          ).nodes
          expect(first_result).to contain_exactly(node1, node2)

          # Simulate node1 going offline
          allow(Search::Zoekt::Node).to receive_message_chain(:for_search, :searchable, :id_in)
            .with([node1.id, node2.id])
            .and_return(Search::Zoekt::Node.id_in([node2.id]))

          # Should detect incomplete cache, fetch fresh nodes using ReplicaSelector
          selector_result = Search::Zoekt::ReplicaSelector::Result.new(
            replica: replica,
            nodes: [node1, node2]
          )
          expect_next_instance_of(Search::Zoekt::ReplicaSelector) do |instance|
            expect(instance).to receive(:select).and_return(selector_result)
          end

          second_result = described_class.new(
            enabled_namespace: enabled_namespace,
            search_level: :project,
            root_ancestor: project.root_ancestor
          ).nodes
          expect(second_result).to contain_exactly(node1, node2)

          # Verify cache was repopulated with fresh node IDs
          cache_key = "zoekt:node_selection:#{enabled_namespace.id}:project"
          cached_value = Rails.cache.read(cache_key)
          expect(cached_value).to match_array([node1.id, node2.id])
        end

        it 'respects the cache TTL' do
          cache_key = "zoekt:node_selection:#{enabled_namespace.id}:project"

          # First call - should cache with TTL
          nodes1 = described_class.new(
            enabled_namespace: enabled_namespace,
            search_level: :project,
            root_ancestor: project.root_ancestor
          ).nodes
          expect(nodes1).to contain_exactly(node1, node2)

          # Verify cache exists
          cached_value = Rails.cache.read(cache_key)
          expect(cached_value).to match_array([node1.id, node2.id])
        end
      end

      context 'when enabled_namespace is missing' do
        let_it_be(:project_without_zoekt) { create(:project) }

        it 'raises an ArgumentError' do
          expect do
            described_class.new(
              enabled_namespace: nil,
              search_level: :project,
              root_ancestor: project_without_zoekt.root_ancestor
            ).nodes
          end.to raise_error(ArgumentError, /No enabled namespace found/)
        end
      end

      context 'when there are no ready replicas' do
        before do
          replica.update!(state: :pending)
        end

        it 'raises an ArgumentError' do
          expect do
            described_class.new(
              enabled_namespace: enabled_namespace,
              search_level: :project,
              root_ancestor: project.root_ancestor
            ).nodes
          end.to raise_error(ArgumentError, /No ready replica found/)
        end
      end

      context 'when there are no online nodes for the replica' do
        before do
          selector_result = Search::Zoekt::ReplicaSelector::Result.new(
            replica: replica,
            nodes: []
          )
          allow_next_instance_of(Search::Zoekt::ReplicaSelector) do |instance|
            allow(instance).to receive(:select).and_return(selector_result)
          end
        end

        it 'raises an ArgumentError' do
          expect do
            described_class.new(
              enabled_namespace: enabled_namespace,
              search_level: :project,
              root_ancestor: project.root_ancestor
            ).nodes
          end.to raise_error(ArgumentError, /No online nodes found for replica/)
        end
      end
    end

    context 'when search level is group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group.root_ancestor) }
      let_it_be_with_reload(:replica) do
        create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace, state: :ready)
      end

      let_it_be(:index1) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, node: node1)
      end

      let_it_be(:index2) do
        create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica, node: node2)
      end

      subject(:nodes) do
        described_class.new(
          enabled_namespace: enabled_namespace,
          search_level: :group,
          root_ancestor: group.root_ancestor
        ).nodes
      end

      it 'returns nodes for the selected replica' do
        expect(nodes).to contain_exactly(node1, node2)
      end

      context 'when there are multiple replicas' do
        let_it_be(:replica2) { create(:zoekt_replica, zoekt_enabled_namespace: enabled_namespace, state: :ready) }
        let_it_be(:index3) do
          create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, replica: replica2, node: node3)
        end

        before do
          # Mock ReplicaSelector to return the first replica with its nodes
          selector_result = Search::Zoekt::ReplicaSelector::Result.new(
            replica: replica,
            nodes: [node1, node2]
          )
          allow_next_instance_of(Search::Zoekt::ReplicaSelector) do |instance|
            allow(instance).to receive(:select).and_return(selector_result)
          end
        end

        it 'returns only nodes from the selected replica' do
          expect(nodes).to contain_exactly(node1, node2)
          expect(nodes).not_to include(node3)
        end
      end
    end
  end
end
