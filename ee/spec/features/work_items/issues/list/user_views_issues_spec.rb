# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User views work items page', :js, feature_category: :planning_views do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be_with_reload(:issue1) { create(:issue, project: project, health_status: 'on_track', weight: 2) }
  let_it_be_with_reload(:issue2) { create(:issue, project: project, health_status: 'needs_attention') }
  let_it_be(:issue3) { create(:issue, project: project, health_status: 'at_risk') }

  before do
    stub_licensed_features(blocked_issues: true, issuable_health_status: true, issue_weights: true)
    sign_in(user)
    visit project_work_items_path(project)
  end

  before_all do
    create(:issue_link, source: issue1, target: issue2, link_type: IssueLink::TYPE_BLOCKS)
  end

  describe 'issue card' do
    it 'shows health status, blocking issues, and weight information', :aggregate_failures do
      within(find_by_testid('issuable-container', text: issue3.title)) do
        expect(page).to have_testid('status-text', text: 'At risk')
        expect(page).to have_no_testid('relationship-blocks-icon')
        expect(page).to have_no_testid('issuable-weight-content')
      end

      within(find_by_testid('issuable-container', text: issue2.title)) do
        expect(page).to have_testid('status-text', text: 'Needs attention')
        expect(page).to have_no_testid('relationship-blocks-icon')
        expect(page).to have_no_testid('issuable-weight-content')
      end

      within(find_by_testid('issuable-container', text: issue1.title)) do
        expect(page).to have_testid('status-text', text: 'On track')
        expect(page).to have_testid('relationship-blocks-icon', text: '1')
        expect(page).to have_testid('issuable-weight-content', text: '2')
      end
    end
  end
end
