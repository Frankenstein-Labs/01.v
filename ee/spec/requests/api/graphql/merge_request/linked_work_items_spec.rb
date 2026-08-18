# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.mergeRequest.linkedWorkItems', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :public) }
  let_it_be(:project) { create(:project, :public, :repository, group: group) }
  let_it_be(:developer) { create(:user, developer_of: project) }

  let(:current_user) { developer }
  let(:linked_work_items_data) { graphql_data_at(:merge_request, :linked_work_items) }

  before_all do
    group.add_developer(developer)
  end

  context 'when filtering by CLOSES type' do
    context 'when a closing work item is a group-level work item' do
      let_it_be(:project_issue) { create(:work_item, project: project) }
      let_it_be(:group_level_epic) { create(:work_item, :epic, :group_level, namespace: group) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }

      let(:merge_request_params) { { 'id' => global_id_of(merge_request) } }

      let(:linked_work_items_fields) do
        <<~GRAPHQL
          linkedWorkItems(types: [CLOSES]) {
            linkType
            workItem { id }
          }
        GRAPHQL
      end

      let(:query) do
        graphql_query_for('mergeRequest', merge_request_params, linked_work_items_fields)
      end

      before_all do
        create(:merge_requests_closing_issues, issue: project_issue, merge_request: merge_request)
        create(:merge_requests_closing_issues, issue: group_level_epic, merge_request: merge_request)
      end

      before do
        stub_licensed_features(epics: true)
        post_graphql(query, current_user: current_user)
      end

      it 'filters out group-level work items from closing issues' do
        work_item_ids = linked_work_items_data.pluck('workItem').pluck('id')

        expect(work_item_ids).to contain_exactly(project_issue.to_gid.to_s)
      end
    end
  end
end
