# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Code Suggestions acceptance by language (GraphQL fixtures)', :click_house,
  feature_category: :custom_dashboards_foundation do
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

  query_path = 'analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_language.query.graphql'

  def seed_suggestions(suggestions)
    events = suggestions.flat_map do |suggestion|
      extras = { unique_tracking_id: suggestion[:uid], language: suggestion[:language] }.to_json

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
          # ruby: 2 shown, 1 accepted -> acceptanceRate 0.5
          { uid: 'uid-1', language: 'ruby', shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { uid: 'uid-2', language: 'ruby', shown_at: 9.days.ago },
          # python: 2 shown, 2 accepted -> acceptanceRate 1.0
          { uid: 'uid-3', language: 'python', shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { uid: 'uid-4', language: 'python', shown_at: 9.days.ago, accepted_at: 9.days.ago + 5.seconds }
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

    context 'with language variants that map to the same display name' do
      before do
        seed_suggestions([
          # js: 1 shown, 1 accepted
          { uid: 'uid-1', language: 'js', shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          # ruby: 2 shown, 2 accepted -> acceptanceRate 1.0
          { uid: 'uid-2', language: 'ruby', shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { uid: 'uid-3', language: 'ruby', shown_at: 9.days.ago, accepted_at: 9.days.ago + 5.seconds },
          # javascript: 3 shown, 3 accepted (combined with `js` -> 4 shown, 4 accepted)
          { uid: 'uid-4', language: 'javascript', shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { uid: 'uid-5', language: 'javascript', shown_at: 9.days.ago, accepted_at: 9.days.ago + 5.seconds },
          { uid: 'uid-6', language: 'javascript', shown_at: 8.days.ago, accepted_at: 8.days.ago + 5.seconds }
        ])
      end

      it "ee/graphql/#{query_path}.language_variants.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'with an empty language' do
      before do
        seed_suggestions([
          { uid: 'uid-1', language: '', shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { uid: 'uid-2', language: 'ruby', shown_at: 9.days.ago, accepted_at: 9.days.ago + 5.seconds }
        ])
      end

      it "ee/graphql/#{query_path}.with_empty_language.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'without accepted suggestions' do
      before do
        seed_suggestions([
          { uid: 'uid-1', language: 'python', shown_at: 10.days.ago },
          { uid: 'uid-2', language: 'ruby', shown_at: 9.days.ago }
        ])
      end

      it "ee/graphql/#{query_path}.zero_accepted.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end

    context 'with a language that has no shown suggestions' do
      before do
        clickhouse_fixture(:ai_usage_events, [
          # swift: accepted but never shown -> shownCount 0 -> acceptanceRate null
          event_row(event: accepted_event, timestamp: 10.days.ago,
            extras: { unique_tracking_id: 'uid-1', language: 'swift' }.to_json),
          # ruby: a normal shown + accepted suggestion so the result is not empty
          event_row(event: shown_event, timestamp: 9.days.ago,
            extras: { unique_tracking_id: 'uid-2', language: 'ruby' }.to_json),
          event_row(event: accepted_event, timestamp: 9.days.ago + 5.seconds,
            extras: { unique_tracking_id: 'uid-2', language: 'ruby' }.to_json)
        ])
      end

      it "ee/graphql/#{query_path}.null_acceptance_rate.json" do
        generate_fixture(query_path)

        expect_graphql_errors_to_be_empty
      end
    end
  end
end
