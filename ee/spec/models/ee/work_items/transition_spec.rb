# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::Transition, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:epic) { create(:epic, group: group) }

  describe 'associations' do
    it { is_expected.to belong_to(:promoted_to_epic).class_name('Epic') }
  end

  describe '#promoted?' do
    subject { work_item_transition.promoted? }

    context 'when promoted to epic' do
      let(:work_item_transition) { build(:work_item_transition, promoted_to_epic: epic) }

      it { is_expected.to be_truthy }
    end

    context 'when not promoted to epic' do
      let(:work_item_transition) { build(:work_item_transition) }

      it { is_expected.to be_falsey }
    end
  end

  # Syncing via `trigger_sync_issues_dates_with_work_item_dates_sources`
  describe 'syncs to work_item_transition from issue' do
    it 'syncs promoted_to_epic_id' do
      work_item = create(:work_item, :issue, project: project, promoted_to_epic: epic)

      expect(work_item.work_item_transition.promoted_to_epic).to eq(epic)

      work_item.update!(promoted_to_epic: nil)

      expect(work_item.reload.work_item_transition.promoted_to_epic).to be_nil
    end
  end
end
