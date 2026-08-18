# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicIssuePresenter, feature_category: :portfolio_management do
  include Gitlab::Routing.url_helpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be_with_reload(:legacy_epic) { create(:epic, :with_synced_work_item, group: group) }
  let_it_be(:epic_work_item) { legacy_epic.work_item }
  let_it_be_with_reload(:child_issue) { create(:work_item, :issue, project: project) }

  let_it_be_with_reload(:parent_link) do
    create(:parent_link, work_item_parent: epic_work_item, work_item: child_issue, relative_position: 100)
  end

  let_it_be_with_reload(:epic_issue) do
    create(:epic_issue, epic: legacy_epic, issue: child_issue, work_item_parent_link: parent_link)
  end

  let(:target_issue) { ::WorkItems::LegacyEpics::WorkItemAsEpic.new(epic_work_item).epic_issues.first }
  let(:presenter) { described_class.new(target_issue, current_user: user) }

  before_all do
    group.add_guest(user)
  end

  before do
    stub_licensed_features(epics: true)
  end

  describe '#group_epic_issue_path' do
    it 'returns correct path' do
      expect(presenter.group_epic_issue_path(user)).to eq("/groups/#{group.full_path}/-/epics/#{legacy_epic.iid}/issues/#{epic_issue.id}")
    end

    it 'returns nil without proper permission' do
      unauth_user = create(:user)

      expect(presenter.group_epic_issue_path(unauth_user)).to be_nil
    end

    context 'when issue has no parent work item' do
      let(:orphan_issue) { create(:work_item, :issue, project: project) }
      let(:presenter) { described_class.new(orphan_issue, current_user: user) }

      it 'returns nil' do
        expect(presenter.group_epic_issue_path(user)).to be_nil
      end
    end
  end

  describe '#epic_issue_id' do
    it 'returns the epic_issue id from parent_link' do
      expect(presenter.epic_issue_id).to eq(epic_issue.id)
    end

    context 'when epic_issue does not exist on parent_link' do
      let_it_be(:epic_without_legacy) { create(:work_item, :epic, namespace: group) }
      let_it_be(:child_without_epic_issue) { create(:work_item, :issue, project: project) }
      let_it_be(:link_without_epic_issue) do
        create(:parent_link, work_item_parent: epic_without_legacy, work_item: child_without_epic_issue)
      end

      let(:target_issue) do
        ::WorkItems::LegacyEpics::WorkItemAsEpic.new(epic_without_legacy).epic_issues.first
      end

      it 'returns nil' do
        expect(presenter.epic_issue_id).to be_nil
      end
    end
  end
end
