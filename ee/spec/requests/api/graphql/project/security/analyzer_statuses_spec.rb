# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).analyzerStatuses', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, developers: [user]) }
  let_it_be(:build) { create(:ci_build) }
  let(:fields) { 'source' }

  let(:query) do
    graphql_query_for(
      :project, { full_path: project.full_path },
      query_graphql_field(:analyzer_statuses, {}, fields)
    )
  end

  before do
    stub_licensed_features(security_inventory: true)
  end

  context 'when the build source maps to a named enum value' do
    let_it_be(:analyzer_status) { create(:analyzer_project_status, project: project, build: build) }
    let_it_be(:build_source) { create(:ci_build_source, job: build, source: :scan_execution_policy) }

    it 'returns the mapped enum value' do
      post_graphql(query, current_user: user)

      sources = graphql_data_at(:project, :analyzer_statuses).pluck('source')
      expect(sources).to contain_exactly('SCAN_EXECUTION_POLICY')
    end
  end

  context 'when the build source maps to yml' do
    let_it_be(:analyzer_status) { create(:analyzer_project_status, project: project, build: build) }
    let_it_be(:build_source) { create(:ci_build_source, job: build, source: :push) }

    it 'returns YML' do
      post_graphql(query, current_user: user)

      sources = graphql_data_at(:project, :analyzer_statuses).pluck('source')
      expect(sources).to contain_exactly('YML')
    end
  end

  context 'when analyzer status has no associated build' do
    let_it_be(:analyzer_status) { create(:analyzer_project_status, project: project, build: nil) }

    it 'returns nil for source' do
      post_graphql(query, current_user: user)

      sources = graphql_data_at(:project, :analyzer_statuses).pluck('source')
      expect(sources).to contain_exactly(nil)
    end
  end

  context 'when a dependency_scanning_post_processing status exists' do
    let(:fields) { 'analyzerType' }

    let_it_be(:sast_status) do
      create(:analyzer_project_status, project: project, analyzer_type: :sast, build: nil)
    end

    let_it_be(:post_processing_status) do
      create(:analyzer_project_status, :dependency_scanning_post_processing, project: project, build: nil)
    end

    it 'includes it in the response and does not error' do
      post_graphql(query, current_user: user)

      expect(graphql_errors).to be_nil
      types = graphql_data_at(:project, :analyzer_statuses).pluck('analyzerType')
      expect(types).to contain_exactly('SAST', 'DEPENDENCY_SCANNING_POST_PROCESSING')
    end
  end
end
