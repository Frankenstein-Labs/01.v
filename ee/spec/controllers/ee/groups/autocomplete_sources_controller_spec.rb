# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::AutocompleteSourcesController, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:group_issue) { create(:work_item, :group_level, namespace: group) }
  let_it_be(:project_issue) { create(:work_item, project: project) }
  let_it_be(:work_item_epic) { create(:work_item, :epic, :group_level, namespace: group) }

  before do
    sign_in(user)
  end

  describe '#issues', feature_category: :portfolio_management do
    before do
      stub_licensed_features(epics: true)
    end

    it 'returns response with group level work items', :aggregate_failures do
      issues_json_response = [
        {
          'iid' => work_item_epic.iid,
          'title' => work_item_epic.title,
          'reference' => work_item_epic.to_reference,
          'icon_name' => 'work-item-epic'
        },
        {
          'iid' => project_issue.iid,
          'title' => project_issue.title,
          'reference' => project_issue.to_reference(group),
          'icon_name' => 'work-item-issue'
        },
        {
          'iid' => group_issue.iid,
          'title' => group_issue.title,
          'reference' => group_issue.to_reference,
          'icon_name' => 'work-item-issue'
        }
      ]

      get :issues, params: { group_id: group }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to be_an(Array)
      expect(json_response.count).to eq(3)
      expect(json_response).to match_array(issues_json_response)
    end
  end
end
