# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzersStatus::UpdateGroupAncestorsStatusesService, feature_category: :security_asset_inventories do
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
    let!(:child_group) { create(:group, parent: original_parent_group) }

    let!(:root_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: root_group,
        analyzer_type: 'sast',
        success: 2,
        failure: 1)
    end

    let!(:original_parent_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: original_parent_group,
        analyzer_type: 'sast',
        success: 2,
        failure: 1)
    end

    let!(:root_sast_iac_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: root_group,
        analyzer_type: 'sast_iac',
        stale: 1)
    end

    let!(:original_parent_sast_iac_analyzer_status) do
      create(:analyzer_namespace_status,
        namespace: original_parent_group,
        analyzer_type: 'sast_iac',
        stale: 1)
    end

    let(:service) { described_class.new(child_group) }

    subject(:update_ancestors) { service.execute }

    context 'when there are no analyzer statuses for the lower level group' do
      before do
        child_group.update!(parent: new_parent_group)
      end

      it 'doesnt decrease statuses from original ancestors or increase for new ancestors' do
        expect { update_ancestors }
          .to not_change { Security::AnalyzerNamespaceStatus.count }
          .and not_change { original_parent_analyzer_status.reload.success }
          .and not_change { original_parent_analyzer_status.reload.failure }
          .and not_change { root_analyzer_status.reload }

        new_parent_status = Security::AnalyzerNamespaceStatus.find_by(namespace_id: new_parent_group.id)
        expect(new_parent_status).to be_nil
      end
    end

    context 'when there are analyzer statuses' do
      let!(:child_analyzer_status) do
        create(:analyzer_namespace_status,
          namespace: child_group,
          analyzer_type: 'sast',
          success: 2,
          failure: 1)
      end

      let!(:child_sast_iac_analyzer_status) do
        create(:analyzer_namespace_status,
          namespace: child_group,
          analyzer_type: 'sast_iac',
          stale: 1)
      end

      before do
        child_group.update!(parent: new_parent_group)
      end

      it 'decreases statuses from original ancestors and increases new ancestors' do
        child_group.update!(parent: new_parent_group)
        original = original_parent_analyzer_status
        original_sast_iac = original_parent_sast_iac_analyzer_status

        expect { update_ancestors }
          .to change { Security::AnalyzerNamespaceStatus.count }.by(2)
          .and change { original_parent_analyzer_status.reload.success }.from(original.success).to(0)
          .and change { original_parent_analyzer_status.reload.failure }.from(original.failure).to(0)
          .and change { original_parent_sast_iac_analyzer_status.reload.stale }.from(original_sast_iac.stale).to(0)
          .and not_change { root_analyzer_status.reload }
          .and not_change { root_sast_iac_analyzer_status.reload }

        new_parent_status = Security::AnalyzerNamespaceStatus
                              .find_by(namespace_id: new_parent_group.id, analyzer_type: 'sast')
        new_parent_sast_iac_status = Security::AnalyzerNamespaceStatus
                                       .find_by(namespace_id: new_parent_group.id, analyzer_type: 'sast_iac')

        expect(new_parent_status&.success).to eq(2)
        expect(new_parent_status.failure).to eq(1)
        expect(new_parent_sast_iac_status&.stale).to eq(1)
      end

      it 'updates analyzer status traversal_ids' do
        original_traversal_ids = child_analyzer_status.traversal_ids
        expected_new_traversal_ids = [root_group.id, new_parent_group.id, child_group.id]

        child_group.update!(parent: new_parent_group)

        expect { update_ancestors }
          .to change { child_analyzer_status.reload.traversal_ids }
          .from(original_traversal_ids)
          .to(expected_new_traversal_ids)
      end
    end
  end
end
