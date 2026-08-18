# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::WorkItemAsEpic, feature_category: :portfolio_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:parent_epic) { create(:epic, group: group) }
  let_it_be_with_reload(:epic) { create(:epic, group: group, parent: parent_epic) }
  let_it_be_with_reload(:work_item) { epic.work_item }

  subject(:adapter) { described_class.new(work_item) }

  describe '#initialize' do
    it 'accepts a work item' do
      expect(adapter.work_item).to eq(work_item)
    end
  end

  describe 'core attributes' do
    let_it_be(:author) { create(:user) }
    let_it_be(:epic_with_attributes) do
      epic = create(:epic,
        group: group,
        title: 'Epic Title',
        description: 'Epic Description',
        state: :closed,
        author: author,
        confidential: true,
        created_at: Time.zone.parse('2022-01-01 10:00:00'),
        updated_at: Time.zone.parse('2022-01-10 15:30:00'))

      epic.work_item.update!(
        closed_at: Time.zone.parse('2022-01-15 12:00:00'),
        imported_from: 'github'
      )

      epic
    end

    let_it_be(:work_item_with_attributes) { epic_with_attributes.work_item }

    subject(:adapter) { described_class.new(work_item_with_attributes) }

    describe '#id' do
      it 'returns epic id' do
        expect(adapter.id).to eq(epic_with_attributes.id)
      end
    end

    describe '#work_item_id' do
      it 'returns work item id' do
        expect(adapter.work_item_id).to eq(work_item_with_attributes.id)
      end
    end

    describe '#iid' do
      it 'returns work item iid' do
        expect(adapter.iid).to eq(work_item_with_attributes.iid)
      end
    end

    describe '#title' do
      it 'returns work item title' do
        expect(adapter.title).to eq('Epic Title')
      end
    end

    describe '#description' do
      it 'returns work item description' do
        expect(adapter.description).to eq('Epic Description')
      end
    end

    describe '#state' do
      it 'returns work item state' do
        expect(adapter.state).to eq('closed')
      end
    end

    describe '#author' do
      it 'returns work item author' do
        expect(adapter.author).to eq(author)
      end
    end

    describe '#created_at' do
      it 'returns work item created_at' do
        expect(adapter.created_at).to eq(Time.zone.parse('2022-01-01 10:00:00'))
      end
    end

    describe '#updated_at' do
      it 'returns work item updated_at' do
        expect(adapter.updated_at).to eq(work_item_with_attributes.updated_at)
      end
    end

    describe '#closed_at' do
      it 'returns work item closed_at' do
        expect(adapter.closed_at).to eq(Time.zone.parse('2022-01-15 12:00:00'))
      end
    end

    describe '#confidential' do
      it 'returns work item confidential' do
        expect(adapter.confidential).to be(true)
      end
    end

    describe '#confidential?' do
      it 'returns work item confidential' do
        expect(adapter.confidential?).to be(true)
      end
    end

    describe '#lock_version' do
      it 'returns work item lock_version' do
        expect(adapter.lock_version).to eq(work_item_with_attributes.lock_version)
      end
    end

    describe '#imported?' do
      it 'returns work item imported?' do
        expect(adapter.imported?).to be(true)
      end
    end

    describe '#imported_from' do
      it 'returns work item imported_from' do
        expect(adapter.imported_from).to eq('github')
      end
    end

    describe '#labels' do
      let_it_be(:label1) { create(:group_label, group: group, title: 'Label 1') }
      let_it_be(:label2) { create(:group_label, group: group, title: 'Label 2') }
      let_it_be(:epic_with_labels) { create(:epic, group: group, labels: [label1, label2]) }
      let_it_be(:work_item_with_labels) { epic_with_labels.work_item }

      subject(:adapter) { described_class.new(work_item_with_labels) }

      it 'returns work item labels' do
        expect(adapter.labels).to match_array([label1, label2])
      end
    end
  end

  describe 'color attributes' do
    context 'when work item has color' do
      let_it_be(:color) { create(:color, work_item: work_item, color: '#0052cc') }

      describe '#color' do
        it 'returns color as string' do
          expect(adapter.color).to eq('#0052cc')
        end
      end

      describe '#text_color' do
        it 'returns text color as string' do
          expect(adapter.text_color).to eq('#FFFFFF')
        end
      end
    end

    context 'when work item has no color' do
      describe '#color' do
        it 'returns empty string' do
          expect(adapter.color).to eq('')
        end
      end

      describe '#text_color' do
        it 'returns empty string' do
          expect(adapter.text_color).to eq('')
        end
      end
    end
  end

  describe 'namespace/group attributes' do
    describe '#group_id' do
      it 'returns work item namespace_id' do
        expect(adapter.group_id).to eq(group.id)
      end
    end

    describe '#group' do
      it 'returns work item namespace' do
        expect(adapter.group).to eq(group)
      end
    end
  end

  describe 'date attributes' do
    let_it_be(:epic_with_dates) do
      epic = create(:epic, group: group)
      epic.work_item.update!(
        start_date: Date.new(2022, 1, 1),
        due_date: Date.new(2022, 12, 31)
      )
      epic
    end

    let_it_be(:work_item_with_dates) { epic_with_dates.work_item }

    subject(:adapter) { described_class.new(work_item_with_dates) }

    describe '#start_date' do
      it 'returns start_date from widget' do
        expect(adapter.start_date).to eq(Date.new(2022, 1, 1))
      end
    end

    describe '#start_date_fixed' do
      it 'returns same as start_date' do
        expect(adapter.start_date_fixed).to eq(Date.new(2022, 1, 1))
      end
    end

    describe '#start_date_is_fixed?' do
      it 'returns false for inherited dates' do
        expect(adapter.start_date_is_fixed?).to be(false)
      end
    end

    describe '#start_date_from_inherited_source' do
      it 'returns start_date as iso8601 string' do
        expect(adapter.start_date_from_inherited_source).to eq(Date.new(2022, 1, 1).to_time.iso8601)
      end
    end

    describe '#start_date_from_milestones' do
      it 'returns same as start_date_from_inherited_source' do
        expect(adapter.start_date_from_milestones).to eq(Date.new(2022, 1, 1).to_time.iso8601)
      end
    end

    describe '#due_date' do
      it 'returns due_date from widget' do
        expect(adapter.due_date).to eq(Date.new(2022, 12, 31))
      end
    end

    describe '#due_date_fixed' do
      it 'returns same as due_date' do
        expect(adapter.due_date_fixed).to eq(Date.new(2022, 12, 31))
      end
    end

    describe '#due_date_is_fixed?' do
      it 'returns false for inherited dates' do
        expect(adapter.due_date_is_fixed?).to be(false)
      end
    end

    describe '#due_date_from_inherited_source' do
      it 'returns due_date as iso8601 string' do
        expect(adapter.due_date_from_inherited_source).to eq(Date.new(2022, 12, 31).to_time.iso8601)
      end
    end

    describe '#due_date_from_milestones' do
      it 'returns same as due_date_from_inherited_source' do
        expect(adapter.due_date_from_milestones).to eq(Date.new(2022, 12, 31).to_time.iso8601)
      end
    end
  end

  describe 'parent relationship attributes' do
    describe '#parent_id' do
      it 'returns parent epic id' do
        expect(adapter.parent_id).to eq(parent_epic.id)
      end

      context 'when epic has no parent' do
        let_it_be(:epic_without_parent) { create(:epic, group: group) }
        let_it_be(:work_item_without_parent) { epic_without_parent.work_item }

        subject(:adapter) { described_class.new(work_item_without_parent) }

        it 'returns nil' do
          expect(adapter.parent_id).to be_nil
        end
      end
    end

    describe '#parent_iid' do
      it 'returns parent work item iid' do
        expect(adapter.parent_iid).to eq(parent_epic.iid)
      end

      context 'when epic has no parent' do
        let_it_be(:epic_without_parent) { create(:epic, group: group) }
        let_it_be(:work_item_without_parent) { epic_without_parent.work_item }

        subject(:adapter) { described_class.new(work_item_without_parent) }

        it 'returns nil' do
          expect(adapter.parent_iid).to be_nil
        end
      end
    end

    describe '#parent' do
      it 'returns parent epic' do
        expect(adapter.parent).to eq(parent_epic)
      end

      context 'when epic has no parent' do
        let_it_be(:epic_without_parent) { create(:epic, group: group) }
        let_it_be(:work_item_without_parent) { epic_without_parent.work_item }

        subject(:adapter) { described_class.new(work_item_without_parent) }

        it 'returns nil' do
          expect(adapter.parent).to be_nil
        end
      end
    end

    describe '#has_parent?' do
      it 'returns true when parent exists' do
        expect(adapter.has_parent?).to be(true)
      end

      context 'when epic has no parent' do
        let_it_be(:epic_without_parent) { create(:epic, group: group) }
        let_it_be(:work_item_without_parent) { epic_without_parent.work_item }

        subject(:adapter) { described_class.new(work_item_without_parent) }

        it 'returns false' do
          expect(adapter.has_parent?).to be(false)
        end
      end
    end

    describe '#work_item_parent_link_id' do
      it 'returns epic work_item_parent_link_id' do
        expect(adapter.work_item_parent_link_id).to eq(epic.work_item_parent_link_id)
      end

      context 'when epic has no parent' do
        let_it_be(:epic_without_parent) { create(:epic, group: group) }
        let_it_be(:work_item_without_parent) { epic_without_parent.work_item }

        subject(:adapter) { described_class.new(work_item_without_parent) }

        it 'returns nil' do
          expect(adapter.work_item_parent_link_id).to be_nil
        end
      end
    end

    describe '#parent_group_id' do
      it 'returns parent work item namespace_id' do
        expect(adapter.parent_group_id).to eq(parent_epic.group_id)
      end

      context 'when parent is in a different group' do
        let_it_be(:other_group) { create(:group) }
        let_it_be(:parent_epic_other_group) { create(:epic, group: other_group) }
        let_it_be(:epic_cross_group) { create(:epic, group: group, parent: parent_epic_other_group) }
        let_it_be(:work_item_cross_group) { epic_cross_group.work_item }

        subject(:adapter) { described_class.new(work_item_cross_group) }

        it 'returns the parent group id' do
          expect(adapter.parent_group_id).to eq(other_group.id)
          expect(adapter.parent_group_id).not_to eq(group.id)
        end
      end

      context 'when epic has no parent' do
        let_it_be(:epic_without_parent) { create(:epic, group: group) }
        let_it_be(:work_item_without_parent) { epic_without_parent.work_item }

        subject(:adapter) { described_class.new(work_item_without_parent) }

        it 'returns nil' do
          expect(adapter.parent_group_id).to be_nil
        end
      end
    end

    describe '#parent_work_item' do
      it 'returns parent work item' do
        expect(adapter.send(:parent_work_item)).to eq(parent_epic.work_item)
      end

      context 'when epic has no parent' do
        let_it_be(:epic_without_parent) { create(:epic, group: group) }
        let_it_be(:work_item_without_parent) { epic_without_parent.work_item }

        subject(:adapter) { described_class.new(work_item_without_parent) }

        it 'returns nil' do
          expect(adapter.send(:parent_work_item)).to be_nil
        end
      end
    end
  end

  describe 'epic-specific methods' do
    describe '#to_reference' do
      context 'with full: false' do
        it 'delegates to epic' do
          expect(adapter.to_reference(full: false)).to eq(epic.to_reference(full: false))
        end
      end

      context 'with full: true' do
        it 'delegates to epic' do
          expect(adapter.to_reference(full: true)).to eq(epic.to_reference(full: true))
        end
      end
    end

    describe '#upvotes' do
      it 'returns 0 when no upvotes' do
        expect(adapter.upvotes).to eq(0)
      end

      context 'with award emoji on work item' do
        let_it_be(:user1) { create(:user) }
        let_it_be(:user2) { create(:user) }

        before do
          create(:award_emoji, name: 'thumbsup', awardable: work_item, user: user1)
          create(:award_emoji, name: 'thumbsup', awardable: work_item, user: user2)
        end

        it 'returns count of thumbsup emoji from work item' do
          expect(adapter.upvotes).to eq(2)
        end
      end

      context 'with award emoji on epic (legacy)' do
        let_it_be(:user1) { create(:user) }
        let_it_be(:user2) { create(:user) }

        before do
          create(:award_emoji, name: 'thumbsup', awardable: epic, user: user1)
          create(:award_emoji, name: 'thumbsup', awardable: epic, user: user2)
        end

        it 'returns count of thumbsup emoji from epic via unified association' do
          expect(adapter.upvotes).to eq(2)
        end
      end

      context 'with award emoji on both work item and epic' do
        let_it_be(:user1) { create(:user) }
        let_it_be(:user2) { create(:user) }
        let_it_be(:user3) { create(:user) }

        before do
          create(:award_emoji, name: 'thumbsup', awardable: work_item, user: user1)
          create(:award_emoji, name: 'thumbsup', awardable: epic, user: user2)
          create(:award_emoji, name: 'thumbsup', awardable: epic, user: user3)
        end

        it 'returns combined count from both via unified association' do
          expect(adapter.upvotes).to eq(3)
        end
      end
    end

    describe '#downvotes' do
      it 'returns 0 when no downvotes' do
        expect(adapter.downvotes).to eq(0)
      end

      context 'with award emoji on work item' do
        let_it_be(:user1) { create(:user) }
        let_it_be(:user2) { create(:user) }

        before do
          create(:award_emoji, name: 'thumbsdown', awardable: work_item, user: user1)
          create(:award_emoji, name: 'thumbsdown', awardable: work_item, user: user2)
        end

        it 'returns count of thumbsdown emoji from work item' do
          expect(adapter.downvotes).to eq(2)
        end
      end

      context 'with award emoji on epic (legacy)' do
        let_it_be(:user1) { create(:user) }
        let_it_be(:user2) { create(:user) }

        before do
          create(:award_emoji, name: 'thumbsdown', awardable: epic, user: user1)
          create(:award_emoji, name: 'thumbsdown', awardable: epic, user: user2)
        end

        it 'returns count of thumbsdown emoji from epic via unified association' do
          expect(adapter.downvotes).to eq(2)
        end
      end

      context 'with award emoji on both work item and epic' do
        let_it_be(:user1) { create(:user) }
        let_it_be(:user2) { create(:user) }
        let_it_be(:user3) { create(:user) }

        before do
          create(:award_emoji, name: 'thumbsdown', awardable: work_item, user: user1)
          create(:award_emoji, name: 'thumbsdown', awardable: epic, user: user2)
          create(:award_emoji, name: 'thumbsdown', awardable: epic, user: user3)
        end

        it 'returns combined count from both via unified association' do
          expect(adapter.downvotes).to eq(3)
        end
      end
    end

    describe '#subscribed?' do
      let(:user) { create(:user) }

      it 'delegates to epic' do
        expect(adapter.subscribed?(user)).to be(false)
      end
    end

    describe '#web_url' do
      it 'returns group epic url' do
        expected_url = ::Gitlab::Routing.url_helpers.group_epic_url(group, epic)
        expect(adapter.web_url).to eq(expected_url)
      end
    end

    describe '#web_edit_url' do
      it 'returns group epic path' do
        expected_path = ::Gitlab::Routing.url_helpers.group_epic_path(group, epic)
        expect(adapter.web_edit_url).to eq(expected_path)
      end
    end

    describe '#start_date_from_inherited_source_title' do
      it 'delegates to epic' do
        expect(adapter.start_date_from_inherited_source_title).to eq(epic.start_date_from_inherited_source_title)
      end
    end

    describe '#due_date_from_inherited_source_title' do
      it 'delegates to epic' do
        expect(adapter.due_date_from_inherited_source_title).to eq(epic.due_date_from_inherited_source_title)
      end
    end
  end

  describe '#epic_issues' do
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:epic_work_item) { create(:work_item, :epic, namespace: group) }
    let_it_be(:child_issue_1) { create(:work_item, :issue, project: project) }
    let_it_be(:child_issue_2) { create(:work_item, :issue, project: project) }
    let_it_be(:child_issue_3) { create(:work_item, :issue, project: project) }
    let_it_be(:child_epic) { create(:work_item, :epic, namespace: group) }

    let_it_be(:parent_link_1) do
      create(:parent_link, work_item_parent: epic_work_item, work_item: child_issue_1, relative_position: 200)
    end

    let_it_be(:parent_link_2) do
      create(:parent_link, work_item_parent: epic_work_item, work_item: child_issue_2, relative_position: 100)
    end

    let_it_be(:parent_link_3) do
      create(:parent_link, work_item_parent: epic_work_item, work_item: child_issue_3, relative_position: nil)
    end

    let_it_be(:parent_link_child_epic) do
      create(:parent_link, work_item_parent: epic_work_item, work_item: child_epic, relative_position: 50)
    end

    subject(:adapter) { described_class.new(epic_work_item) }

    it 'returns child issues excluding epics' do
      expect(adapter.epic_issues).to contain_exactly(child_issue_1, child_issue_2, child_issue_3)
    end

    it 'orders by relative_position ASC NULLS LAST, then by parent_link id ASC' do
      expect(adapter.epic_issues.to_a).to eq([child_issue_2, child_issue_1, child_issue_3])
    end

    it 'includes parent_link_id virtual attribute' do
      result = described_class.epic_issue_api_preloads(adapter.epic_issues).first
      expect(result.parent_link_id).to eq(parent_link_2.id)
    end

    it 'includes parent_link_relative_position virtual attribute' do
      result = described_class.epic_issue_api_preloads(adapter.epic_issues).first
      expect(result.parent_link_relative_position).to eq(100)
    end

    it 'does not have N+1 queries' do
      adapter.epic_issues.to_a # warm-up
      control = ActiveRecord::QueryRecorder.new { adapter.epic_issues.to_a }

      create(:parent_link, work_item_parent: epic_work_item,
        work_item: create(:work_item, :issue, project: project),
        relative_position: 300)

      expect { described_class.new(epic_work_item).epic_issues.to_a }.not_to exceed_query_limit(control)
    end

    context 'when epic has no child issues' do
      let_it_be(:empty_epic) { create(:work_item, :epic, namespace: group) }

      it 'returns an empty relation' do
        expect(described_class.new(empty_epic).epic_issues).to be_empty
      end
    end

    context 'when work item is not an epic' do
      let_it_be(:issue_work_item) { create(:work_item, :issue, project: project) }

      it 'returns none' do
        expect(described_class.new(issue_work_item).epic_issues).to be_empty
      end
    end

    context 'with epic_issue association on parent_link' do
      let_it_be_with_reload(:legacy_epic) { create(:epic, :with_synced_work_item, group: group) }
      let_it_be(:legacy_epic_work_item) { legacy_epic.work_item }
      let_it_be_with_reload(:child_for_legacy) { create(:work_item, :issue, project: project) }

      let_it_be_with_reload(:parent_link_with_epic_issue) do
        create(:parent_link, work_item_parent: legacy_epic_work_item, work_item: child_for_legacy,
          relative_position: 100)
      end

      let_it_be_with_reload(:epic_issue_record) do
        create(:epic_issue, epic: legacy_epic, issue: child_for_legacy,
          work_item_parent_link: parent_link_with_epic_issue)
      end

      subject(:adapter) { described_class.new(legacy_epic_work_item) }

      it 'preloads epic_issue association without extra queries' do
        issues = described_class.epic_issue_api_preloads(adapter.epic_issues).to_a

        recorder = ActiveRecord::QueryRecorder.new do
          issues.each { |issue| issue.parent_link.epic_issue }
        end

        expect(recorder.count).to eq(0)
      end

      it 'allows access to epic_issue_id through parent_link' do
        result = described_class.epic_issue_api_preloads(adapter.epic_issues).find { |i| i.id == child_for_legacy.id }
        expect(result.parent_link.epic_issue.id).to eq(epic_issue_record.id)
      end
    end
  end

  describe '#find_child_issue' do
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:epic_work_item) { create(:work_item, :epic, namespace: group) }
    let_it_be(:child_issue) { create(:work_item, :issue, project: project) }
    let_it_be(:other_issue) { create(:work_item, :issue, project: project) }

    let_it_be(:parent_link) do
      create(:parent_link, work_item_parent: epic_work_item, work_item: child_issue)
    end

    subject(:adapter) { described_class.new(epic_work_item) }

    it 'returns the child work item when it exists' do
      expect(adapter.find_child_issue(child_issue.id)).to eq(child_issue)
    end

    it 'returns nil when child is not linked to parent' do
      expect(adapter.find_child_issue(other_issue.id)).to be_nil
    end

    context 'when work item is not an epic' do
      let_it_be(:issue_work_item) { create(:work_item, :issue, project: project) }

      it 'returns nil' do
        expect(described_class.new(issue_work_item).find_child_issue(child_issue.id)).to be_nil
      end
    end
  end
end
