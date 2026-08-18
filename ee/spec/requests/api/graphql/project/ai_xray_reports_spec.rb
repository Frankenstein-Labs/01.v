# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).aiXrayReports', feature_category: :code_suggestions do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project, developers: current_user) }
  let_it_be(:project_without_xray_reports) { create(:project, developers: current_user) }
  let_it_be(:xray_report1) { create(:xray_report, project: project, lang: 'ruby') }
  let_it_be(:xray_report2) { create(:xray_report, project: project, lang: 'python') }

  let(:project_full_path) { project.full_path }

  let(:query) do
    graphql_query_for(
      :project, { full_path: project_full_path },
      <<~FIELDS
        id
        #{query_nodes(:ai_xray_reports)}
      FIELDS
    )
  end

  subject(:post_query) { post_graphql(query, current_user: current_user) }

  it 'returns the expected x-ray reports data' do
    post_query

    expect(graphql_data_at(:project, :aiXrayReports, :nodes)).to contain_exactly(
      { 'language' => xray_report1.lang },
      { 'language' => xray_report2.lang }
    )
  end

  context 'when the project does not have any x-ray reports' do
    let(:project_full_path) { project_without_xray_reports.full_path }

    it 'returns an empty array' do
      post_query

      expect(graphql_data_at(:project, :aiXrayReports, :nodes)).to eq([])
    end
  end
end
