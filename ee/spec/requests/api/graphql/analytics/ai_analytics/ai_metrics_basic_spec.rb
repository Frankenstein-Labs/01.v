# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'aiMetricsBasic', :freeze_time, feature_category: :value_stream_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, name: 'my-group') }
  let_it_be(:current_user) { create(:user, reporter_of: group) }
  let_it_be(:project_1) { create(:project, group: group) }
  let_it_be(:project_2) { create(:project, group: group) }

  let(:ai_metrics_basic_fields) do
    query_graphql_field(:aiMetricsBasic, filter_params, fields)
  end

  let(:filter_params) { {} }

  shared_examples 'common ai metrics basic' do
    let(:fields) do
      <<~FIELDS
        codeSuggestions {
          shownCount
          acceptedCount
        }
      FIELDS
    end

    let(:from) { 30.days.ago.to_date }
    let(:to) { Date.current }
    let(:filter_params) { { startDate: from, endDate: to } }

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
        .with(current_user, :read_pro_ai_analytics, anything)
        .and_return(true)
    end

    context 'with code suggestion events' do
      let_it_be(:events) do
        # Code suggestions shown events
        create(:ai_events_count,
          namespace: project_1.project_namespace,
          event: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
          events_date: 15.days.ago.to_date,
          total_occurrences: 25
        )

        create(:ai_events_count,
          namespace: project_2.project_namespace,
          event: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
          events_date: 5.days.ago.to_date,
          total_occurrences: 30
        )

        # Code suggestions accepted events
        create(:ai_events_count,
          namespace: project_1.project_namespace,
          event: Ai::EventsCount.events[:code_suggestion_accepted_in_ide],
          events_date: 10.days.ago.to_date,
          total_occurrences: 15
        )

        create(:ai_events_count,
          namespace: project_2.project_namespace,
          event: Ai::EventsCount.events[:code_suggestion_accepted_in_ide],
          events_date: 8.days.ago.to_date,
          total_occurrences: 20
        )

        # not included - outside of date range
        create(:ai_events_count,
          namespace: project_1.project_namespace,
          event: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
          events_date: 60.days.ago.to_date,
          total_occurrences: 100
        )

        # not included - namespace outside of hierarchy
        other_namespace = create(:project).project_namespace
        create(:ai_events_count,
          namespace: other_namespace,
          event: Ai::EventsCount.events[:code_suggestion_shown_in_ide],
          events_date: 5.days.ago.to_date,
          total_occurrences: 50
        )
      end

      it 'returns code suggestion metrics' do
        post_graphql(query, current_user: current_user)

        expect(ai_metrics_basic).to eq(expected_results)
      end
    end

    context 'when no events exist' do
      it 'returns zero counts' do
        post_graphql(query, current_user: current_user)

        expected_results = {
          'codeSuggestions' => {
            'shownCount' => 0,
            'acceptedCount' => 0
          }
        }

        expect(ai_metrics_basic).to eq(expected_results)
      end
    end
  end

  context 'for group' do
    let(:namespace) { group }
    let(:query) { graphql_query_for(:group, { fullPath: group.full_path }, ai_metrics_basic_fields) }
    let(:ai_metrics_basic) { graphql_data['group']['aiMetricsBasic'] }
    let(:expected_results) do
      {
        'codeSuggestions' => {
          'shownCount' => 55,
          'acceptedCount' => 35
        }
      }
    end

    it_behaves_like 'common ai metrics basic'
  end

  context 'for project' do
    let(:query) { graphql_query_for(:project, { fullPath: project_1.full_path }, ai_metrics_basic_fields) }
    let(:ai_metrics_basic) { graphql_data['project']['aiMetricsBasic'] }
    let(:expected_results) do
      {
        'codeSuggestions' => {
          'shownCount' => 25,
          'acceptedCount' => 15
        }
      }
    end

    it_behaves_like 'common ai metrics basic'
  end
end
