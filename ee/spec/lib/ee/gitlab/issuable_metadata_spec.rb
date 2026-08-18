# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::IssuableMetadata, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:project1) { create(:project, :public, :repository, creator: user, namespace: user.namespace) }
  let_it_be(:project2) { create(:project, :public, :repository, creator: user, namespace: user.namespace) }

  context 'with epics' do
    let_it_be(:group) { create(:group) }
    let_it_be(:epic1) { create(:epic, group: group) }
    let_it_be(:epic2) { create(:epic, group: group) }

    it 'aggregates votes from both epic and work item award emojis' do
      create(:award_emoji, :upvote, awardable: epic1, user: user)
      legacy_emoji = create(:award_emoji, :downvote, awardable: epic2, user: user)
      legacy_emoji.update_columns(awardable_type: 'Epic', awardable_id: epic2.id)

      data = described_class.new(user, Epic.id_in([epic1.id, epic2.id]).limit(2)).data

      expect(data[epic1.id].upvotes).to eq(1)
      expect(data[epic1.id].downvotes).to eq(0)
      expect(data[epic2.id].upvotes).to eq(0)
      expect(data[epic2.id].downvotes).to eq(1)
    end
  end

  context 'with issues' do
    # blocked issues
    let_it_be(:blocked_issue_1) { create(:issue, author: user, project: project1) }
    let_it_be(:blocked_issue_2) { create(:issue, author: user, project: project2) }
    let_it_be(:blocked_issue_3) { create(:issue, author: user, project: project1) }
    let_it_be(:closed_blocked_issue) { create(:issue, author: user, project: project2, state: :closed) }
    # blocking issues (as target or source)
    let_it_be(:blocking_issue_1) { create(:issue, project: project1) }
    let_it_be(:blocking_issue_2) { create(:issue, project: project2) }

    before_all do
      create(:issue_link, source: blocking_issue_1, target: blocked_issue_1, link_type: IssueLink::TYPE_BLOCKS)
      create(:issue_link, source: blocking_issue_2, target: blocked_issue_2, link_type: IssueLink::TYPE_BLOCKS)
      create(:issue_link, source: blocking_issue_1, target: closed_blocked_issue, link_type: IssueLink::TYPE_BLOCKS)
      create(:issue_link, source: blocking_issue_1, target: blocked_issue_3, link_type: IssueLink::TYPE_BLOCKS)
    end

    it 'aggregates stats on issues' do
      data = described_class.new(user, Issue.all.limit(6)).data

      expect(data.count).to eq(6)
      expect(data[blocking_issue_1.id].blocking_issues_count).to eq(2)
      expect(data[blocking_issue_2.id].blocking_issues_count).to eq(1)
      expect(data[blocked_issue_1.id].blocking_issues_count).to eq(0)
    end
  end
end
