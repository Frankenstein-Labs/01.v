# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Statistics::AdjustmentWorker, feature_category: :vulnerability_management do
  let(:worker) { described_class.new }

  describe "#perform" do
    let(:project_ids) { [1, 2, 3] }
    let(:diffs) { [{ 'namespace_id' => 1, 'total' => 5 }] }
    let(:affected_project_ids) { [1, 3] }
    let(:adjustment_result) { { diff: diffs, affected_project_ids: affected_project_ids } }

    before do
      allow(Vulnerabilities::Statistics::AdjustmentService).to receive(:execute).and_return(adjustment_result)
      allow(Security::InventoryFilters::VulnerabilityStatisticsSyncService).to receive(:execute)
      allow(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)
      allow(Vulnerabilities::HistoricalStatistics::AdjustmentService).to receive(:execute).and_return([1, 2])
      allow(Vulnerabilities::NamespaceHistoricalStatistics::AdjustmentService).to receive(:execute)
    end

    it 'calls `Vulnerabilities::Statistics::AdjustmentService` with given project_ids' do
      worker.perform(project_ids)

      expect(Vulnerabilities::Statistics::AdjustmentService).to have_received(:execute).with(project_ids)
    end

    it 'calls `Vulnerabilities::NamespaceStatistics::UpdateService` with diffs from AdjustmentService' do
      worker.perform(project_ids)

      expect(Vulnerabilities::NamespaceStatistics::UpdateService).to have_received(:execute).with(diffs)
    end

    it 'calls `Security::InventoryFilters::VulnerabilityStatisticsSyncService` ids output from AdjustmentService' do
      worker.perform(project_ids)

      expect(Security::InventoryFilters::VulnerabilityStatisticsSyncService)
        .to have_received(:execute).with(affected_project_ids)
    end

    it 'calls `Vulnerabilities::HistoricalStatistics::AdjustmentService` with given project_ids' do
      worker.perform(project_ids)

      expect(Vulnerabilities::HistoricalStatistics::AdjustmentService).to have_received(:execute).with(project_ids)
    end

    it 'calls `Vulnerabilities::NamespaceHistoricalStatistics::AdjustmentService` with returned project_ids' do
      worker.perform(project_ids)

      expect(Vulnerabilities::NamespaceHistoricalStatistics::AdjustmentService).to have_received(:execute).with([1, 2])
    end
  end

  it_behaves_like 'statistics filtered by tracked context'
end
