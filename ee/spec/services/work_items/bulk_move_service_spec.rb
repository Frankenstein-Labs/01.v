# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::BulkMoveService, feature_category: :team_planning do
  let_it_be(:source_group) { create(:group) }
  let_it_be(:target_group) { create(:group) }

  let_it_be(:group_level_issue) { create(:work_item, :issue, namespace: source_group) }
  let_it_be(:group_level_epic) { create(:work_item, :epic_with_legacy_epic, namespace: source_group) }

  let(:current_user) { create(:user, :with_namespace, developer_of: [source_group, target_group]) }

  subject(:service_result) do
    described_class.new(
      current_user: current_user,
      work_item_ids: work_item_ids,
      source_namespace: source_group,
      target_namespace: target_group
    ).execute
  end

  describe '#execute' do
    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when work items between groups' do
        let(:work_item_ids) { [group_level_epic.id, group_level_issue.id] }

        it 'successfully moves epic and issue work items' do
          expect(service_result).to be_success
          expect(service_result[:moved_work_item_count]).to eq(2)
        end
      end
    end

    context 'when epics are disabled' do
      before do
        stub_licensed_features(epics: false)
      end

      context 'when moving work items between groups' do
        let(:work_item_ids) { [group_level_epic.id, group_level_issue.id] }

        it 'does not move epic and raises an appropriate error' do
          expect(service_result).to be_error
          expect(service_result[:moved_work_item_count]).to eq(0)
          expect(service_result[:message]).to eq('You do not have permission to move items to this namespace.')
        end
      end
    end
  end
end
