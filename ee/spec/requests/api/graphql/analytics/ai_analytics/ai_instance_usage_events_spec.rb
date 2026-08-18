# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'aiUsageData.all', feature_category: :code_suggestions do
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
  let_it_be(:admin) { create(:admin) }

  # let_it_be_with_reload (not frozen) because these records are passed to
  # #store_to_clickhouse below, which calls #valid? and triggers the
  # before_validation :floor_timestamp callback that mutates the record.
  # A frozen let_it_be record raises FrozenError there.
  let_it_be_with_reload(:event_1) do
    create(:ai_usage_event, event: :code_suggestion_shown_in_ide, user: user_1,
      namespace: group_project.reload.project_namespace)
  end

  let_it_be_with_reload(:event_2) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_2,
      namespace: subgroup_project.reload.project_namespace)
  end

  let_it_be_with_reload(:event_3) do
    create(:ai_usage_event, event: :code_suggestion_rejected_in_ide, user: user_3,
      namespace: other_group_project.reload.project_namespace, extras: { foo: :bar })
  end

  let_it_be_with_reload(:event_4) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_3,
      namespace: nil, extras: { foo: :bar })
  end

  let_it_be_with_reload(:out_of_range_event) do
    create(:ai_usage_event, event: :code_suggestion_rejected_in_ide, user: user_3,
      namespace: other_group_project.reload.project_namespace, extras: { foo: :bar }, timestamp: 10.days.ago)
  end

  let_it_be_with_reload(:all_declared_events) do
    Gitlab::Tracking::AiTracking.registered_events.filter_map do |name, _id|
      next if Gitlab::Tracking::AiTracking.deprecated_event?(name)

      create(:ai_usage_event, event: name, user: user_3, namespace: group)
    end
  end

  let(:filter_params) { { start_date: 3.days.ago, end_date: 3.days.since } }

  let(:query) do
    nodes = <<~NODES
      nodes {
        user {
          id
        }
        event
        timestamp
        extras
        namespacePath
      }
    NODES

    graphql_query_for(:aiUsageData, {}, query_graphql_field(:all, filter_params, nodes))
  end

  let(:response_events) { graphql_data.dig('aiUsageData', 'all', 'nodes') }

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

  shared_examples 'ai usage events endpoint with permissions' do
    let_it_be(:current_user) { admin }

    it 'returns events' do
      post_graphql(query, current_user: current_user)

      expected_identifiers = expected_events.map { |event| event_identifier(event) }
      actual_identifiers = extract_event_identifiers(response_events)

      expect(actual_identifiers).to match_array(expected_identifiers)
    end
  end

  shared_examples 'ai usage events endpoint tests' do
    it 'returns no data for non-admins' do
      group.add_owner(current_user)

      post_graphql(query, current_user: current_user)

      expect(response_events).to be_nil
    end

    it_behaves_like 'ai usage events endpoint with permissions' do
      let(:expected_events) do
        [event_1, event_2, event_3, event_4] + all_declared_events
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
        let(:expected_events) do
          [event_1]
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

      ([event_1, event_2, event_3, event_4, out_of_range_event] + all_declared_events).map(&:store_to_clickhouse)

      ClickHouse::DumpWriteBufferWorker.new.perform(Ai::UsageEvent.clickhouse_table_name)
    end

    it_behaves_like 'ai usage events endpoint tests'
  end
end
