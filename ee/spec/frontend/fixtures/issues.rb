# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GraphQL::Query, type: :request, feature_category: :team_planning do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, group: group, reporters: user) }

  issue_popover_query_path = 'issuable/popover/queries/issue.query.graphql'

  before do
    stub_licensed_features(work_item_status: true)
  end

  it "ee/graphql/#{issue_popover_query_path}.json" do
    query = get_graphql_query_as_string(issue_popover_query_path, ee: true)

    issue = create(
      :work_item,
      :issue,
      project: project,
      assignees: [user],
      confidential: true,
      created_at: Time.parse('2020-07-01T04:08:01Z'),
      due_date: Date.new(2020, 7, 5),
      start_date: Date.new(2020, 7, 3),
      milestone: create(
        :milestone,
        project: project,
        title: '15.2',
        start_date: Date.new(2020, 7, 1),
        due_date: Date.new(2020, 7, 30)
      ),
      weight: 3
    )
    create(
      :work_item_current_status,
      :system_defined,
      work_item: issue
    )

    post_graphql(query, current_user: user, variables: {
      fullPath: project.full_path,
      iid: issue.iid.to_s,
      useWorkItemFeatures: false
    })

    expect_graphql_errors_to_be_empty
  end

  it "ee/graphql/#{issue_popover_query_path}_with_features.json" do
    query = get_graphql_query_as_string(issue_popover_query_path, ee: true)

    issue = create(
      :work_item,
      :issue,
      project: project,
      assignees: [user],
      confidential: true,
      created_at: Time.parse('2020-07-01T04:08:01Z'),
      due_date: Date.new(2020, 7, 5),
      start_date: Date.new(2020, 7, 3),
      milestone: create(
        :milestone,
        project: project,
        title: '15.2',
        start_date: Date.new(2020, 7, 1),
        due_date: Date.new(2020, 7, 30)
      ),
      weight: 3
    )
    create(
      :work_item_current_status,
      :system_defined,
      work_item: issue
    )

    post_graphql(query, current_user: user, variables: {
      fullPath: project.full_path,
      iid: issue.iid.to_s,
      useWorkItemFeatures: true
    })

    expect_graphql_errors_to_be_empty
  end
end
