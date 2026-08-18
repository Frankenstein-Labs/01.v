# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::IssueStageEvent, feature_category: :value_stream_management do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:project) { create(:project, namespace: create(:group), developers: user) }
  let_it_be(:issue1) { create(:issue, project: project) }
  let_it_be(:issue2) { create(:issue, project: project) }
  let_it_be_with_reload(:issue3) { create(:issue, project: project, assignees: [user]) }

  let_it_be(:epic1) { create(:epic, group: project.group) }
  let_it_be(:epic2) { create(:epic, group: project.group) }

  let_it_be(:epic_issue1) { create(:epic_issue, epic: epic1, issue: issue1) }
  let_it_be(:epic_issue2) { create(:epic_issue, epic: epic2, issue: issue3) }

  let_it_be(:stage_event1) do
    create(:cycle_analytics_issue_stage_event,
      author_id: 1,
      weight: 2,
      sprint_id: 3,
      issue_id: issue1.id)
  end

  let_it_be(:stage_event2) do
    create(:cycle_analytics_issue_stage_event,
      author_id: nil,
      weight: nil,
      sprint_id: nil,
      issue_id: issue2.id)
  end

  let_it_be(:stage_event3) do
    create(:cycle_analytics_issue_stage_event,
      author_id: 4,
      weight: 5,
      sprint_id: 6,
      issue_id: issue3.id)
  end

  describe '.not_authored' do
    subject(:scope) { described_class.not_authored(stage_event3.author_id).pluck(:issue_id) }

    it { is_expected.to match_array([stage_event1.issue_id, stage_event2.issue_id]) }
  end

  describe '.without_weight' do
    subject(:scope) { described_class.without_weight(stage_event1.weight).pluck(:issue_id) }

    it { is_expected.to match_array([stage_event2.issue_id, stage_event3.issue_id]) }
  end

  describe '.without_sprint_id' do
    subject(:scope) { described_class.without_sprint_id(stage_event1.sprint_id).pluck(:issue_id) }

    it { is_expected.to match_array([stage_event2.issue_id, stage_event3.issue_id]) }
  end

  describe '.without_epic_id' do
    subject(:scope) { described_class.without_epic_id(epic2.id).pluck(:issue_id) }

    it { is_expected.to match_array([stage_event1.issue_id, stage_event2.issue_id]) }
  end

  describe '.not_assigned_to' do
    subject(:scope) { described_class.not_assigned_to(user.id).pluck(:issue_id) }

    it { is_expected.to match_array([stage_event1.issue_id, stage_event2.issue_id]) }
  end
end
