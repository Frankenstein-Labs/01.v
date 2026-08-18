# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Zoekt::Router, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be_with_reload(:zoekt_replica) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
  let_it_be(:project_1) { create(:project, namespace: namespace) }
  let_it_be(:project_2) { create(:project, namespace: namespace) }
  let_it_be(:zoekt_node_1) { create(:zoekt_node) }
  let_it_be(:zoekt_node_2) { create(:zoekt_node) }

  let_it_be(:zoekt_index_1) do
    create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace,
      reserved_storage_bytes: 100, node: zoekt_node_1)
  end

  let_it_be(:zoekt_index_2) do
    create(:zoekt_index, replica: zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace,
      reserved_storage_bytes: 10, node: zoekt_node_2)
  end

  describe '.fetch_indices_for_indexing' do
    let(:result) { described_class.fetch_indices_for_indexing(project_1.id, root_namespace_id: namespace.id) }

    context 'when a zoekt repository exists already for a project' do
      let_it_be(:zoekt_repo) do
        create(:zoekt_repository, project: project_1, zoekt_index: zoekt_index_1, state: :ready)
      end

      it 'includes the index that is associated with that zoekt repository' do
        expect(::Search::Zoekt::Index).to receive(:where).with(id: [zoekt_index_1.id]).and_call_original
        expect(result).to match_array([zoekt_index_1])
      end
    end

    context 'when a zoekt repository does not exist for that project yet' do
      it 'includes the index that has the most amount of free storage bytes' do
        allow(zoekt_index_1).to receive(:free_storage_bytes).and_return(100.gigabytes)
        allow(zoekt_index_2).to receive(:free_storage_bytes).and_return(20.gigabytes)
        expect(::Search::Zoekt::Index).to receive(:where).with(id: [zoekt_index_1.id]).and_call_original
        expect(result).to contain_exactly(zoekt_index_1)
      end
    end

    context 'when a replica does not have any indices yet' do
      let(:result) do
        described_class.fetch_indices_for_indexing(another_project.id, root_namespace_id: another_namespace.id)
      end

      let_it_be(:another_namespace) { create(:group) }
      let_it_be(:another_project) { create(:project, namespace: another_namespace) }
      let_it_be(:another_zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: another_namespace) }
      let_it_be(:replica) { create(:zoekt_replica, zoekt_enabled_namespace: another_zoekt_enabled_namespace) }

      it 'returns an empty collection' do
        expect(replica.fetch_repositories_with_project_identifier(another_project.id)).to be_empty
        expect(replica.indices).to be_empty

        expect(result).to be_empty
      end
    end
  end

  describe '.fetch_nodes_for_indexing' do
    let(:result) do
      described_class.fetch_nodes_for_indexing(project_1.id, root_namespace_id: namespace.id, node_ids: node_ids)
    end

    context 'when node ids are specified' do
      let(:node_ids) { [zoekt_node_1.id, zoekt_node_2.id] }

      it 'fetches the requested node objects' do
        expect(result).to match_array([zoekt_node_1, zoekt_node_2])
      end
    end

    context 'when node ids are not specified' do
      let(:node_ids) { [] }

      it 'returns nodes that are associated with relevant zoekt indices' do
        expect(described_class).to receive(:fetch_indices_for_indexing).with(project_1.id,
          root_namespace_id: namespace.id)
          .and_return(Search::Zoekt::Index.where(id: zoekt_node_1.indices.select(:id)))

        expect(result).to match_array([zoekt_node_1])
      end
    end
  end
end
