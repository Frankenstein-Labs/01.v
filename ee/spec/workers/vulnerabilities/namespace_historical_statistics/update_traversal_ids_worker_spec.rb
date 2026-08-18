# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceHistoricalStatistics::UpdateTraversalIdsWorker, feature_category: :vulnerability_management do
  let(:worker) { described_class.new }

  describe '#perform' do
    let(:service_layer_logic) { Vulnerabilities::NamespaceHistoricalStatistics::UpdateTraversalIdsService }

    before do
      allow(service_layer_logic).to receive(:execute)
    end

    context 'when there is no group with the given group ID' do
      it 'does not call the service layer logic' do
        worker.perform(non_existing_record_id)

        expect(service_layer_logic).not_to have_received(:execute)
      end
    end

    context 'when there is a group with the given group ID' do
      let(:group) { create(:group) }

      it 'calls the service layer logic' do
        worker.perform(group.id)

        expect(service_layer_logic).to have_received(:execute).with(group)
      end
    end
  end
end
