# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::RecalculateService, feature_category: :security_asset_inventories do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :group) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:group)
    end
  end

  describe '#execute' do
    let_it_be(:grandparent_group) { create(:group) }
    let_it_be(:parent_group) { create(:group, parent: grandparent_group) }
    let_it_be(:child_group) { create(:group, parent: parent_group) }

    context 'when group is missing' do
      subject(:recalculate) { described_class.new(nil).execute }

      it 'returns early without executing update logic' do
        expect(Vulnerabilities::NamespaceStatistics::AdjustmentService).not_to receive(:new)
        expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)

        recalculate
      end
    end

    context 'when group is present' do
      let(:adjustment_service) { instance_double(Vulnerabilities::NamespaceStatistics::AdjustmentService) }

      subject(:recalculate) { described_class.new(child_group).execute }

      before do
        allow(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)
        allow(adjustment_service).to receive(:execute).and_return(namespace_diffs)
        allow(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new)
          .with([child_group.id]).and_return(adjustment_service)
      end

      context 'when namespace_diffs contains a valid entry with multiple traversal_ids' do
        let(:statistics) do
          {
            'total' => 4,
            'critical' => 2,
            'high' => -2,
            'medium' => 1,
            'low' => 1,
            'info' => -1,
            'unknown' => 0
          }
        end

        let(:namespace_diffs) do
          [
            {
              'namespace_id' => child_group.id,
              'traversal_ids' => "{#{grandparent_group.id},#{parent_group.id},#{child_group.id}}"
            }.merge(statistics)
          ]
        end

        it 'recalculates group statistics and propagates changes to ancestors' do
          expected_ancestor_diff = {
            'namespace_id' => parent_group.id,
            'traversal_ids' => "{#{grandparent_group.id},#{parent_group.id}}"
          }.merge(statistics)

          expect(Vulnerabilities::NamespaceStatistics::AdjustmentService).to receive(:new).with([child_group.id])
          expect(Vulnerabilities::NamespaceStatistics::UpdateService).to receive(:execute)
            .with([expected_ancestor_diff])

          recalculate
        end
      end

      context 'when namespace_diffs is empty' do
        let(:namespace_diffs) { [] }

        it 'does not call UpdateService' do
          expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)

          recalculate
        end
      end

      context 'when namespace_diffs has more than one entry' do
        let(:namespace_diffs) { [{ 'namespace_id' => 1 }, { 'namespace_id' => 2 }] }

        it 'does not call UpdateService' do
          expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)

          recalculate
        end
      end

      context 'when traversal_ids array has only one element' do
        let(:namespace_diffs) { [{ 'namespace_id' => child_group.id, 'traversal_ids' => "{#{child_group.id}}" }] }

        it 'does not call UpdateService as there are no ancestors' do
          expect(Vulnerabilities::NamespaceStatistics::UpdateService).not_to receive(:execute)

          recalculate
        end
      end
    end
  end
end
