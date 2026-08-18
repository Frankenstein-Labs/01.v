# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an issue list at root level', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group1) { create(:group, developers: current_user) }
  let_it_be(:group2) { create(:group, developers: current_user) }
  let_it_be(:project_a) { create(:project, :repository, :public, group: group1) }
  let_it_be(:project_b) { create(:project, :repository, :private, group: group1) }
  let_it_be(:project_c) { create(:project, :repository, :public, group: group2) }
  let_it_be(:project_d) { create(:project, :repository, :private, group: group2) }
  let_it_be(:public_project) { project_a }
  let_it_be(:issue_a) { create(:issue, project: project_a) }
  let_it_be(:issue_b) { create(:issue, project: project_b, weight: 1) }
  let_it_be(:issue_c) { create(:issue, project: project_c, weight: 2) }
  let_it_be(:issue_d) { create(:issue, project: project_d, weight: 3) }
  let_it_be(:issue_e) { create(:issue, project: project_d, weight: 4) }

  let_it_be(:issues) { [issue_a, issue_b, issue_c, issue_d, issue_e] }
  # we need to always provide at least one filter to the query so it doesn't fail
  let_it_be(:base_params) { { iids: issues.map { |issue| issue.iid.to_s } } }

  let(:issue_filter_params) { {} }
  let(:all_query_params) { base_params.merge(**issue_filter_params) }

  let(:fields) do
    <<~QUERY
      nodes { id }
    QUERY
  end

  context 'with quarantine', quarantine: {
    issue: [
      'https://gitlab.com/gitlab-org/gitlab/-/issues/517908',
      'https://gitlab.com/gitlab-org/gitlab/-/issues/450283',
      'https://gitlab.com/gitlab-org/gitlab/-/issues/448509',
      'https://gitlab.com/gitlab-org/gitlab/-/issues/448396'
    ]
  } do
    # All new specs should be added to the shared example if the change also
    # affects the `issues` query at the project level of the API.
    # Shared example also used in ee/spec/requests/api/graphql/project/issues_spec.rb
    it_behaves_like 'graphql issue list request spec EE' do
      let(:issue_nodes_path) { %w[issues nodes] }

      # sorting
      let(:data_path) { [:issues] }

      def pagination_query(params)
        graphql_query_for(
          :issues,
          base_params.merge(**issue_filter_params).merge(**params.to_h),
          "#{page_info} nodes { id }"
        )
      end
    end
  end

  context 'when fetching issues from multiple projects' do
    before do
      stub_licensed_features(group_ip_restriction: true)
      stub_application_setting(check_namespace_plan: true)
    end

    let(:fields) do
      <<~QUERY
        nodes {
          id
          epic {
            id
          }
        }
      QUERY
    end

    it 'avoids N+1 queries', :use_sql_query_cache, :request_store do
      post_query # warm-up

      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query, current_user: current_user)
      end
      expect_graphql_errors_to_be_empty

      new_private_project = create(:project, :private, developers: current_user)
      create(:issue, project: new_private_project)

      root_group = create(:group, :private, maintainers: current_user)
      create(:issue, project: create(:project, :private, group: root_group))
      child_group = create(:group, :private, parent: root_group)
      create(:issue, project: create(:project, :private, group: child_group))

      # Threshold accounts for organization admin checks and namespace loading for nested groups
      # +5 from configurable work item types (custom_types + root_ancestor lookups per new namespace)
      expect { post_graphql(query, current_user: current_user) }.not_to exceed_all_query_limit(control)
        .with_threshold(12)
      expect_graphql_errors_to_be_empty
    end
  end

  def execute_query
    post_query
  end

  def post_query(request_user = current_user)
    post_graphql(query, current_user: request_user)
  end

  def query(params = all_query_params)
    graphql_query_for(
      :issues,
      params,
      fields
    )
  end
end
