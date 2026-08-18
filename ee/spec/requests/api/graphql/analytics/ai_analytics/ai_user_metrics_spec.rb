# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'aiUserMetrics', :click_house, :freeze_time, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, name: 'my-group') }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user, reporter_of: group) }

  let(:filter_params) { {} }
  let(:fields) { ['user { id }'] }
  let(:ai_user_metrics_fields) { query_nodes(:aiUserMetrics, fields, args: filter_params) }
  let(:event_date) { Time.zone.today.beginning_of_month + 10.days }

  before do
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
      .with(current_user, :read_enterprise_ai_analytics, anything)
      .and_return(true)
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  def usage_events_daily_fixture(events)
    processed = events.map do |row|
      row.merge(
        event: ::Ai::UsageEvent.events[row[:event]],
        date: row.fetch(:date, event_date).to_s
      )
    end
    clickhouse_fixture(:ai_usage_events_daily, processed)
  end

  shared_examples 'ai user metrics query' do
    # expects: query, ai_user_metrics, namespace_path

    context 'with no event data' do
      before do
        post_graphql(query, current_user: current_user)
      end

      it 'returns empty nodes' do
        expect(ai_user_metrics['nodes']).to be_empty
      end
    end

    context 'with event data' do
      before do
        usage_events_daily_fixture([
          {
            user_id: current_user.id,
            namespace_path: namespace_path,
            event: :code_suggestion_accepted_in_ide,
            occurrences: 8
          },
          {
            user_id: current_user.id,
            namespace_path: namespace_path,
            event: :request_duo_chat_response,
            occurrences: 3
          }
        ])

        post_graphql(query, current_user: current_user)
      end

      it 'returns user information' do
        expect(ai_user_metrics['nodes'].first['user']).to eq({ 'id' => current_user.to_global_id.to_s })
      end

      context 'when querying totalEventCount' do
        let(:fields) { ['user { id }', 'totalEventCount'] }

        it 'returns the sum of all event counts' do
          expect(ai_user_metrics['nodes'].first['totalEventCount']).to eq(11)
        end
      end

      context 'when querying feature-specific fields' do
        let(:fields) do
          [
            'user { id }',
            'codeSuggestions { codeSuggestionAcceptedInIdeEventCount codeSuggestionShownInIdeEventCount }',
            'chat { requestDuoChatResponseEventCount }'
          ]
        end

        it 'returns correct event counts and defaults missing events to 0' do
          node = ai_user_metrics['nodes'].first

          expect(node['codeSuggestions']).to include(
            'codeSuggestionAcceptedInIdeEventCount' => 8,
            'codeSuggestionShownInIdeEventCount' => 0
          )
          expect(node['chat']).to include('requestDuoChatResponseEventCount' => 3)
        end
      end

      context 'when querying deprecated fields' do
        let(:fields) do
          [
            'user { id }',
            'codeSuggestionsAcceptedCount',
            'duoChatInteractionsCount',
            'codeSuggestions { codeSuggestionAcceptedInIdeEventCount }',
            'chat { requestDuoChatResponseEventCount }'
          ]
        end

        it 'returns values for deprecated fields' do
          node = ai_user_metrics['nodes'].first

          expect(node).to include(
            'codeSuggestionsAcceptedCount' => 8,
            'duoChatInteractionsCount' => 3
          )
        end

        it 'returns values for new fields' do
          node = ai_user_metrics['nodes'].first

          expect(node['codeSuggestions']).to include('codeSuggestionAcceptedInIdeEventCount' => 8)
          expect(node['chat']).to include('requestDuoChatResponseEventCount' => 3)
        end
      end

      context 'when querying lastDuoActivityOn' do
        let(:fields) do
          ['user { id lastDuoActivityOn }', 'lastDuoActivityOn', 'codeSuggestions { lastDuoActivityOn }']
        end

        let_it_be(:current_user_metrics) do
          create(:ai_user_metrics, last_duo_activity_on: 5.days.ago.to_date, user: current_user)
        end

        it 'returns the last activity date for the feature' do
          expect(ai_user_metrics['nodes'].first['codeSuggestions']['lastDuoActivityOn'])
            .to eq(event_date.to_date.to_s)
        end

        it 'returns the last activity date across all features' do
          expect(ai_user_metrics['nodes'].first['lastDuoActivityOn']).to eq(event_date.to_date.to_s)
        end

        it 'returns the last activity date for the user from the database' do
          expect(ai_user_metrics['nodes'].first['user']['lastDuoActivityOn'])
            .to eq(5.days.ago.to_date.to_s)
        end
      end
    end

    context 'with date filtering' do
      context 'when filter range exceeds maximum' do
        let(:filter_params) { { startDate: 5.years.ago } }

        before do
          post_graphql(query, current_user: current_user)
        end

        it 'returns an error' do
          expect_graphql_errors_to_include("maximum date range is 1 year")
          expect(ai_user_metrics).to be_nil
        end
      end
    end

    context 'when ClickHouse is unavailable' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
        post_graphql(query, current_user: current_user)
      end

      it 'returns empty nodes' do
        expect(ai_user_metrics['nodes']).to be_empty
      end
    end
  end

  context 'for group' do
    it_behaves_like 'ai user metrics query' do
      let(:namespace_path) { group.traversal_path(with_organization: false) }
      let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_user_metrics_fields) }
      let(:ai_user_metrics) { graphql_data['group']['aiUserMetrics'] }
    end
  end

  context 'for project' do
    it_behaves_like 'ai user metrics query' do
      let(:namespace_path) { project.project_namespace.reload.traversal_path(with_organization: false) }
      let(:query) { graphql_query_for(:project, { fullPath: project.full_path }, ai_user_metrics_fields) }
      let(:ai_user_metrics) { graphql_data['project']['aiUserMetrics'] }
    end
  end

  context 'with granular token authorization' do
    # The token also needs the parent type's permission (read_group / read_project)
    # to authorize the enclosing type; read_enterprise_ai_analytics (assignable as
    # read_ai_usage_metric) authorizes the field.
    context 'for group' do
      let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_user_metrics_fields) }

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:read_group, :read_enterprise_ai_analytics] do
        let(:user) { current_user }
        let(:boundary_object) { group }
        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
      end

      context 'when the token authorizes only the parent group' do
        let(:pat) do
          create(:granular_pat, user: current_user, boundary: ::Authz::Boundary.for(group),
            permissions: %w[read_group])
        end

        it 'returns the group but not aiUserMetrics' do
          post_graphql(query, token: { personal_access_token: pat })

          expect(graphql_data_at(:group)).to be_present
          expect(graphql_data_at(:group, :ai_user_metrics)).to be_nil
        end
      end
    end

    context 'for project' do
      let(:query) { graphql_query_for(:project, { fullPath: project.full_path }, ai_user_metrics_fields) }

      it_behaves_like 'authorizing granular token permissions for GraphQL',
        [:read_project, :read_enterprise_ai_analytics] do
        let(:user) { current_user }
        let(:boundary_object) { project }
        let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
      end

      context 'when the token authorizes only the parent project' do
        let(:pat) do
          create(:granular_pat, user: current_user, boundary: ::Authz::Boundary.for(project),
            permissions: %w[read_project])
        end

        it 'returns the project but not aiUserMetrics' do
          post_graphql(query, token: { personal_access_token: pat })

          expect(graphql_data_at(:project)).to be_present
          expect(graphql_data_at(:project, :ai_user_metrics)).to be_nil
        end
      end
    end
  end

  context 'with sorting' do
    let_it_be(:user1) { create(:user, reporter_of: group) }
    let_it_be(:user2) { create(:user, reporter_of: group) }
    let_it_be(:user3) { create(:user, reporter_of: group) }
    let_it_be(:user4) { create(:user, reporter_of: group) }

    let(:fields) { ['user { id }'] }
    let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_user_metrics_fields) }
    let(:ai_user_metrics) { graphql_data['group']['aiUserMetrics'] }

    before do
      date = Time.zone.today.beginning_of_month + 15.days
      # user1: 100 shown, 50 accepted, 25 rejected | 30 chat requests
      # user2: 60 shown, 80 accepted, 40 rejected | 100 chat requests
      # user3: 40 shown, 30 accepted, 60 rejected | 50 chat requests
      # user4: 20 shown, 10 accepted, 5 rejected | 80 chat requests
      usage_events_daily_fixture([
        # Code suggestions - shown
        { user_id: user1.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_shown_in_ide, date: date, occurrences: 100 },
        { user_id: user2.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_shown_in_ide, date: date, occurrences: 60 },
        { user_id: user3.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_shown_in_ide, date: date, occurrences: 40 },
        { user_id: user4.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_shown_in_ide, date: date, occurrences: 20 },
        # Code suggestions - accepted
        { user_id: user1.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_accepted_in_ide, date: date, occurrences: 50 },
        { user_id: user2.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_accepted_in_ide, date: date, occurrences: 80 },
        { user_id: user3.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_accepted_in_ide, date: date, occurrences: 30 },
        { user_id: user4.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_accepted_in_ide, date: date, occurrences: 10 },
        # Code suggestions - rejected
        { user_id: user1.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_rejected_in_ide, date: date, occurrences: 25 },
        { user_id: user2.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_rejected_in_ide, date: date, occurrences: 40 },
        { user_id: user3.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_rejected_in_ide, date: date, occurrences: 60 },
        { user_id: user4.id, namespace_path: group.traversal_path(with_organization: false),
          event: :code_suggestion_rejected_in_ide, date: date, occurrences: 5 },
        # Chat events
        { user_id: user1.id, namespace_path: group.traversal_path(with_organization: false),
          event: :request_duo_chat_response, date: date, occurrences: 30 },
        { user_id: user2.id, namespace_path: group.traversal_path(with_organization: false),
          event: :request_duo_chat_response, date: date, occurrences: 100 },
        { user_id: user3.id, namespace_path: group.traversal_path(with_organization: false),
          event: :request_duo_chat_response, date: date, occurrences: 50 },
        { user_id: user4.id, namespace_path: group.traversal_path(with_organization: false),
          event: :request_duo_chat_response, date: date, occurrences: 80 }
      ])
    end

    it 'sorts by code suggestions total count descending' do
      filter_params[:sort] = :CODE_SUGGESTIONS_TOTAL_COUNT_DESC
      post_graphql(query, current_user: current_user)

      user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
      # user2: 180 total (60+80+40), user1: 175 total (100+50+25), user3: 130 (40+30+60), user4: 35 (20+10+5)
      expect(user_ids).to eq([user2, user1, user3, user4].map { |u| u.to_global_id.to_s })
    end

    it 'sorts by code suggestions total count ascending' do
      filter_params[:sort] = :CODE_SUGGESTIONS_TOTAL_COUNT_ASC
      post_graphql(query, current_user: current_user)

      user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
      # user4: 35, user3: 130, user1: 175, user2: 180
      expect(user_ids).to eq([user4, user3, user1, user2].map { |u| u.to_global_id.to_s })
    end

    it 'sorts by chat total count descending' do
      filter_params[:sort] = :CHAT_TOTAL_COUNT_DESC
      post_graphql(query, current_user: current_user)

      user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
      # user2: 100, user4: 80, user3: 50, user1: 30
      expect(user_ids).to eq([user2, user4, user3, user1].map { |u| u.to_global_id.to_s })
    end

    context 'with total events count sorting' do
      it 'sorts by total events count descending' do
        filter_params[:sort] = :TOTAL_EVENTS_COUNT_DESC
        post_graphql(query, current_user: current_user)

        user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
        # user2: 280 (60+80+40+100), user1: 205 (100+50+25+30), user3: 180 (40+30+60+50), user4: 115 (20+10+5+80)
        expect(user_ids).to eq([user2, user1, user3, user4].map { |u| u.to_global_id.to_s })
      end

      it 'sorts by total events count ascending' do
        filter_params[:sort] = :TOTAL_EVENTS_COUNT_ASC
        post_graphql(query, current_user: current_user)

        user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
        # user4: 115, user3: 180, user1: 205, user2: 280
        expect(user_ids).to eq([user4, user3, user1, user2].map { |u| u.to_global_id.to_s })
      end
    end

    context 'with event-level sorting' do
      it 'sorts by code_suggestion_shown_in_ide descending' do
        filter_params[:sort] = :CODE_SUGGESTION_SHOWN_IN_IDE_DESC
        post_graphql(query, current_user: current_user)

        user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
        # user1: 100, user2: 60, user3: 40, user4: 20
        expect(user_ids).to eq([user1, user2, user3, user4].map { |u| u.to_global_id.to_s })
      end

      it 'sorts by code_suggestion_shown_in_ide ascending' do
        filter_params[:sort] = :CODE_SUGGESTION_SHOWN_IN_IDE_ASC
        post_graphql(query, current_user: current_user)

        user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
        # user4: 20, user3: 40, user2: 60, user1: 100
        expect(user_ids).to eq([user4, user3, user2, user1].map { |u| u.to_global_id.to_s })
      end

      it 'sorts by code_suggestion_accepted_in_ide descending' do
        filter_params[:sort] = :CODE_SUGGESTION_ACCEPTED_IN_IDE_DESC
        post_graphql(query, current_user: current_user)

        user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
        # user2: 80, user1: 50, user3: 30, user4: 10
        expect(user_ids).to eq([user2, user1, user3, user4].map { |u| u.to_global_id.to_s })
      end

      it 'sorts by code_suggestion_rejected_in_ide descending' do
        filter_params[:sort] = :CODE_SUGGESTION_REJECTED_IN_IDE_DESC
        post_graphql(query, current_user: current_user)

        user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
        # user3: 60, user2: 40, user1: 25, user4: 5
        expect(user_ids).to eq([user3, user2, user1, user4].map { |u| u.to_global_id.to_s })
      end

      it 'sorts by request_duo_chat_response descending' do
        filter_params[:sort] = :REQUEST_DUO_CHAT_RESPONSE_DESC
        post_graphql(query, current_user: current_user)

        user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
        # user2: 100, user4: 80, user3: 50, user1: 30
        expect(user_ids).to eq([user2, user4, user3, user1].map { |u| u.to_global_id.to_s })
      end

      it 'sorts by request_duo_chat_response ascending' do
        filter_params[:sort] = :REQUEST_DUO_CHAT_RESPONSE_ASC
        post_graphql(query, current_user: current_user)

        user_ids = ai_user_metrics['nodes'].map { |node| node['user']['id'] }
        # user1: 30, user3: 50, user4: 80, user2: 100
        expect(user_ids).to eq([user1, user3, user4, user2].map { |u| u.to_global_id.to_s })
      end
    end

    context 'when ClickHouse is unavailable' do
      let(:fields) { ['user { id }', 'totalEventCount'] }
      let(:filter_params) { { sort: :CODE_SUGGESTIONS_TOTAL_COUNT_DESC } }

      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
        post_graphql(query, current_user: current_user)
      end

      it 'returns empty nodes' do
        expect(ai_user_metrics).to eq({ 'nodes' => [] })
      end
    end

    context 'with cursor-based pagination on computed sort column' do
      let(:pagination_query) do
        <<~QUERY
          query($fullPath: ID!, $cursor: String) {
            group(fullPath: $fullPath) {
              aiUserMetrics(sort: CODE_SUGGESTION_SHOWN_IN_IDE_DESC, first: 2, after: $cursor) {
                nodes {
                  user { id }
                }
                pageInfo {
                  endCursor
                  hasNextPage
                }
              }
            }
          }
        QUERY
      end

      it 'navigates pages without error' do
        post_graphql(pagination_query, current_user: current_user,
          variables: { fullPath: group.full_path })

        first_page = graphql_data_at('group', 'aiUserMetrics')
        expect(first_page['nodes'].size).to eq(2)
        expect(first_page['pageInfo']['hasNextPage']).to be true

        cursor = first_page['pageInfo']['endCursor']
        post_graphql(pagination_query, current_user: current_user,
          variables: { fullPath: group.full_path, cursor: cursor })

        second_page = graphql_data_at('group', 'aiUserMetrics')
        expect(second_page['nodes'].size).to eq(2)
        expect(second_page['pageInfo']['hasNextPage']).to be false

        all_ids = (first_page['nodes'] + second_page['nodes']).map { |n| n['user']['id'] }
        expect(all_ids.uniq.size).to eq(4)
      end
    end
  end
end
