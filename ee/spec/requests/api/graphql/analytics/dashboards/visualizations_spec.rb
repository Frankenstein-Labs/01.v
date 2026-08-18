# frozen_string_literal: true

require 'spec_helper'
require 'rspec-parameterized'

RSpec.describe 'Query.project(id).dashboards.panels(id).visualization', feature_category: :product_analytics do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :with_product_analytics_dashboard) }

  let(:query) do
    <<~GRAPHQL
      query {
        project(fullPath: "#{project.full_path}") {
          name
          customizableDashboards {
            nodes {
              title
              slug
              description
              panels {
                nodes {
                  title
                  gridAttributes
                  visualization {
                    type
                    options
                    data
                    errors
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL
  end

  before do
    stub_licensed_features(product_analytics: true, project_merge_request_analytics: false)
  end

  context 'when current user is a developer' do
    let_it_be(:user) { create(:user, developer_of: project) }

    it 'returns visualization' do
      get_graphql(query, current_user: user)

      expect(
        graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, 0, :visualization, :type)
      ).to eq('LineChart')
    end

    context 'when clickhouse is enabled' do
      using RSpec::Parameterized::TableSyntax

      before do
        allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?)
                      .with(user, :read_enterprise_ai_analytics, anything)
                      .and_return(true)
      end

      it 'returns the correct number of visualizations' do
        get_graphql(query, current_user: user)

        expect(graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes).count).to eq(21)
      end

      where(:node_idx, :panel_type, :panel_title) do
        0  | 'SingleStat'         | 'GitLab Duo users'
        1  | 'SingleStat'         | 'GitLab Duo power users'
        2  | 'SingleStat'         | 'GitLab Duo agent/flow users'
        3  | 'SingleStat'         | 'GitLab Duo Agent Chat sessions'
        4  | 'SingleStat'         | 'Pipelines using GitLab Duo features'
        5  | 'DataTable'          | 'GitLab Duo Agent Platform flow usage'
        6  | 'LineChart'          | 'Pipelines using GitLab Duo Agent Platform over time'
        7  | 'LineChart'          | 'Returning GitLab Duo users by feature'
        8  | 'AiImpactTable'      | 'GitLab Duo usage metrics for the %{namespaceName} %{namespaceType}'
        9  | 'AiImpactTable'      | 'Development metrics for the %{namespaceName} %{namespaceType}'
        10 | 'AiImpactTable'      | 'Pipeline metrics for the %{namespaceName} %{namespaceType}'
        11 | 'DataTable'          | 'GitLab Duo usage by user'
        12 | 'DataTable'          | 'GitLab Duo Code Review usage by user'
        13 | 'DataTable'          | 'GitLab Duo Root Cause Analysis usage by user'
        14 | 'DataTable'          | 'Flows usage by user'
        15 | 'DataTable'          | 'GitLab Duo Code Suggestions usage by user'
        16 | 'BarChart'           | 'GitLab Duo Code Suggestions acceptance by language'
        17 | 'BarChart'           | 'GitLab Duo Code Suggestions acceptance by IDE'
        18 | 'StackedColumnChart' | 'GitLab Duo Code Review requests by role'
        19 | 'AreaChart'          | 'GitLab Duo Code Review comments sentiment'
        20 | 'AreaChart'          | 'Code generation volume trends'
      end

      with_them do
        it "returns the each visualization" do
          get_graphql(query, current_user: user)

          expect(
            graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, node_idx, :visualization,
              :type)
          ).to eq(panel_type)
          expect(
            graphql_data_at(:project, :customizable_dashboards, :nodes, 0, :panels, :nodes, node_idx, :title)
          ).to eq(panel_title)
        end
      end
    end

    context 'when the visualization has validation errors' do
      let_it_be(:project) { create(:project, :with_product_analytics_invalid_custom_visualization) }
      let_it_be(:user) { create(:user, developer_of: project) }

      let(:slug) { "dashboard_example_invalid_vis" }
      let(:query) do
        <<~GRAPHQL
          query {
            project(fullPath: "#{project.full_path}") {
              customizableDashboards(slug: "#{slug}") {
                nodes {
                  panels {
                    nodes {
                      visualization {
                        errors
                      }
                    }
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it 'returns the visualization with a validation error' do
        get_graphql(query, current_user: user)

        expect(
          graphql_data_at(:project, :customizable_dashboards, :nodes, 0,
            :panels, :nodes, 0, :visualization, :errors, 0))
          .to eq("property '/type' is not one of: " \
            "[\"AreaChart\", \"LineChart\", \"ColumnChart\", \"DataTable\", \"Glql\", \"SingleStat\", " \
            "\"DORAChart\", \"UsageOverview\", \"DoraPerformersScore\", " \
            "\"DoraProjectsComparison\", \"AiImpactTable\", \"ContributionsByUserTable\", " \
            "\"ContributionsPushesChart\", \"ContributionsIssuesChart\", " \
            "\"ContributionsMergeRequestsChart\", \"NamespaceMetadata\", " \
            "\"MergeRequestsThroughputTable\", " \
            "\"BarChart\", \"StackedColumnChart\"]")
      end
    end
  end
end
