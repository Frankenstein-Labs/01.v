# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::PlanningService, :freeze_time, feature_category: :global_search do
  let_it_be(:group1) { create(:group) }
  let_it_be_with_reload(:enabled_namespace1) { create(:zoekt_enabled_namespace, namespace: group1) }
  let_it_be(:group2) { create(:group) }
  let_it_be_with_reload(:enabled_namespace2) { create(:zoekt_enabled_namespace, namespace: group2) }
  # `freeze: false` is required here: this `let_it_be` subject cannot survive
  # `let_it_be`'s `deep_freeze` traversal (e.g. a test/verifying double, a
  # delegator whose association-reflection walk raises, or an rspec-mocks
  # proxy). Freezing it raises during setup, so the opt-out is kept. Do not
  # drop it or convert to `let_it_be_with_reload`/`refind` (see
  # gitlab-org/gitlab#602925).
  let_it_be(:_, freeze: false) { create_list(:zoekt_node, 5, total_bytes: 100.gigabytes, used_bytes: 90.gigabytes) }
  # `freeze: false` is required here: this `let_it_be` subject is an
  # ActiveRecord::Relation whose `deep_freeze` traversal recurses infinitely
  # (SystemStackError). Keep the opt-out (see gitlab-org/gitlab#602925).
  let_it_be(:nodes, freeze: false) { Search::Zoekt::Node.order_by_unclaimed_space_desc.online }
  let_it_be(:projects_namespace1) do
    [
      create(:project, namespace: group1, statistics: create(:project_statistics, repository_size: 1.gigabyte)),
      create(:project, namespace: group1, statistics: create(:project_statistics, repository_size: 2.gigabytes))
    ]
  end

  let_it_be(:projects_namespace2) do
    [create(:project, namespace: group2, statistics: create(:project_statistics, repository_size: 2.gigabytes))]
  end

  let(:max_indices_per_replica) { Search::Zoekt::MAX_INDICES_PER_REPLICA }

  describe '.plan' do
    subject(:plan) do
      described_class.plan(
        enabled_namespaces: [enabled_namespace1, enabled_namespace2],
        nodes: nodes,
        max_indices_per_replica: max_indices_per_replica
      )
    end

    let(:num_replicas) { 2 }
    let(:buffer_factor) { Search::Zoekt::Index::DEFAULT_BUFFER_FACTOR }

    before do
      enabled_namespace1.update!(number_of_replicas_override: num_replicas)
      enabled_namespace2.update!(number_of_replicas_override: num_replicas)
    end

    it 'returns total required storage bytes across all namespaces' do
      total_storage = (projects_namespace1 + projects_namespace2).sum { |p| p.statistics.repository_size }
      buffered_storage = total_storage * buffer_factor * num_replicas
      expect(plan[:total_required_storage_bytes]).to eq(buffered_storage)
    end

    it 'returns plans for each enabled namespace to create' do
      expect(plan[:create].size).to eq(2)
      expect(plan[:create].pluck(:enabled_namespace_id))
        .to contain_exactly(enabled_namespace1.id, enabled_namespace2.id)
    end

    it 'calculates the namespace-specific required storage bytes' do
      namespace1_storage = projects_namespace1.sum { |p| p.statistics.repository_size * buffer_factor }
      namespace2_storage = projects_namespace2.sum { |p| p.statistics.repository_size * buffer_factor }

      expect(plan[:create][0][:namespace_required_storage_bytes]).to eq(namespace1_storage * num_replicas)
      expect(plan[:create][1][:namespace_required_storage_bytes]).to eq(namespace2_storage * num_replicas)
    end

    it 'assigns projects to indices for each namespace without reusing nodes' do
      namespace1_used_nodes = []
      plan[:create][0][:replicas].each do |replica|
        replica[:indices].each do |index|
          expect(namespace1_used_nodes).not_to include(index[:node_id])
          namespace1_used_nodes << index[:node_id]
        end
      end
    end

    it 'identifies the target node on each index with id and name' do
      nodes_by_id = nodes.index_by(&:id)

      plan[:create].flat_map { |np| np[:replicas].flat_map { |r| r[:indices] } }.each do |index|
        node = nodes_by_id.fetch(index[:node_id])
        expect(index[:node_name]).to eq(node.metadata['name'])
      end
    end

    context 'when there are no nodes' do
      let_it_be(:nodes) { Search::Zoekt::Node.none }

      it 'creates plan with failure 0 total_required_storage_bytes' do
        expect(plan[:failures]).not_to be_empty
        expect(plan[:create]).to be_empty
      end
    end

    context 'when max indices per replica is reached' do
      let(:max_indices_per_replica) { 1 }

      it 'logs an error for the namespace which can not be fit into 1 index' do
        plan[:failures].each do |namespace_plan|
          expect(namespace_plan[:errors]).to include(a_hash_including(type: :index_limit_exceeded))
        end
      end
    end

    context 'when a namespace has to be spread across multiple indices' do
      let(:num_replicas) { 1 }

      before do
        create(:project, namespace: group1, statistics: create(:project_statistics, repository_size: 2.gigabytes))
        enabled_namespace1.update!(number_of_replicas_override: num_replicas)
      end

      it 'creates multiple indices for a namespace' do
        namespace1_plan = plan[:create].find { |n| n[:enabled_namespace_id] == enabled_namespace1.id }
        indices_plan = namespace1_plan[:replicas].flat_map { |replica| replica[:indices] }

        expect(indices_plan.size).to eq(2)
        expect(indices_plan.pluck(:node_id).uniq.size).to eq(2)
        projects = indices_plan.first[:projects]
        p_ns = ::Namespace.by_root_id(group1.id).project_namespaces.order(:id)
        expect(projects).to eq({ project_namespace_id_from: nil, project_namespace_id_to: p_ns[1].id })
        first_index_project_namespace_id_to = projects[:project_namespace_id_to]
        projects = indices_plan.last[:projects]
        expect(projects).to eq(
          { project_namespace_id_from: first_index_project_namespace_id_to.next, project_namespace_id_to: nil }
        )

        namespace2_plan = plan[:create].find { |n| n[:enabled_namespace_id] == enabled_namespace2.id }
        indices_plan = namespace2_plan[:replicas].flat_map { |replica| replica[:indices] }
        expect(indices_plan.size).to eq(1)
        projects = indices_plan.first[:projects]
        expect(projects).to eq({ project_namespace_id_from: nil, project_namespace_id_to: nil })
      end
    end

    context 'when there are more projects than the batch size' do
      let(:batch_size) { 2 }
      let(:num_replicas) { 2 }

      before do
        # Create more projects than the batch size
        (1..6).each do |i|
          create(:project, namespace: group1, statistics: create(:project_statistics, repository_size: i.megabytes))
        end
        enabled_namespace1.update!(number_of_replicas_override: num_replicas)
      end

      it 'processes all projects in batches without skipping any' do
        # Run the planning service with a specific batch size
        result = described_class.plan(
          enabled_namespaces: [enabled_namespace1],
          nodes: nodes
        )

        # Total storage should account for all projects
        total_storage = group1.projects.sum do |p|
          p.statistics.repository_size
        end

        buffered_storage = total_storage * buffer_factor * num_replicas

        expect(result[:total_required_storage_bytes]).to eq(buffered_storage)

        # Ensure all projects are assigned
        assigned_projects = result[:create][0][:replicas].flat_map { |r| r[:indices].flat_map { |i| i[:projects] } }
        lower, upper = assigned_projects.pluck(:project_namespace_id_from, :project_namespace_id_to).flatten.uniq
        id_range = upper.blank? ? lower.. : lower..upper
        project_ids = group1.projects.by_project_namespace(id_range).pluck(:id)

        expect(project_ids).to match_array(group1.projects.pluck(:id))
      end
    end

    context 'when a project has nil statistics' do
      let(:num_replicas) { 1 }
      let_it_be(:project_with_nil_statistics) { create(:project, namespace: group1) }

      before do
        project_with_nil_statistics.statistics.delete
        enabled_namespace1.update!(number_of_replicas_override: num_replicas)
      end

      it 'skips the project with nil statistics and continues processing other projects' do
        result = described_class.plan(
          enabled_namespaces: [enabled_namespace1],
          nodes: nodes
        )

        expected_storage = projects_namespace1.sum do |p|
          p.statistics.repository_size * buffer_factor * num_replicas
        end
        expect(result[:total_required_storage_bytes]).to eq(expected_storage)

        namespace_plan = result[:create].find { |n| n[:namespace_id] == group1.id }
        expect(namespace_plan[:errors]).to be_empty
      end
    end

    context 'when a namespace does not have any project_namespaces' do
      let_it_be(:namespace_without_project_namespace) { create(:group) }
      let_it_be_with_reload(:enabled_namespace) do
        create(:zoekt_enabled_namespace, namespace: namespace_without_project_namespace)
      end

      subject(:plan) do
        described_class.plan(enabled_namespaces: [enabled_namespace], nodes: nodes)
      end

      before do
        enabled_namespace.update!(number_of_replicas_override: num_replicas)
      end

      it 'creates plan with 0 total_required_storage_bytes' do
        expect(plan[:total_required_storage_bytes]).to eq(0)
        expect(plan[:failures]).to be_empty
        projects_plan = plan[:create][0][:replicas][0][:indices][0][:projects]
        expect(projects_plan).to eq({ project_namespace_id_from: nil, project_namespace_id_to: nil })
      end

      context 'when node is not available' do
        let_it_be(:nodes) { Search::Zoekt::Node.none }

        it 'creates plan with failure 0 total_required_storage_bytes' do
          expect(plan[:failures]).not_to be_empty
          expect(plan[:create]).to be_empty
        end
      end
    end

    context 'when there is a single node and a namespace has multiple projects' do
      let(:num_replicas) { 1 }
      let_it_be(:nodes) { Search::Zoekt::Node.order_by_unclaimed_space_desc.online.limit(1) }

      before do
        # Use a small buffer factor so both namespaces (1 GB + 2 GB, 2 GB) fit on the
        # single 10 GB node. The default 3x would require 9 GB + 6 GB = 15 GB which
        # exceeds the node's capacity and would leave namespace2 without a node.
        allow(Search::Zoekt::Index).to receive(:global_buffer_factor).and_return(1.5)
      end

      it 'returns successful plans for each enabled namespace' do
        result = plan
        expect(result[:create].size).to eq(2)
        expect(result[:create].pluck(:enabled_namespace_id))
          .to contain_exactly(enabled_namespace1.id, enabled_namespace2.id)
      end
    end
  end

  describe 'action determination and mixed scenarios' do
    let(:buffer_factor) { Search::Zoekt::Index::DEFAULT_BUFFER_FACTOR }

    context 'when namespace needs to destroy replicas' do
      let_it_be(:namespace_with_replicas) { create(:group) }
      let_it_be(:enabled_namespace_destroy) do
        create(:zoekt_enabled_namespace, namespace: namespace_with_replicas, number_of_replicas_override: 2)
      end

      let_it_be_with_reload(:existing_replicas) do
        create_list(:zoekt_replica, 5,
          namespace_id: namespace_with_replicas.id,
          zoekt_enabled_namespace: enabled_namespace_destroy
        )
      end

      subject(:plan) do
        described_class.plan(
          enabled_namespaces: [enabled_namespace_destroy],
          nodes: nodes
        )
      end

      it 'creates a destroy plan with replica IDs to remove' do
        expect(plan[:destroy].size).to eq(1)
        destroy_plan = plan[:destroy].first

        expect(destroy_plan[:action]).to eq(:destroy)
        expect(destroy_plan[:namespace_id]).to eq(namespace_with_replicas.id)
        expect(destroy_plan[:replicas_to_destroy]).to be_an(Array)
        expect(destroy_plan[:replicas_to_destroy].size).to eq(3) # 5 existing - 2 desired = 3 to destroy
        expect(destroy_plan[:replicas_to_destroy]).to all(be_a(Integer))
      end

      it 'does not include destroy plans in create section' do
        expect(plan[:create]).to be_empty
      end

      it 'does not calculate storage for destroy actions' do
        expect(plan[:total_required_storage_bytes]).to eq(0)
      end

      context 'with replica deletion order' do
        # Reset all replicas to a known state before these tests
        before do
          existing_replicas.each(&:ready!)
        end

        it 'deletes replicas deterministically: pending state first, then by oldest ID' do
          # Update replicas with mixed states and IDs
          existing_replicas[0].ready!
          existing_replicas[1].pending!
          existing_replicas[2].ready!
          existing_replicas[3].pending!
          existing_replicas[4].ready!

          # Reload to ensure we have fresh data from DB
          test_replicas = enabled_namespace_destroy.replicas.reload

          # Run the plan multiple times to ensure deterministic results
          results = Array.new(3) do
            described_class.plan(
              enabled_namespaces: [enabled_namespace_destroy],
              nodes: nodes
            )
          end

          # All runs should return the same replica IDs in the same order
          first_result = results[0][:destroy].first[:replicas_to_destroy]

          expect(results[1][:destroy].first[:replicas_to_destroy]).to eq(first_result)
          expect(results[2][:destroy].first[:replicas_to_destroy]).to eq(first_result)

          # Verify the order: pending state replicas come first (sorted by descending ID within state)
          # then ready state replicas (sorted by descending ID)
          # enum: pending: 0, ready: 10
          # sort_by: [state_before_type_cast, -id] means pending (0) comes before ready (10)
          pending_replicas = test_replicas.select { |r| r.state == 'pending' }.sort_by(&:id).reverse
          ready_replicas = test_replicas.select { |r| r.state == 'ready' }.sort_by(&:id).reverse

          # We need 3 replicas to destroy (5 existing - 2 desired)
          # Should take all pending first (2), then oldest ready (1)
          expected_order = (pending_replicas + ready_replicas).take(3).map(&:id)

          expect(first_result).to eq(expected_order)
        end

        it 'is deterministic when all replicas have the same state' do
          # Ensure all replicas are in ready state (should already be from before block)
          enabled_namespace_destroy.replicas.update_all(state: :ready)

          # Run multiple times
          results = Array.new(3) do
            described_class.plan(
              enabled_namespaces: [enabled_namespace_destroy],
              nodes: nodes
            )
          end

          # All runs should return the same replica IDs
          first_result = results[0][:destroy].first[:replicas_to_destroy]
          expect(results[1][:destroy].first[:replicas_to_destroy]).to eq(first_result)
          expect(results[2][:destroy].first[:replicas_to_destroy]).to eq(first_result)

          # Should be sorted by descending ID (oldest first)
          expected_order = enabled_namespace_destroy.replicas.reload.sort_by(&:id).reverse.take(3).map(&:id)
          expect(first_result).to eq(expected_order)
        end
      end
    end

    context 'when namespace has exactly the desired number of replicas' do
      let_it_be(:namespace_unchanged) { create(:group) }
      let_it_be(:enabled_namespace_unchanged) do
        create(:zoekt_enabled_namespace, namespace: namespace_unchanged, number_of_replicas_override: 3)
      end

      let_it_be(:_existing_replicas_unchanged) do
        create_list(:zoekt_replica, 3,
          namespace_id: namespace_unchanged.id,
          zoekt_enabled_namespace: enabled_namespace_unchanged
        )
      end

      subject(:plan) do
        described_class.plan(
          enabled_namespaces: [enabled_namespace_unchanged],
          nodes: nodes
        )
      end

      it 'creates an unchanged plan' do
        expect(plan[:unchanged].size).to eq(1)
        unchanged_plan = plan[:unchanged].first

        expect(unchanged_plan[:action]).to eq(:unchanged)
        expect(unchanged_plan[:namespace_id]).to eq(namespace_unchanged.id)
      end

      it 'does not include in create or destroy sections' do
        expect(plan[:create]).to be_empty
        expect(plan[:destroy]).to be_empty
      end

      it 'does not calculate storage for unchanged actions' do
        expect(plan[:total_required_storage_bytes]).to eq(0)
      end

      it 'returns empty replica and error arrays for unchanged action' do
        unchanged_plan = plan[:unchanged].first

        expect(unchanged_plan[:replicas]).to eq([])
        expect(unchanged_plan[:errors]).to eq([])
        expect(unchanged_plan[:namespace_required_storage_bytes]).to eq(0)
      end
    end

    context 'when scaling down to zero replicas' do
      let_it_be(:namespace_scale_to_zero) { create(:group) }
      let_it_be(:enabled_namespace_zero) do
        # Note: We bypass validation here to test the planning logic
        # In practice, validation prevents setting to 0, but we want to ensure the planner handles it gracefully
        ns = create(:zoekt_enabled_namespace, namespace: namespace_scale_to_zero, number_of_replicas_override: 1)
        ns.update_column(:number_of_replicas_override, 0) # Bypass validation
        ns
      end

      let_it_be(:existing_replicas_zero) do
        create_list(:zoekt_replica, 3,
          namespace_id: namespace_scale_to_zero.id,
          zoekt_enabled_namespace: enabled_namespace_zero
        )
      end

      subject(:plan) do
        described_class.plan(
          enabled_namespaces: [enabled_namespace_zero],
          nodes: nodes
        )
      end

      it 'creates a destroy plan to remove all replicas' do
        expect(plan[:destroy].size).to eq(1)
        destroy_plan = plan[:destroy].first

        expect(destroy_plan[:action]).to eq(:destroy)
        expect(destroy_plan[:replicas_to_destroy].size).to eq(3)
      end
    end

    context 'when multiple namespaces have different actions' do
      let_it_be(:create_namespace) { create(:group) }
      let_it_be(:enabled_namespace_create) do
        create(:zoekt_enabled_namespace, namespace: create_namespace, number_of_replicas_override: 3)
      end

      let_it_be(:destroy_namespace) { create(:group) }
      let_it_be(:enabled_namespace_destroy_mixed) do
        create(:zoekt_enabled_namespace, namespace: destroy_namespace, number_of_replicas_override: 1)
      end

      let_it_be(:_destroy_replicas) do
        create_list(:zoekt_replica, 4,
          namespace_id: destroy_namespace.id,
          zoekt_enabled_namespace: enabled_namespace_destroy_mixed
        )
      end

      let_it_be(:unchanged_namespace) { create(:group) }
      let_it_be(:enabled_namespace_unchanged_mixed) do
        create(:zoekt_enabled_namespace, namespace: unchanged_namespace, number_of_replicas_override: 2)
      end

      let_it_be(:_unchanged_replicas) do
        create_list(:zoekt_replica, 2,
          namespace_id: unchanged_namespace.id,
          zoekt_enabled_namespace: enabled_namespace_unchanged_mixed
        )
      end

      subject(:plan) do
        described_class.plan(
          enabled_namespaces: [enabled_namespace_create, enabled_namespace_destroy_mixed,
            enabled_namespace_unchanged_mixed],
          nodes: nodes
        )
      end

      it 'correctly categorizes each namespace by action' do
        expect(plan[:create].size).to eq(1)
        expect(plan[:destroy].size).to eq(1)
        expect(plan[:unchanged].size).to eq(1)

        expect(plan[:create].first[:namespace_id]).to eq(create_namespace.id)
        expect(plan[:destroy].first[:namespace_id]).to eq(destroy_namespace.id)
        expect(plan[:unchanged].first[:namespace_id]).to eq(unchanged_namespace.id)
      end

      it 'only calculates storage for create actions' do
        create_plan = plan[:create].first
        expect(plan[:total_required_storage_bytes]).to eq(create_plan[:namespace_required_storage_bytes])
      end
    end

    context 'when scaling up from existing replicas (partial creation)' do
      let_it_be(:partial_namespace) { create(:group) }
      let_it_be(:enabled_namespace_partial) do
        create(:zoekt_enabled_namespace, namespace: partial_namespace, number_of_replicas_override: 5)
      end

      let_it_be(:partial_projects) do
        create_list(:project, 2, namespace: partial_namespace).each do |project|
          create(:project_statistics, project: project, repository_size: 1.gigabyte)
        end
      end

      let_it_be(:_existing_partial_replicas) do
        create_list(:zoekt_replica, 2,
          namespace_id: partial_namespace.id,
          zoekt_enabled_namespace: enabled_namespace_partial
        )
      end

      subject(:plan) do
        described_class.plan(
          enabled_namespaces: [enabled_namespace_partial],
          nodes: nodes
        )
      end

      it 'creates plan for only the additional replicas needed' do
        create_plan = plan[:create].first

        expect(create_plan[:action]).to eq(:create)
        expect(create_plan[:replicas].size).to eq(3) # 5 desired - 2 existing = 3 to create
      end

      it 'calculates storage only for new replicas' do
        create_plan = plan[:create].first
        per_replica_storage = partial_projects.sum { |p| p.statistics.repository_size * buffer_factor }

        expect(create_plan[:namespace_required_storage_bytes]).to eq(per_replica_storage * 3) # 3 new replicas
      end
    end

    context 'when different namespaces have vastly different replica counts' do
      # Create enough nodes to support the large replica count
      let_it_be(:_extra_nodes) { create_list(:zoekt_node, 4, total_bytes: 100.gigabytes, used_bytes: 10.gigabytes) }
      let_it_be(:all_nodes) { Search::Zoekt::Node.order_by_unclaimed_space_desc.online }

      let_it_be(:small_namespace) { create(:group) }
      let_it_be(:enabled_namespace_small) do
        create(:zoekt_enabled_namespace, namespace: small_namespace, number_of_replicas_override: 1)
      end

      let_it_be(:large_namespace) { create(:group) }
      let_it_be(:enabled_namespace_large) do
        create(:zoekt_enabled_namespace, namespace: large_namespace, number_of_replicas_override: 4)
      end

      let_it_be(:_small_projects) do
        create(:project, namespace: small_namespace,
          statistics: create(:project_statistics, repository_size: 1.gigabyte))
      end

      let_it_be(:_large_projects) do
        create(:project, namespace: large_namespace,
          statistics: create(:project_statistics, repository_size: 500.megabytes))
      end

      subject(:plan) do
        described_class.plan(
          enabled_namespaces: [enabled_namespace_small, enabled_namespace_large],
          nodes: all_nodes
        )
      end

      it 'creates correct number of replicas for each namespace' do
        small_plan = plan[:create].find { |p| p[:namespace_id] == small_namespace.id }
        large_plan = plan[:create].find { |p| p[:namespace_id] == large_namespace.id }

        expect(small_plan[:replicas].size).to eq(1)
        expect(large_plan[:replicas].size).to eq(4)
      end

      it 'calculates storage correctly for each namespace' do
        small_plan = plan[:create].find { |p| p[:namespace_id] == small_namespace.id }
        large_plan = plan[:create].find { |p| p[:namespace_id] == large_namespace.id }

        expected_small = 1.gigabyte * buffer_factor * 1
        expected_large = 500.megabytes * buffer_factor * 4

        expect(small_plan[:namespace_required_storage_bytes]).to eq(expected_small)
        expect(large_plan[:namespace_required_storage_bytes]).to eq(expected_large)
        expect(plan[:total_required_storage_bytes]).to eq(expected_small + expected_large)
      end
    end
  end

  describe 'dynamic buffer factor' do
    let(:dynamic_factor) { 0.72 } # e.g. 0.6 observed ratio * 1.2 safety margin
    let_it_be(:group) { create(:group) }
    let_it_be_with_reload(:enabled_namespace) { create(:zoekt_enabled_namespace, namespace: group) }
    let_it_be(:project) do
      create(:project, namespace: group, statistics: create(:project_statistics, repository_size: 1.gigabyte))
    end

    subject(:plan) { described_class.plan(enabled_namespaces: [enabled_namespace], nodes: nodes) }

    before do
      enabled_namespace.update!(number_of_replicas_override: 1)
      allow(Search::Zoekt::Index).to receive(:global_buffer_factor).and_return(dynamic_factor)
    end

    it 'uses the instance-wide dynamic buffer factor from Index.global_buffer_factor' do
      expected_storage = project.statistics.repository_size * dynamic_factor
      namespace_plan = plan[:create].find { |p| p[:namespace_id] == group.id }
      expect(namespace_plan[:namespace_required_storage_bytes]).to be_within(1).of(expected_storage)
    end

    it 'calls Index.global_buffer_factor once per Plan (memoized)' do
      plan
      # global_buffer_factor is memoized per Plan instance; each enabled_namespace
      # gets its own Plan, so it's called once here.
      expect(Search::Zoekt::Index).to have_received(:global_buffer_factor).once
    end
  end
end
