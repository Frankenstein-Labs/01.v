# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::UpdateTraversalIdsService, feature_category: :security_asset_inventories do
  describe '.execute' do
    it 'instantiates a new service object and calls execute' do
      expect_next_instance_of(described_class, :group) do |instance|
        expect(instance).to receive(:execute)
      end

      described_class.execute(:group)
    end
  end

  describe '#execute' do
    let_it_be_with_reload(:parent_group) { create(:group) }
    let_it_be_with_reload(:child_group) { create(:group, parent: parent_group) }
    let_it_be(:parent_statistic) { create(:vulnerability_namespace_statistic, namespace: parent_group) }
    let_it_be(:child_statistic) { create(:vulnerability_namespace_statistic, namespace: child_group) }

    let(:service_object) { described_class.new(parent_group) }

    subject(:update_traversal_ids) { service_object.execute }

    before do
      parent_group.update!(traversal_ids: [non_existing_record_id])
      child_group.update!(traversal_ids: [non_existing_record_id, child_group.id])
    end

    it 'updates statistics for group and descendants' do
      expect { update_traversal_ids }.to change { parent_statistic.reload.traversal_ids }.to([non_existing_record_id])
        .and change { child_statistic.reload.traversal_ids }.to([non_existing_record_id, child_group.id])
    end

    describe 'parallel execution' do
      include ExclusiveLeaseHelpers

      let(:lease_key) { "namespaces:#{parent_group.id}:update_namespace_statistics_traversal_ids" }
      let(:lease_ttl) { 5.minutes }

      before do
        stub_const("#{described_class}::LEASE_TRY_AFTER", 0.001)
        stub_exclusive_lease_taken(lease_key, timeout: lease_ttl)
      end

      it 'does not permit parallel execution of the logic' do
        expect { update_traversal_ids }.to raise_error(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
          .and not_change { parent_statistic.reload.traversal_ids }.from([parent_group.id])
      end
    end
  end
end
