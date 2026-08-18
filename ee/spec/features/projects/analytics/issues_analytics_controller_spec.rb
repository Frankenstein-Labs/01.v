# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Analytics::IssuesAnalyticsController, :js, feature_category: :value_stream_management do
  describe 'GET /:namespace/:project/-/analytics/issues' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, group: group) }
    let_it_be(:user) { create(:user, owner_of: group) }
    let_it_be(:issue) { create(:issue, project: project, created_at: 2.days.ago) }

    before do
      stub_licensed_features(issues_analytics: true)
      sign_in(user)
    end

    subject(:visit_page) do
      visit namespace_project_analytics_issues_analytics_path(project_id: project.path, namespace_id: group.path)
    end

    it 'loads the chart' do
      visit_page

      expect(page).to have_content 'Issue Analytics'
      expect(page).not_to have_content 'Failed to load chart.'
    end
  end
end
