# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project).aiUsageData.all', feature_category: :code_suggestions do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, name: 'my-group') }
  let_it_be(:subgroup) { create(:group, parent: group, name: 'my-subgroup') }
  let_it_be(:group_project) { create(:project, group: group) }
  let_it_be(:subgroup_project) { create(:project, group: group) }
  let_it_be(:other_group_project) { create(:project) }
  let_it_be(:current_user) { create(:user, :with_namespace) }
  let_it_be(:user_1) { create(:user, :with_namespace) }
  let_it_be(:user_2) { create(:user, :with_namespace) }
  let_it_be(:user_3) { create(:user, :with_namespace) }

  let(:ai_usage_data_fields) do
    nodes = <<~NODES
      nodes {
        user {
          id
        }
        event
        timestamp
      }
    NODES

    query_graphql_field(:aiUsageData, {}, query_graphql_field(:all, filter_params, nodes))
  end

  let(:filter_params) { { start_date: 3.days.ago, end_date: 3.days.since } }

  # let_it_be_with_reload (not frozen) because these records are passed to
  # #store_to_clickhouse below, which calls #valid? and triggers the
  # before_validation :floor_timestamp callback that mutates the record.
  # A frozen let_it_be record raises FrozenError there.
  let_it_be_with_reload(:code_suggestion_event_1) do
    create(:ai_usage_event, event: :code_suggestion_shown_in_ide, user: user_1,
      namespace: group_project.reload.project_namespace)
  end

  let_it_be_with_reload(:code_suggestion_event_2) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_1,
      namespace: subgroup_project.reload.project_namespace)
  end

  let_it_be_with_reload(:code_suggestion_event_3) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_2,
      namespace: other_group_project.reload.project_namespace)
  end

  let_it_be_with_reload(:code_suggestion_event_4) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_3,
      namespace: subgroup_project.reload.project_namespace)
  end

  let_it_be_with_reload(:out_of_timeframe_event) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_3,
      namespace: subgroup_project.reload.project_namespace, timestamp: 10.days.ago)
  end

  def event_identifier(event)
    {
      user_id: event.user.to_global_id.to_s,
      event: event.event.to_s.upcase,
      timestamp: event.timestamp.iso8601
    }
  end

  def extract_event_identifiers(response_events)
    response_events.map do |event|
      {
        user_id: event.dig('user', 'id'),
        event: event['event'],
        timestamp: event['timestamp']
      }
    end
  end

  before do
    stub_licensed_features(ai_analytics: true)
  end

  shared_examples 'ai usage events endpoint without permissions' do
    it 'returns no data for guests' do
      group.add_guest(current_user)

      post_graphql(query, current_user: current_user)

      expect(response_events).to be_nil
    end

    it 'returns no data for non-licensed namespaces' do
      stub_licensed_features(ai_analytics: false)
      group.add_reporter(current_user)

      post_graphql(query, current_user: current_user)

      expect(response_events).to be_nil
    end
  end

  shared_examples 'ai usage events endpoint with permissions' do
    it 'returns events' do
      group.add_reporter(current_user)

      post_graphql(query, current_user: current_user)

      expected_identifiers = expected_events.map { |event| event_identifier(event) }
      actual_identifiers = extract_event_identifiers(response_events)

      expect(actual_identifiers).to match_array(expected_identifiers)
    end
  end

  shared_examples 'ai usage events endpoint tests' do
    context 'for group' do
      let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_usage_data_fields) }
      let(:response_events) { graphql_data.dig('group', 'aiUsageData', 'all', 'nodes') }

      it_behaves_like 'ai usage events endpoint without permissions'

      it_behaves_like 'ai usage events endpoint with permissions' do
        let(:expected_events) do
          [
            code_suggestion_event_1,
            code_suggestion_event_2,
            code_suggestion_event_4
          ]
        end
      end

      context 'when filtering by users and events' do
        let(:filter_params) do
          super().merge(
            user_ids: [user_1.to_global_id.to_s],
            events: [:CODE_SUGGESTION_SHOWN_IN_IDE]
          )
        end

        it_behaves_like 'ai usage events endpoint with permissions' do
          let(:expected_events) { [code_suggestion_event_1] }
        end
      end
    end

    context 'for project' do
      let(:query) { graphql_query_for(:project, { fullPath: subgroup_project.full_path }, ai_usage_data_fields) }
      let(:response_events) { graphql_data.dig('project', 'aiUsageData', 'all', 'nodes') }

      it_behaves_like 'ai usage events endpoint without permissions'

      it_behaves_like 'ai usage events endpoint with permissions' do
        let(:expected_events) do
          [
            code_suggestion_event_2,
            code_suggestion_event_4
          ]
        end
      end

      context 'when filtering by users and events' do
        let(:filter_params) do
          super().merge(
            user_ids: [user_1.to_global_id.to_s],
            events: [:CODE_SUGGESTION_ACCEPTED_IN_IDE]
          )
        end

        it_behaves_like 'ai usage events endpoint with permissions' do
          let(:expected_events) { [code_suggestion_event_2] }
        end
      end
    end
  end

  context 'when using PostgreSQL data source' do
    before do
      allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(false)
    end

    it_behaves_like 'ai usage events endpoint tests'
  end

  context 'when using ClickHouse data source', :click_house do
    include ClickHouseHelpers

    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

      [
        code_suggestion_event_1,
        code_suggestion_event_2,
        code_suggestion_event_3,
        code_suggestion_event_4,
        out_of_timeframe_event
      ].map(&:store_to_clickhouse)

      ClickHouse::DumpWriteBufferWorker.new.perform(Ai::UsageEvent.clickhouse_table_name)
    end

    it_behaves_like 'ai usage events endpoint tests'

    context 'when there are duplicate events' do
      let_it_be(:duplicate_event) do
        create(:ai_usage_event, event: :code_suggestion_shown_in_ide, user: user_1,
          namespace: group_project.reload.project_namespace)
      end

      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)

        # Create duplicate entries with the same grouping key (user_id, namespace_path, event, timestamp)
        # to test that deduplication via GROUP BY works correctly
        clickhouse_fixture(:ai_usage_events, [
          {
            user_id: user_1.id,
            namespace_path: group_project.project_namespace.traversal_path(with_organization: false),
            event: ::Ai::UsageEvent.events[:code_suggestion_shown_in_ide],
            timestamp: duplicate_event.timestamp.utc.strftime('%Y-%m-%d %H:%M:%S.%6N')
          },
          {
            user_id: user_1.id,
            namespace_path: group_project.project_namespace.traversal_path(with_organization: false),
            event: ::Ai::UsageEvent.events[:code_suggestion_shown_in_ide],
            timestamp: duplicate_event.timestamp.utc.strftime('%Y-%m-%d %H:%M:%S.%6N')
          },
          {
            user_id: user_1.id,
            namespace_path: group_project.project_namespace.traversal_path(with_organization: false),
            event: ::Ai::UsageEvent.events[:code_suggestion_shown_in_ide],
            timestamp: duplicate_event.timestamp.utc.strftime('%Y-%m-%d %H:%M:%S.%6N')
          }
        ])
      end

      context 'for group' do
        let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_usage_data_fields) }
        let(:response_events) { graphql_data.dig('group', 'aiUsageData', 'all', 'nodes') }

        before_all do
          group.add_reporter(current_user)
        end

        it 'deduplicates events and returns only one event per unique combination' do
          post_graphql(query, current_user: current_user)

          duplicate_events = response_events.select do |event|
            event.dig('user', 'id') == user_1.to_global_id.to_s &&
              event['event'] == 'CODE_SUGGESTION_SHOWN_IN_IDE' &&
              event['timestamp'] == duplicate_event.timestamp.iso8601
          end

          expect(duplicate_events.count).to eq(1)
        end
      end

      context 'for project' do
        let(:query) { graphql_query_for(:project, { fullPath: group_project.full_path }, ai_usage_data_fields) }
        let(:response_events) { graphql_data.dig('project', 'aiUsageData', 'all', 'nodes') }

        before_all do
          group.add_reporter(current_user)
        end

        it 'deduplicates events and returns only one event per unique combination' do
          post_graphql(query, current_user: current_user)

          duplicate_events = response_events.select do |event|
            event.dig('user', 'id') == user_1.to_global_id.to_s &&
              event['event'] == 'CODE_SUGGESTION_SHOWN_IN_IDE' &&
              event['timestamp'] == duplicate_event.timestamp.iso8601
          end

          expect(duplicate_events.count).to eq(1)
        end
      end
    end
  end
end
