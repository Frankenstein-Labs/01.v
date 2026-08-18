# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::UpdateGroupAncestorsStatisticsService, feature_category: :security_asset_inventories do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :group) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:group)
    end
  end

  describe '#execute' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:original_parent_group) { create(:group, parent: root_group) }
    let_it_be(:new_parent_group) { create(:group, parent: root_group) }
    let_it_be(:root_statistic) do
      create(:vulnerability_namespace_statistic, namespace: root_group, total: 4, critical: 3, low: 1)
    end

    let_it_be(:original_parent_statistic) do
      create(:vulnerability_namespace_statistic, namespace: original_parent_group, total: 4, critical: 3, low: 1)
    end

    let(:service_object) { described_class.new(child_group) }

    subject(:update_ancestors) { service_object.execute }

    context 'when there is no group statistics record' do
      let_it_be_with_reload(:child_group) { create(:group, parent: original_parent_group) }

      it 'doesnt decrease statistics from original ancestors or increase for new ancestors' do
        child_group.update!(parent: new_parent_group)

        expect { update_ancestors }
          .to not_change { Vulnerabilities::NamespaceStatistic.count }
          .and not_change { original_parent_statistic.reload.total }
          .and not_change { original_parent_statistic.reload.critical }
          .and not_change { original_parent_statistic.reload.low }
          .and not_change { root_statistic.reload }

        new_parent_statistics = Vulnerabilities::NamespaceStatistic.find_by(namespace_id: new_parent_group.id)

        expect(new_parent_statistics).to be_nil
      end
    end

    context 'when there is a group statistics record' do
      let!(:child_group) { create(:group, parent: original_parent_group) }
      let!(:child_statistic) do
        create(:vulnerability_namespace_statistic, namespace: child_group, total: 4, critical: 3, low: 1)
      end

      it 'decreases statistics from original ancestors and increases new ancestors' do
        child_group.update!(parent: new_parent_group)
        original = original_parent_statistic

        expect { update_ancestors }
          .to change { Vulnerabilities::NamespaceStatistic.count }.by(1)
          .and change { original_parent_statistic.reload.total }.from(original.total).to(0)
          .and change { original_parent_statistic.reload.critical }.from(original.critical).to(0)
          .and change { original_parent_statistic.reload.low }.from(original.low).to(0)
          .and not_change { root_statistic.reload }

        new_parent_statistics = Vulnerabilities::NamespaceStatistic.find_by(namespace_id: new_parent_group.id)

        expect(new_parent_statistics&.total).to eq(4)
        expect(new_parent_statistics.critical).to eq(3)
        expect(new_parent_statistics.low).to eq(1)
      end

      it 'update groups statistic traversal_ids' do
        original_traversal_ids = child_statistic.traversal_ids
        expected_new_traversal_ids = [root_group.id, new_parent_group.id, child_group.id]

        child_group.update!(parent: new_parent_group)

        expect { update_ancestors }
          .to change { child_statistic.reload.traversal_ids }
          .from(original_traversal_ids)
          .to(expected_new_traversal_ids)
      end
    end
  end
end
