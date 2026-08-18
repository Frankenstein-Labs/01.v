# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::UpdateNamespaceTraversalIdsService, feature_category: :security_asset_inventories do
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
    let_it_be(:parent_analyzer_status) { create(:analyzer_namespace_status, namespace: parent_group) }
    let_it_be(:child_analyzer_status) { create(:analyzer_namespace_status, namespace: child_group) }

    subject(:update_traversal_ids) { described_class.execute(parent_group) }

    before do
      parent_group.update!(traversal_ids: [non_existing_record_id])
      child_group.update!(traversal_ids: [non_existing_record_id, child_group.id])
    end

    it 'updates analyzer statuses for group and descendants' do
      expect { update_traversal_ids }
        .to change { parent_analyzer_status.reload.traversal_ids }.to([non_existing_record_id])
        .and change { child_analyzer_status.reload.traversal_ids }.to([non_existing_record_id, child_group.id])
    end
  end
end
