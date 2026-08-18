# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Code Suggestions acceptance by IDE (GraphQL fixtures)', :click_house,
  feature_category: :value_stream_management do
  include ApiHelpers
  include JavaScriptFixturesHelpers
  include GraphqlHelpers
  include ClickHouseHelpers

  let_it_be(:group) { create(:group, name: 'cool-group') }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user, reporter_of: group) }
  let_it_be(:user) { create(:user) }

  let(:start_date) { 30.days.ago.iso8601 }
  let(:end_date) { Time.current.iso8601 }

  let(:shown_event) { Ai::UsageEvent.events[:code_suggestion_shown_in_ide] }
  let(:accepted_event) { Ai::UsageEvent.events[:code_suggestion_accepted_in_ide] }

  query_path = 'analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_ide.query.graphql'

  def seed_suggestions(suggestions)
    events = suggestions.flat_map do |suggestion|
      extras = { unique_tracking_id: suggestion[:uid], ide_name: suggestion[:ide_name] }.to_json

      rows = [event_row(event: shown_event, timestamp: suggestion[:shown_at], extras: extras)]
      rows << event_row(event: accepted_event, timestamp: suggestion[:accepted_at], extras: extras) if
        suggestion[:accepted_at]

      rows
    end

    clickhouse_fixture(:ai_usage_events, events)
  end

  def event_row(event:, timestamp:, extras:)
    {
      user_id: user.id,
      event: event,
      timestamp: timestamp,
      namespace_path: project.project_namespace.traversal_path(with_organization: false),
      extras: extras
    }
  end

  def generate_fixture(query_path)
    query = get_graphql_query_as_string(query_path)

    post_graphql(query, current_user: current_user,
      variables: { fullPath: group.full_path, startDate: start_date, endDate: end_date })
  end

  before do
    stub_licensed_features(ai_analytics: true)
    allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
  end

  describe GraphQL::Query, type: :request do
    context 'with code suggestions data' do
      before do
        seed_suggestions([
          # PyCharm: 2 shown, 0 accepted -> acceptanceRate 0.0
          { uid: 'uid-1', ide_name: 'PyCharm', shown_at: 10.days.ago },
          { uid: 'uid-2', ide_name: 'PyCharm', shown_at: 9.days.ago },
          # RubyMine: 4 shown, 3 accepted -> acceptanceRate 0.75
          { uid: 'uid-3', ide_name: 'RubyMine', shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { uid: 'uid-4', ide_name: 'RubyMine', shown_at: 9.days.ago, accepted_at: 9.days.ago + 5.seconds },
          { uid: 'uid-5', ide_name: 'RubyMine', shown_at: 8.days.ago, accepted_at: 8.days.ago + 5.seconds },
          { uid: 'uid-6', ide_name: 'RubyMine', shown_at: 7.days.ago }
        ])
      end

      it "ee/graphql/#{query_path}.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'without code suggestions data' do
      it "ee/graphql/#{query_path}.empty.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'with an unnamed IDE' do
      before do
        seed_suggestions([
          { uid: 'uid-1', ide_name: '', shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { uid: 'uid-2', ide_name: 'VS Code', shown_at: 9.days.ago, accepted_at: 9.days.ago + 5.seconds }
        ])
      end

      it "ee/graphql/#{query_path}.with_empty_ide.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'without accepted suggestions' do
      before do
        seed_suggestions([
          { uid: 'uid-1', ide_name: 'PyCharm', shown_at: 10.days.ago },
          { uid: 'uid-2', ide_name: 'RubyMine', shown_at: 9.days.ago }
        ])
      end

      it "ee/graphql/#{query_path}.zero_accepted.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'with an IDE that has no shown suggestions' do
      before do
        clickhouse_fixture(:ai_usage_events, [
          # Xcode: accepted but never shown -> shownCount 0 -> acceptanceRate null
          event_row(event: accepted_event, timestamp: 10.days.ago,
            extras: { unique_tracking_id: 'uid-1', ide_name: 'Xcode' }.to_json),
          # VS Code: a normal shown + accepted suggestion so the result is not empty
          event_row(event: shown_event, timestamp: 9.days.ago,
            extras: { unique_tracking_id: 'uid-2', ide_name: 'VS Code' }.to_json),
          event_row(event: accepted_event, timestamp: 9.days.ago + 5.seconds,
            extras: { unique_tracking_id: 'uid-2', ide_name: 'VS Code' }.to_json)
        ])
      end

      it "ee/graphql/#{query_path}.null_acceptance_rate.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end
  end
end
