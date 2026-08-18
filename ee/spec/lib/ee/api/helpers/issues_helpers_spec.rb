# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Helpers::IssuesHelpers do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:epic) { create(:epic, group: group) }

  subject(:issues_helpers) { Class.new.include(described_class).new }

  before do
    allow(issues_helpers).to receive(:current_user).and_return(user)
  end

  describe 'find_issues' do
    context 'with epics' do
      before do
        allow(issues_helpers).to receive(:declared_params).and_return(project_id: project.id)
      end

      it 'returns results' do
        issues = create_issues(2, project: project, epic: epic)

        expect(issues_helpers.find_issues.count).to be(issues.count)
      end

      it 'avoids N+1 queries' do
        create_issues(2, project: project, epic: epic)

        recorder = ActiveRecord::QueryRecorder.new { issues_helpers.find_issues.map(&:epic) }

        create_issues(4, project: project, epic: epic)

        expect { issues_helpers.find_issues.map(&:epic) }.not_to exceed_query_limit(recorder)
      end
    end

    context 'with milestone_id filtering' do
      let_it_be(:milestone_ending_in_future) { create(:milestone, group: group, due_date: 2.days.from_now) }
      let_it_be(:milestone_started_in_past) { create(:milestone, group: group, start_date: 2.days.ago) }

      let_it_be(:issue_with_ending_milestone) do
        create(:issue, project: project, milestone: milestone_ending_in_future)
      end

      let_it_be(:issue_with_started_milestone) do
        create(:issue, project: project, milestone: milestone_started_in_past)
      end

      it 'uses the legacy milestone_id wildcard filtering logic for started' do
        allow(issues_helpers).to receive(:declared_params).and_return(project_id: project.id, milestone_id: 'Started')

        expect(issues_helpers.find_issues).to contain_exactly(issue_with_started_milestone)
      end

      it 'uses the legacy milestone_id wildcard filtering logic for upcoming' do
        allow(issues_helpers).to receive(:declared_params).and_return(project_id: project.id, milestone_id: 'Upcoming')

        expect(issues_helpers.find_issues).to contain_exactly(issue_with_ending_milestone)
      end
    end
  end

  private

  def create_issues(count, params)
    (1..count).step do
      create(:issue, params)
    end
  end
end
