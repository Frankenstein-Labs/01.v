# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::RoutingService, feature_category: :global_search do
  let(:service) { described_class.new(projects) }

  let_it_be(:ns_1) { create(:namespace) }
  let_it_be(:ns_2) { create(:namespace) }

  let_it_be(:project_1) { create(:project, namespace: ns_1) }
  let_it_be(:project_2) { create(:project, namespace: ns_2) }
  let_it_be(:project_3) { create(:project, namespace: ns_2) }
  let_it_be(:_project_4) { create(:project, namespace: ns_2) }

  let(:projects) { Project.where(id: [project_1.id, project_2.id, project_3.id]) }

  subject(:execute_task) { service.execute }

  describe '.execute' do
    it 'executes the task' do
      expect(described_class).to receive(:new).with(projects).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(projects)
    end
  end

  describe '#execute' do
    let_it_be(:node_1) { create(:zoekt_node, :enough_free_space) }
    let_it_be(:node_2) { create(:zoekt_node, :enough_free_space) }
    let_it_be(:node_3) { create(:zoekt_node, :enough_free_space) }

    let_it_be(:zoekt_enabled_namespace_1) { create(:zoekt_enabled_namespace, namespace: ns_1) }
    let_it_be(:zoekt_enabled_namespace_2) { create(:zoekt_enabled_namespace, namespace: ns_2) }

    let_it_be(:zoekt_replica_1) do
      create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace_1, state: :ready)
    end

    let_it_be(:zoekt_replica_2) do
      create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace_2, state: :ready)
    end

    let_it_be(:zoekt_replica_3) do
      create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace_2, state: :ready)
    end

    # Indices attached to this pending replica should be excluded
    let_it_be(:zoekt_replica_4) do
      create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace_2, state: :pending)
    end

    let_it_be(:zoekt_index_1_on_node_1) do
      create(:zoekt_index, replica: zoekt_replica_1, zoekt_enabled_namespace: zoekt_enabled_namespace_1, node: node_1,
        state: :ready)
    end

    let_it_be(:zoekt_index_2_on_node_2) do
      create(:zoekt_index, replica: zoekt_replica_2, zoekt_enabled_namespace: zoekt_enabled_namespace_2, node: node_2,
        state: :ready)
    end

    let_it_be(:zoekt_index_3_on_node_1) do
      create(:zoekt_index, replica: zoekt_replica_3, zoekt_enabled_namespace: zoekt_enabled_namespace_2, node: node_1,
        state: :ready)
    end

    let_it_be(:zoekt_index_4_on_node_3) do
      create(:zoekt_index, replica: zoekt_replica_4, zoekt_enabled_namespace: zoekt_enabled_namespace_2, node: node_3,
        state: :ready)
    end

    let_it_be(:zoekt_repo_project_1_on_index_1_on_node_1) do
      create(:zoekt_repository, state: :ready, project: project_1, zoekt_index: zoekt_index_1_on_node_1)
    end

    let_it_be(:zoekt_repo_project_2_on_index_2_on_node_2) do
      create(:zoekt_repository, state: :ready, project: project_2, zoekt_index: zoekt_index_2_on_node_2)
    end

    let_it_be(:zoekt_repo_project_3_on_index_3_on_node_1) do
      create(:zoekt_repository, state: :ready, project: project_3, zoekt_index: zoekt_index_3_on_node_1)
    end

    it 'returns correct map' do
      expect(execute_task).to eq(
        {
          node_1.id => [project_1.id, project_3.id],
          node_2.id => [project_2.id]
        })
    end

    context 'when nodes are offline' do
      let_it_be(:offline_only_project) { create(:project, namespace: ns_1) }

      before_all do
        offline_node = create(:zoekt_node, :offline)
        offline_zoekt_replica = create(:zoekt_replica,
          zoekt_enabled_namespace: zoekt_enabled_namespace_1, state: :ready)
        offline_zoekt_index = create(:zoekt_index,
          replica: offline_zoekt_replica,
          zoekt_enabled_namespace: zoekt_enabled_namespace_1,
          node: offline_node, state: :ready)
        create(:zoekt_repository, state: :ready, project: offline_only_project, zoekt_index: offline_zoekt_index)
      end

      it 'excludes projects that only exist on offline nodes' do
        projects_with_offline = Project.where(id: [
          project_1.id, project_2.id, project_3.id, offline_only_project.id
        ])
        service_with_offline = described_class.new(projects_with_offline)
        result = service_with_offline.execute

        # Should not include the offline_only_project since it's only on an offline node
        expect(result).to eq(
          {
            node_1.id => [project_1.id, project_3.id],
            node_2.id => [project_2.id]
          })
        expect(result.values.flatten).not_to include(offline_only_project.id)
      end
    end
  end
end
