# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "getting a project's linked observability metrics", feature_category: :observability do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:metric) { create(:observability_metrics_issues_connection, issue: create(:issue, project: project)) }
  let_it_be(:metric2) do
    create(:observability_metrics_issues_connection,
      metric_name: 'test1',
      metric_type: :sum_type,
      issue: create(:issue, project: project, title: 'title1')
    )
  end

  let_it_be(:metric3) do
    create(:observability_metrics_issues_connection,
      metric_name: 'test1',
      metric_type: :sum_type,
      issue: create(:issue, project: project, title: 'title2')
    )
  end

  let_it_be(:metric4) do
    create(:observability_metrics_issues_connection,
      metric_name: 'different_name',
      metric_type: :sum_type,
      issue: create(:issue, project: project)
    )
  end

  let_it_be(:metric5) do
    create(:observability_metrics_issues_connection,
      metric_name: 'test1',
      metric_type: :gauge_type,
      issue: create(:issue, project: project)
    )
  end

  let_it_be(:metric_different_project) { create(:observability_metrics_issues_connection, issue: create(:issue)) }

  let(:fields) do
    <<~QUERY
      nodes {
        name
        type
        issue {
          title
          webUrl
        }
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('observabilityMetricsLinks', params, fields)
    )
  end

  let(:params) { {} }

  let(:metrics) do
    graphql_data.dig('project', 'observabilityMetricsLinks', 'nodes')
  end

  before_all do
    project.add_reporter(current_user)
  end

  context 'when observability features are available' do
    before do
      stub_licensed_features(observability: true)
    end

    context 'when no parameters are passed' do
      it 'returns all metric connections for a project' do
        post_graphql(query, current_user: current_user)

        expect(metrics.size).to eq(5)
      end
    end

    context 'when name is passed, and type is not' do
      let(:params) { { name: 'test1' } }

      it 'returns an empty collection' do
        post_graphql(query, current_user: current_user)

        expect(metrics.count).to be_zero
      end
    end

    context 'when type is passed, but name is not' do
      let(:params) { { type: :SUM_TYPE } }

      it 'returns an empty collection' do
        post_graphql(query, current_user: current_user)

        expect(metrics.count).to be_zero
      end
    end

    context 'when both type and name are passed' do
      let(:params) { { name: 'test1', type: :SUM_TYPE } }

      it 'returns metrics from the project that match the input parameters' do
        post_graphql(query, current_user: current_user)

        expect(metrics.count).to eq(2)
        expect(metrics.first).to eq({
          issue: {
            title: metric3.issue.title,
            webUrl: Gitlab::UrlBuilder.build(metric3.issue)
          }.stringify_keys,
          name: "test1",
          type: "sum_type"
        }.stringify_keys)
        expect(metrics.second).to eq({
          issue: {
            title: metric2.issue.title,
            webUrl: Gitlab::UrlBuilder.build(metric2.issue)
          }.stringify_keys,
          name: "test1",
          type: "sum_type"
        }.stringify_keys)
      end
    end
  end

  context 'when observability features are not licensed' do
    before do
      stub_licensed_features(observability: false)
    end

    it 'returns no results' do
      post_graphql(query, current_user: current_user)

      expect(metrics).to be_nil
    end
  end

  context 'when observability features are not enabled' do
    before do
      stub_licensed_features(observability: true)
      stub_feature_flags(observability_features: false)
    end

    it 'returns no results' do
      post_graphql(query, current_user: current_user)

      expect(metrics).to be_nil
    end
  end
end
