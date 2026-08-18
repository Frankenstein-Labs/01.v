# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Blocking issues count', feature_category: :planning_views do
  include Features::SortingHelpers

  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:project, freeze: false) { build(:project, :public) }
  let_it_be(:blocked_issue, freeze: false) { build(:issue, project: project, created_at: 1.day.ago) }
  let_it_be(:issue1, freeze: false) do
    build(:issue, project: project, created_at: 2.days.ago, title: 'blocks one issue')
  end

  let_it_be(:issue2, freeze: false) do
    build(:issue, project: project, created_at: 3.days.ago, title: 'blocks two issues')
  end

  before do
    visit project_work_items_path(project)
  end

  before_all do
    create(:issue_link, source: issue1, target: blocked_issue, link_type: IssueLink::TYPE_BLOCKS)
    create(:issue_link, source: issue2, target: issue1, link_type: IssueLink::TYPE_BLOCKS)
    create(:issue_link, source: issue2, target: blocked_issue, link_type: IssueLink::TYPE_BLOCKS)
  end

  it 'sorts by blocking', :js do
    click_button 'Display'
    pajamas_sort_by 'Blocking', from: 'Created date'

    page.within(".issues-list") do
      page.within("li.issue:nth-child(1)") do
        expect(page).to have_content('blocks two issues')
        expect(page).to have_testid('relationship-blocks-icon', text: '2')
      end

      page.within("li.issue:nth-child(2)") do
        expect(page).to have_content('blocks one issue')
        expect(page).to have_testid('relationship-blocks-icon', text: '1')
      end
    end
  end
end
