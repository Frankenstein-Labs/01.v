# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Agent Platform Sessions (GraphQL fixtures)', :click_house,
  time_travel_to: '2026-03-27', feature_category: :value_stream_management do
  include ApiHelpers
  include JavaScriptFixturesHelpers
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:group, freeze: false) { create(:group, name: 'cool-group') }
  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:current_user, freeze: false) { create(:user, reporter_of: group) }
  let_it_be(:user1, freeze: false) { create(:user) }
  let_it_be(:user2, freeze: false) { create(:user) }

  let(:start_date) { 60.days.ago.iso8601 }
  let(:end_date) { Time.current.iso8601 }

  before do
    stub_licensed_features(ai_analytics: true)
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
      .with(current_user, :read_pro_ai_analytics, anything)
      .and_return(true)
  end

  describe GraphQL::Query, type: :request do
    query_path = 'analytics/dashboards/ai_impact/graphql/duo_agent_platform_agent_flows_users_count.query.graphql'

    context 'with sessions data' do
      before do
        clickhouse_fixture(:ai_usage_events, [
          {
            user_id: user1.id,
            event: Ai::UsageEvent.events[:agent_platform_session_created],
            timestamp: 30.days.ago,
            namespace_path: project.project_namespace.traversal_path(with_organization: false),
            extras: { flow_type: 'duo_chat', session_id: 1, environment: 'prod', project_id: project.id }
          },
          {
            user_id: user2.id,
            event: Ai::UsageEvent.events[:agent_platform_session_created],
            timestamp: 15.days.ago,
            namespace_path: project.project_namespace.traversal_path(with_organization: false),
            extras: { flow_type: 'code_review', session_id: 2, environment: 'prod', project_id: project.id }
          }
        ])
      end

      it "ee/graphql/#{query_path}.json" do
        query = get_graphql_query_as_string(query_path)
        post_graphql(query, current_user: current_user,
          variables: { fullPath: group.full_path, startDate: start_date, endDate: end_date })

        expect_graphql_errors_to_be_empty
      end
    end

    context 'with no sessions data' do
      it "ee/graphql/#{query_path}.empty.json" do
        query = get_graphql_query_as_string(query_path)
        post_graphql(query, current_user: current_user,
          variables: { fullPath: group.full_path, startDate: start_date, endDate: end_date })

        expect_graphql_errors_to_be_empty
      end
    end

    context 'with previous period sessions data' do
      before do
        clickhouse_fixture(:ai_usage_events, [
          {
            user_id: user1.id,
            event: Ai::UsageEvent.events[:agent_platform_session_created],
            timestamp: 45.days.ago,
            namespace_path: project.project_namespace.traversal_path(with_organization: false),
            extras: { flow_type: 'duo_chat', session_id: 3, environment: 'prod', project_id: project.id }
          }
        ])
      end

      it "ee/graphql/#{query_path}.previous.json" do
        query = get_graphql_query_as_string(query_path)
        post_graphql(query, current_user: current_user,
          variables: { fullPath: group.full_path, startDate: 60.days.ago.iso8601, endDate: 31.days.ago.iso8601 })

        expect_graphql_errors_to_be_empty
      end
    end
  end
end
