# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ReplicaStateService, feature_category: :global_search do
  subject(:service) { described_class.new }

  let_it_be_with_reload(:replica) { create(:zoekt_replica) }
  let_it_be(:enabled_namespace) { replica.zoekt_enabled_namespace }
  let_it_be(:node_1) { create(:zoekt_node) }
  let_it_be(:node_2) { create(:zoekt_node) }
  let_it_be_with_reload(:idx_1) do
    create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, node: node_1, replica: replica)
  end

  let_it_be_with_reload(:idx_2) do
    create(:zoekt_index, zoekt_enabled_namespace: enabled_namespace, node: node_2, replica: replica)
  end

  describe '.execute' do
    let(:replica_state_service) { instance_double(::Search::Zoekt::ReplicaStateService) }

    it 'delegates to a new instance' do
      expect(described_class).to receive(:new).and_return(replica_state_service)
      expect(replica_state_service).to receive(:execute)

      described_class.execute
    end
  end

  describe '#execute' do
    context 'when all the indices for a replica are marked as ready' do
      before do
        replica.indices.update_all(state: :ready)
      end

      it 'marks the replica as ready' do
        replica.pending!
        expect { service.execute }.to change { replica.reload.state }.from('pending').to('ready')
      end
    end

    context 'when one of the indices for the replica is not ready' do
      before do
        idx_1.ready!
        idx_2.pending!
      end

      it 'marks the replica as pending' do
        replica.ready!
        expect { service.execute }.to change { replica.reload.state }.from('ready').to('pending')
      end
    end
  end
end
