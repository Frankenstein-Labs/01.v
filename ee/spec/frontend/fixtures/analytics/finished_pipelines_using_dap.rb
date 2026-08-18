# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Finished Pipelines Using DAP (GraphQL fixtures)', :click_house,
  feature_category: :value_stream_management do
  include ApiHelpers
  include JavaScriptFixturesHelpers
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:group, freeze: false) { create(:group, name: 'cool-group') }
  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:current_user, freeze: false) { create(:user, reporter_of: group) }

  # Dates are fixed to match the globally pinned Jest fake date (2020-07-06).
  let(:start_date) { '2020-01-06T00:00:00Z' }
  let(:end_date) { '2020-07-06T00:00:00Z' }

  before do
    stub_licensed_features(ai_analytics: true)
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
      .with(current_user, :read_ci_cd_analytics, anything)
      .and_return(true)
  end

  describe GraphQL::Query, type: :request do
    query_path = 'analytics/dashboards/ai_impact/graphql/finished_pipelines_using_dap.query.graphql'

    def post_finished_pipelines_query(query_path, group, current_user, start_date, end_date)
      query = get_graphql_query_as_string(query_path)
      post_graphql(query, current_user: current_user,
        variables: {
          fullPath: group.full_path,
          startDate: start_date,
          endDate: end_date
        })
    end

    def pipeline_at(source, month, status = 'success')
      { source: source, started_at: Time.utc(2020, month, 6), status: status }
    end

    def insert_pipelines(project, pipelines)
      clickhouse_fixture(:siphon_p_ci_pipelines, pipelines.map.with_index(1) do |p, id|
        {
          id: id,
          partition_id: 100,
          project_id: project.id,
          traversal_path: project.project_namespace.traversal_path(with_organization: true).to_s,
          ref: 'main',
          source: ::Enums::Ci::Pipeline.sources[p[:source].to_sym],
          status: p[:status],
          duration: 60,
          started_at: p[:started_at],
          finished_at: p[:started_at] + 60.seconds,
          _siphon_replicated_at: Time.current,
          _siphon_deleted: false
        }
      end)
    end

    context 'with pipelines data' do
      before do
        insert_pipelines(project, [
          pipeline_at('duo_workflow', 2),
          pipeline_at('push',         2, 'failed'),
          pipeline_at('push',         2, 'canceled'),
          pipeline_at('duo_workflow', 3, 'skipped'),
          pipeline_at('push',         3),
          pipeline_at('duo_workflow', 4),
          pipeline_at('duo_workflow', 4, 'failed'),
          pipeline_at('push',         4, 'skipped'),
          pipeline_at('duo_workflow', 5, 'canceled'),
          pipeline_at('push',         5),
          pipeline_at('push',         5, 'failed'),
          pipeline_at('duo_workflow', 6),
          pipeline_at('duo_workflow', 6, 'skipped'),
          pipeline_at('push',         6, 'canceled'),
          pipeline_at('duo_workflow', 7, 'failed'),
          pipeline_at('push',         7),
          # Excluded by the completed-status filter
          pipeline_at('duo_workflow', 4, 'running'),
          pipeline_at('push',         6, 'pending')
        ])
      end

      it "ee/graphql/#{query_path}.json" do
        post_finished_pipelines_query(query_path, group, current_user, start_date, end_date)
        expect_graphql_errors_to_be_empty
      end
    end

    context 'with gaps in data' do
      before do
        insert_pipelines(project, [
          pipeline_at('push',         2, 'failed'),
          # Mar 2020 intentionally has no completed pipelines
          pipeline_at('duo_workflow', 3, 'running'),
          pipeline_at('duo_workflow', 4, 'canceled'),
          pipeline_at('duo_workflow', 5),
          pipeline_at('push',         5, 'skipped'),
          pipeline_at('push',         6),
          pipeline_at('push',         7, 'failed')
        ])
      end

      it "ee/graphql/#{query_path}.gaps.json" do
        post_finished_pipelines_query(query_path, group, current_user, start_date, end_date)
        expect_graphql_errors_to_be_empty
      end
    end

    context 'with no pipelines data' do
      it "ee/graphql/#{query_path}.empty.json" do
        post_finished_pipelines_query(query_path, group, current_user, start_date, end_date)
        expect_graphql_errors_to_be_empty
      end
    end
  end
end
