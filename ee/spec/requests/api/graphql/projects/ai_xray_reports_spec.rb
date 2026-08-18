# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.projects(ids).aiXrayReports', feature_category: :code_suggestions do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, developers: current_user) }
  let_it_be(:project_without_xray_reports) { create(:project, developers: current_user) }
  let_it_be(:xray_report1) { create(:xray_report, project: project, lang: 'ruby') }
  let_it_be(:xray_report2) { create(:xray_report, project: project, lang: 'python') }

  def post_query
    project_ids = Project.all.map { |p| global_id_of(p) }

    query = graphql_query_for(
      :projects, { ids: project_ids },
      <<~FIELDS
        nodes {
          id
          #{query_nodes(:ai_xray_reports)}
        }
      FIELDS
    )

    post_graphql(query, current_user: current_user)
  end

  it 'returns the expected x-ray reports data' do
    post_query

    expect(graphql_data_at(:projects, :nodes)).to contain_exactly(
      a_graphql_entity_for(project_without_xray_reports, aiXrayReports: { 'nodes' => [] }),
      a_graphql_entity_for(
        project,
        aiXrayReports: { 'nodes' => match_array([
          { 'language' => xray_report1.lang },
          { 'language' => xray_report2.lang }
        ]) }
      )
    )
  end

  it 'avoids N+1 queries' do
    post_query # Warm up

    control_count = ActiveRecord::QueryRecorder.new(skip_cached: false) { post_query }

    other_project = create(:project, developers: current_user)
    create(:xray_report, project: other_project)

    expect { post_query }.not_to exceed_query_limit(control_count).allow_skip_cache_inconsistency
  end
end
