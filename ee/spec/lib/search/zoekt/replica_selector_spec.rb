# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ReplicaSelector, feature_category: :global_search do
  describe '#select' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
    let_it_be(:node1) { create(:zoekt_node) }
    let_it_be(:node2) { create(:zoekt_node) }
    let_it_be(:node3) { create(:zoekt_node) }

    subject(:result) { described_class.new(zoekt_enabled_namespace).select }

    context 'when there are no ready replicas' do
      it 'returns an empty result' do
        expect(result.replica).to be_nil
        expect(result.nodes).to be_empty
        expect(result).to be_empty
        expect(result).not_to be_present
      end
    end

    context 'when there is only one ready replica' do
      let_it_be(:replica) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: zoekt_enabled_namespace) }

      let_it_be(:index) do
        create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, replica: replica, node: node1)
      end

      it 'returns that replica with its nodes' do
        expect(result.replica).to eq(replica)
        expect(result.nodes).to contain_exactly(node1)
        expect(result).to be_present
        expect(result).not_to be_empty
      end
    end

    context 'when there are multiple ready replicas' do
      let_it_be(:replica1) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: zoekt_enabled_namespace) }
      let_it_be(:replica2) { create(:zoekt_replica, :ready, zoekt_enabled_namespace: zoekt_enabled_namespace) }

      let_it_be(:index1) do
        create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, replica: replica1, node: node1)
      end

      let_it_be(:index2) do
        create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, replica: replica2, node: node2)
      end

      it 'picks the replica with the lowest load using LoadBalancer' do
        load_balancer1 = instance_double(Search::Zoekt::LoadBalancer)
        load_balancer2 = instance_double(Search::Zoekt::LoadBalancer)

        allow(Search::Zoekt::LoadBalancer).to receive(:new) do |nodes|
          node_ids = nodes.map(&:id).sort
          if node_ids == [node1.id]
            load_balancer1
          elsif node_ids == [node2.id]
            load_balancer2
          else
            # For any other nodes, return a stub with high load
            lb = instance_double(Search::Zoekt::LoadBalancer)
            allow(lb).to receive_messages(pick: nodes.first,
              distribution: [{ node_id: nodes.first.id, current_load: 999.0 }])
            lb
          end
        end

        allow(load_balancer1).to receive_messages(pick: node1, distribution: [{ node_id: node1.id, current_load: 5.0 }])
        allow(load_balancer2).to receive_messages(pick: node2, distribution: [{ node_id: node2.id, current_load: 2.0 }])

        # Should pick replica2 because node2 has lower load (2.0 < 5.0)
        expect(result.replica).to eq(replica2)
        expect(result.nodes).to contain_exactly(node2)
      end

      context 'when a replica has no online nodes' do
        let_it_be(:replica3) do
          create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace, state: :ready)
        end

        let_it_be(:node_offline) { create(:zoekt_node, last_seen_at: 2.minutes.ago) }

        let_it_be(:index3) do
          create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, replica: replica3, node: node_offline)
        end

        it 'skips the replica with no online nodes and picks another' do
          load_balancer1 = instance_double(Search::Zoekt::LoadBalancer)
          load_balancer2 = instance_double(Search::Zoekt::LoadBalancer)

          allow(Search::Zoekt::LoadBalancer).to receive(:new) do |nodes|
            node_ids = nodes.map(&:id).sort
            if node_ids == [node1.id]
              load_balancer1
            elsif node_ids == [node2.id]
              load_balancer2
            else
              # For any other nodes, return a stub with high load
              lb = instance_double(Search::Zoekt::LoadBalancer)
              allow(lb).to receive_messages(pick: nodes.first,
                distribution: [{ node_id: nodes.first.id, current_load: 999.0 }])
              lb
            end
          end

          allow(load_balancer1).to receive_messages(pick: node1,
            distribution: [{ node_id: node1.id, current_load: 3.0 }])
          allow(load_balancer2).to receive_messages(pick: node2,
            distribution: [{ node_id: node2.id, current_load: 1.0 }])

          # Should skip replica3 (offline node) and pick replica2 (lower load than replica1)
          expect(result.replica).to eq(replica2)
          expect(result.nodes).to contain_exactly(node2)
        end
      end

      context 'when checking for N+1 queries' do
        let_it_be(:node4) { create(:zoekt_node) }
        let_it_be(:node5) { create(:zoekt_node) }
        let_it_be(:node6) { create(:zoekt_node) }

        it 'does not create N+1 queries when iterating over multiple replicas' do
          # Create multiple replicas with nodes to ensure we iterate over them
          replica3 = create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace, state: :ready)
          replica4 = create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace, state: :ready)

          create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, replica: replica3, node: node4)
          create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, replica: replica4, node: node5)

          # Setup load balancer mocks
          allow(Search::Zoekt::LoadBalancer).to receive(:new).and_wrap_original do |original_method, *args, &block|
            lb = original_method.call(*args, &block)
            allow(lb).to receive_messages(pick: args.first.first,
              distribution: [{ node_id: args.first.first.id, current_load: 1.0 }])
            lb
          end

          # Warmup query to load any initial data
          described_class.new(zoekt_enabled_namespace).select

          # Now measure queries - should not scale with number of replicas
          control = ActiveRecord::QueryRecorder.new do
            described_class.new(zoekt_enabled_namespace).select
          end

          # Add more replicas - this should NOT increase query count
          replica5 = create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace, state: :ready)
          replica6 = create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace, state: :ready)
          create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, replica: replica5, node: node6)
          create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, replica: replica6, node: node3)

          expect do
            described_class.new(zoekt_enabled_namespace).select
          end.not_to exceed_query_limit(control)
        end
      end
    end
  end

  describe 'Result' do
    describe '#present?' do
      it 'returns true when both replica and nodes are present' do
        replica = build(:zoekt_replica)
        nodes = [build(:zoekt_node)]
        result = described_class::Result.new(replica: replica, nodes: nodes)

        expect(result).to be_present
      end

      it 'returns false when replica is nil' do
        result = described_class::Result.new(replica: nil, nodes: [build(:zoekt_node)])

        expect(result).not_to be_present
      end

      it 'returns false when nodes are empty' do
        result = described_class::Result.new(replica: build(:zoekt_replica), nodes: [])

        expect(result).not_to be_present
      end
    end

    describe '#empty?' do
      it 'returns false when both replica and nodes are present' do
        replica = build(:zoekt_replica)
        nodes = [build(:zoekt_node)]
        result = described_class::Result.new(replica: replica, nodes: nodes)

        expect(result).not_to be_empty
      end

      it 'returns true when replica is nil' do
        result = described_class::Result.new(replica: nil, nodes: [])

        expect(result).to be_empty
      end
    end
  end
end
