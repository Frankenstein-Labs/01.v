# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::CleanOldNamespaceConnectionsWorker, feature_category: :security_testing_configuration do
  let_it_be(:group) { create(:group) }
  let(:group_id) { group.id }
  let(:traverse_hierarchy) { true }
  let(:delete_service) { Security::ScanProfiles::CleanOldNamespaceConnectionsService }

  subject(:perform_worker) { described_class.new.perform(group_id, traverse_hierarchy) }

  describe '#perform' do
    before do
      allow(delete_service).to receive(:execute)
    end

    it 'calls CleanOldNamespaceConnectionsService with default parameters' do
      perform_worker

      expect(delete_service).to have_received(:execute).with(group_id, true)
    end

    context 'with traverse_hierarchy set to false' do
      let(:traverse_hierarchy) { false }

      it 'calls CleanOldNamespaceConnectionsService with correct parameters' do
        perform_worker

        expect(delete_service).to have_received(:execute).with(group_id, false)
      end
    end

    context 'when group_id is nil' do
      let(:group_id) { nil }

      it 'exits gracefully without raising an error' do
        expect { perform_worker }.not_to raise_error
      end

      it 'does not call the service' do
        perform_worker

        expect(delete_service).not_to have_received(:execute)
      end
    end
  end
end
