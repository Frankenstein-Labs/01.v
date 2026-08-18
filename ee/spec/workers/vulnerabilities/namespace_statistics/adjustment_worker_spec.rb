# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::AdjustmentWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }

  describe '#perform' do
    let(:namespace_ids) { [1, 2, 3] }

    before do
      allow(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:execute)
    end

    it 'calls Vulnerabilities::NamespaceStatistics::AdjustmentService with given namespace_ids' do
      worker.perform(namespace_ids)
      expect(Vulnerabilities::NamespaceStatistics::AdjustmentService).to have_received(:execute).with(namespace_ids)
    end

    context 'when namespace_ids is empty' do
      let(:namespace_ids) { [] }

      it 'doesnt call Vulnerabilities::NamespaceStatistics::AdjustmentService' do
        worker.perform(namespace_ids)
        expect(Vulnerabilities::NamespaceStatistics::AdjustmentService).not_to have_received(:execute)
      end
    end
  end
end
