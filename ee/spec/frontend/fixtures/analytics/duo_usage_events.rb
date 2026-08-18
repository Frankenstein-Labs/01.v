# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Usage Events (GraphQL fixtures)', :click_house,
  feature_category: :value_stream_management do
  include ApiHelpers
  include JavaScriptFixturesHelpers
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:group, freeze: false) { create(:group, name: 'cool-group') }
  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:current_user, freeze: false) { create(:user, reporter_of: group) }
  let_it_be(:power_user_1, freeze: false) { create(:user) }
  let_it_be(:power_user_2, freeze: false) { create(:user) }
  let_it_be(:non_power_user, freeze: false) { create(:user) }

  let(:start_date) { 30.days.ago.iso8601 }
  let(:end_date) { Time.current.iso8601 }

  # Fixed, pinned dates for the retention fixtures so the generated series are
  # deterministic. 2020-06-01 and 2020-06-08 are consecutive Mondays, keeping
  # them in two distinct weekly buckets within the pinned Jest window.
  let(:retention_start_date) { '2020-01-06T00:00:00Z' }
  let(:retention_end_date) { '2020-07-06T00:00:00Z' }
  let(:week_one) { Time.utc(2020, 6, 1) }
  let(:week_two) { Time.utc(2020, 6, 8) }

  let(:code_suggestion_event) { Ai::UsageEvent.events[:code_suggestion_shown_in_ide] }
  let(:chat_event) { Ai::UsageEvent.events[:request_duo_chat_response] }
  let(:troubleshoot_event) { Ai::UsageEvent.events[:troubleshoot_job] }
  let(:agent_platform_event) { Ai::UsageEvent.events[:agent_platform_session_created] }
  let(:code_review_event) { Ai::UsageEvent.events[:post_comment_duo_code_review_on_diff] }

  def event_row(user:, event:, timestamp:, extras: '{}')
    {
      user_id: user.id,
      event: event,
      timestamp: timestamp,
      namespace_path: project.project_namespace.traversal_path(with_organization: false),
      extras: extras
    }
  end

  before do
    stub_licensed_features(ai_analytics: true)
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
      .with(current_user, :read_pro_ai_analytics, anything)
      .and_return(true)
  end

  describe GraphQL::Query, type: :request do
    query_path = 'analytics/dashboards/ai_impact/graphql/duo_power_users_count.query.graphql'

    context 'with power users in the current period' do
      before do
        clickhouse_fixture(:ai_usage_events, [
          # power_user_1 used 4 features: code_suggestions, chat, troubleshoot_job, code_review
          event_row(user: power_user_1, event: code_suggestion_event, timestamp: 25.days.ago),
          event_row(user: power_user_1, event: chat_event, timestamp: 20.days.ago),
          event_row(user: power_user_1, event: troubleshoot_event, timestamp: 15.days.ago),
          event_row(user: power_user_1, event: code_review_event, timestamp: 13.days.ago),
          # power_user_2 used 3 features: code_suggestions, chat, agent_platform
          event_row(user: power_user_2, event: code_suggestion_event, timestamp: 22.days.ago),
          event_row(user: power_user_2, event: chat_event, timestamp: 18.days.ago),
          event_row(user: power_user_2, event: agent_platform_event, timestamp: 12.days.ago,
            extras: { session_id: 1, flow_type: 'duo_chat', environment: 'prod', project_id: project.id }.to_json),
          # non_power_user used only 1 feature: chat
          event_row(user: non_power_user, event: chat_event, timestamp: 10.days.ago)
        ])
      end

      it "ee/graphql/#{query_path}.json" do
        query = get_graphql_query_as_string(query_path)
        post_graphql(query, current_user: current_user,
          variables: { fullPath: group.full_path, startDate: start_date, endDate: end_date })

        expect_graphql_errors_to_be_empty
      end
    end

    context 'with previous period power users data' do
      before do
        clickhouse_fixture(:ai_usage_events, [
          # power_user_1 used 3 features in the previous period (days 30-60)
          event_row(user: power_user_1, event: code_suggestion_event, timestamp: 55.days.ago),
          event_row(user: power_user_1, event: chat_event, timestamp: 45.days.ago),
          event_row(user: power_user_1, event: troubleshoot_event, timestamp: 35.days.ago)
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

  describe GraphQL::Query, 'feature retention', type: :request do
    query_path = 'analytics/analytics_dashboards/graphql/queries/get_duo_feature_retention.query.graphql'

    def post_retention_query(query_path, group, current_user, start_date, end_date)
      query = get_graphql_query_as_string(query_path, ee: true)
      post_graphql(query, current_user: current_user,
        variables: {
          fullPath: group.full_path,
          startDate: start_date,
          endDate: end_date,
          feature: %w[code_suggestions chat],
          granularity: 'weekly'
        })
    end

    context 'with retention data across two periods' do
      before do
        clickhouse_fixture(:ai_usage_events, [
          # code_suggestions: week one users [1, 2], week two users [1, 3]
          #   => returning {1} = 1, previous period users = 2  => 50%
          event_row(user: power_user_1, event: code_suggestion_event, timestamp: week_one),
          event_row(user: power_user_2, event: code_suggestion_event, timestamp: week_one),
          event_row(user: power_user_1, event: code_suggestion_event, timestamp: week_two),
          event_row(user: non_power_user, event: code_suggestion_event, timestamp: week_two),
          # chat: week one user [2], week two users [2, 3]
          #   => returning {2} = 1, previous period users = 1  => 100%
          event_row(user: power_user_2, event: chat_event, timestamp: week_one),
          event_row(user: power_user_2, event: chat_event, timestamp: week_two),
          event_row(user: non_power_user, event: chat_event, timestamp: week_two)
        ])
      end

      it "ee/graphql/#{query_path}.json" do
        post_retention_query(query_path, group, current_user, retention_start_date, retention_end_date)
        expect_graphql_errors_to_be_empty
      end
    end

    context 'with no retention data' do
      it "ee/graphql/#{query_path}.empty.json" do
        post_retention_query(query_path, group, current_user, retention_start_date, retention_end_date)
        expect_graphql_errors_to_be_empty
      end
    end
  end
end
