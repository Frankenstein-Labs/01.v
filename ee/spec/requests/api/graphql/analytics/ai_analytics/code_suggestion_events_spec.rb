# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '(Group|Project).aiUsageData.codeSuggestionEvents', :click_house, feature_category: :code_suggestions do
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
        language
        suggestionSize
        uniqueTrackingId
        timestamp
      }
    NODES

    code_suggestion_fields = query_graphql_field(:code_suggestion_events, filter_params, nodes)

    query_graphql_field(:aiUsageData, {}, code_suggestion_fields)
  end

  let(:filter_params) { { startDate: 3.days.ago, endDate: 3.days.since } }

  let_it_be(:code_suggestion_event_1) do
    create(:ai_usage_event, event: :code_suggestion_shown_in_ide, user: user_1,
      namespace: group_project.reload.project_namespace,
      extras: { unique_tracking_id: '1' })
  end

  let_it_be(:code_suggestion_event_2) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_1,
      namespace: subgroup_project.reload.project_namespace,
      extras: { language: 'ruby', suggestion_size: 5, unique_tracking_id: '2' })
  end

  let_it_be(:code_suggestion_event_3) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_2,
      namespace: other_group_project.reload.project_namespace,
      extras: { unique_tracking_id: '3' })
  end

  let_it_be(:code_suggestion_event_4) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_3,
      namespace: subgroup_project.reload.project_namespace,
      extras: { unique_tracking_id: '4' })
  end

  let_it_be(:out_of_timeframe_event) do
    create(:ai_usage_event, event: :code_suggestion_accepted_in_ide, user: user_3,
      namespace: subgroup_project.reload.project_namespace, timestamp: 10.days.ago,
      extras: { unique_tracking_id: '5' })
  end

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
    stub_licensed_features(ai_analytics: true)

    clickhouse_fixture(Ai::UsageEvent.all)

    insert_events_into_click_house([
      build_stubbed(:event, :pushed, project: group_project, author: user_1),
      build_stubbed(:event, :pushed, project: group_project, author: user_1),
      build_stubbed(:event, :pushed, project: subgroup_project, author: user_2),
      build_stubbed(:event, :pushed, project: other_group_project, author: user_3)
    ])
  end

  shared_examples 'code suggestion events' do
    context 'when user cannot read code suggestion events' do
      before_all do
        group.add_guest(current_user)
      end

      it 'returns no data' do
        post_graphql(query, current_user: current_user)

        expect(code_suggestion_events).to be_nil
      end
    end

    context 'when user can read code suggestion events' do
      before_all do
        group.add_reporter(current_user)
      end

      it 'returns code suggestion events' do
        post_graphql(query, current_user: current_user)

        event_ids = code_suggestion_events.pluck('uniqueTrackingId')

        expect(event_ids).to match_array(expected_event_ids)
      end

      it 'returns expanded extras data' do
        post_graphql(query, current_user: current_user)

        event2 = code_suggestion_events.detect { |e| e['uniqueTrackingId'] == '2' }

        expect(event2).to include('language' => 'ruby', 'suggestionSize' => '5', 'uniqueTrackingId' => '2')
      end
    end
  end

  context 'for group' do
    it_behaves_like 'code suggestion events' do
      let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_usage_data_fields) }
      let(:code_suggestion_events) { graphql_data.dig('group', 'aiUsageData', 'codeSuggestionEvents', 'nodes') }
      let(:expected_event_ids) do
        [1, 2, 4].map(&:to_s)
      end
    end
  end

  context 'for project' do
    it_behaves_like 'code suggestion events' do
      let(:query) { graphql_query_for(:project, { fullPath: subgroup_project.full_path }, ai_usage_data_fields) }
      let(:code_suggestion_events) { graphql_data.dig('project', 'aiUsageData', 'codeSuggestionEvents', 'nodes') }

      let(:expected_event_ids) do
        [2, 4].map(&:to_s)
      end
    end
  end
end
