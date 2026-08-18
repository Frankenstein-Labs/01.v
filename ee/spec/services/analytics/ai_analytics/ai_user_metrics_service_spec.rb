# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AiAnalytics::AiUserMetricsService, feature_category: :value_stream_management do
  subject(:service_response) do
    described_class.new(
      current_user: current_user,
      namespace: container,
      from: from,
      to: to,
      user_ids: user_ids,
      feature: feature,
      sort: sort
    ).execute
  end

  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: subgroup) }
  let_it_be(:user1) { create(:user, developer_of: group) }
  let_it_be(:user2) { create(:user, developer_of: subgroup) }
  let_it_be(:current_user) { user1 }
  let_it_be(:from) { 14.days.ago }
  let_it_be(:to) { 1.day.ago }
  let_it_be(:user_ids) { [user1.id, user2.id] }
  let_it_be(:feature) { :code_suggestions }

  let(:sort) { nil }

  before do
    allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).and_return(true)
  end

  shared_examples 'ai user metrics service' do
    context 'when ClickHouse is not available' do
      before do
        allow(Gitlab::ClickHouse).to receive(:enabled_for_analytics?).with(container).and_return(false)
      end

      it 'returns error' do
        expect(service_response).to be_error
        expect(service_response.message).to eq(s_('AiAnalytics|the ClickHouse data store is not available'))
      end
    end

    context 'when feature has no registered events', :click_house do
      before do
        allow(Gitlab::Tracking::AiTracking).to receive(:registered_events).with(feature).and_return({})
      end

      it 'returns empty results' do
        expect(service_response).to be_success
        expect(ClickHouse::Client.select(service_response.payload, :main)).to be_empty
      end
    end

    context 'with ClickHouse available', :click_house, :freeze_time do
      let(:raw_results) { ClickHouse::Client.select(service_response.payload, :main) }

      context 'without data' do
        it 'returns empty results' do
          expect(service_response).to be_success
          expect(raw_results).to be_empty
        end
      end

      context 'when feature is :all_features' do
        let(:feature) { :all_features }
        let_it_be(:user3) { create(:user, developer_of: group) }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            # Code suggestions events (event IDs: 2, 3)
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 3.days).to_date, occurrences: 2 },
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 2,
              date: (to - 3.days).to_date, occurrences: 1 },
            # Chat events (event ID: 6)
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 6,
              date: (to - 2.days).to_date, occurrences: 3 },
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 6,
              date: (to - 2.days).to_date, occurrences: 2 },
            # Code review events (event ID: 10)
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 10,
              date: (to - 1.day).to_date, occurrences: 1 }
          ])
        end

        it 'returns aggregated metrics across all features' do
          expect(service_response).to be_success
          expect(raw_results).to include(
            a_hash_including(
              'user_id' => user1.id,
              'total_events_count' => 6,
              'code_suggestion_accepted_in_ide_event_count' => 2,
              'code_suggestion_shown_in_ide_event_count' => 1,
              'request_duo_chat_response_event_count' => 3
            ),
            a_hash_including(
              'user_id' => user2.id,
              'total_events_count' => 3,
              'request_duo_chat_response_event_count' => 2,
              'encounter_duo_code_review_error_during_review_event_count' => 1
            )
          )
        end

        it 'includes last_duo_activity_on when fetching all features' do
          expect(service_response).to be_success
          expect(raw_results).to all(include('last_duo_activity_on'))
        end

        it 'returns the most recent activity date across all features' do
          expect(service_response).to be_success
          user1_row = raw_results.find { |r| r['user_id'] == user1.id }
          user2_row = raw_results.find { |r| r['user_id'] == user2.id }
          expect(user1_row['last_duo_activity_on']).to eq((to - 2.days).to_date)
          expect(user2_row['last_duo_activity_on']).to eq((to - 1.day).to_date)
        end

        it 'includes event counts from all registered features' do
          expect(service_response).to be_success
          expect(raw_results).to all(include(
            'total_events_count',
            'code_suggestion_accepted_in_ide_event_count',
            'code_suggestion_shown_in_ide_event_count',
            'request_duo_chat_response_event_count'
          ))
        end
      end

      context 'with code suggestions data' do
        let_it_be(:other_namespace) { create(:project).reload.project_namespace }
        let_it_be(:user3) { create(:user, developer_of: group) }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 3.days).to_date, occurrences: 2 },
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 2,
              date: (to - 3.days).to_date, occurrences: 1 },
            { user_id: user1.id, namespace_path: other_namespace.traversal_path(with_organization: false), event: 3,
              date: (to - 4.days).to_date, occurrences: 1 },
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 2,
              date: (to - 2.days).to_date, occurrences: 1 },
            { user_id: user2.id, namespace_path: other_namespace.traversal_path(with_organization: false), event: 3,
              date: (to - 2.days).to_date, occurrences: 1 },
            { user_id: user3.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 1.day).to_date, occurrences: 3 }
          ])
        end

        it 'returns only events within the specified namespace' do
          expect(service_response).to be_success
          user1_row = raw_results.find { |r| r['user_id'] == user1.id }
          user2_row = raw_results.find { |r| r['user_id'] == user2.id }

          expect(user1_row).to include(
            'total_events_count' => 3,
            'code_suggestion_accepted_in_ide_event_count' => 2,
            'code_suggestion_direct_access_token_refresh_event_count' => 0,
            'code_suggestion_rejected_in_ide_event_count' => 0,
            'code_suggestion_shown_in_ide_event_count' => 1,
            'code_suggestions_requested_event_count' => 0,
            'last_duo_activity_on' => (to - 3.days).to_date
          )
          expect(user2_row).to include(
            'total_events_count' => 1,
            'code_suggestion_accepted_in_ide_event_count' => 0,
            'code_suggestion_direct_access_token_refresh_event_count' => 0,
            'code_suggestion_rejected_in_ide_event_count' => 0,
            'code_suggestion_shown_in_ide_event_count' => 1,
            'code_suggestions_requested_event_count' => 0,
            'last_duo_activity_on' => (to - 2.days).to_date
          )
        end

        it 'includes last_duo_activity_on with the most recent activity date' do
          expect(service_response).to be_success
          user1_row = raw_results.find { |r| r['user_id'] == user1.id }
          user2_row = raw_results.find { |r| r['user_id'] == user2.id }
          expect(user1_row['last_duo_activity_on']).to eq((to - 3.days).to_date)
          expect(user2_row['last_duo_activity_on']).to eq((to - 2.days).to_date)
        end

        context 'when user_ids is empty' do
          let(:user_ids) { [] }

          it 'returns metrics for all users without filtering by user_ids' do
            expect(service_response).to be_success
            user1_row = raw_results.find { |r| r['user_id'] == user1.id }
            user2_row = raw_results.find { |r| r['user_id'] == user2.id }
            user3_row = raw_results.find { |r| r['user_id'] == user3.id }

            expect(user1_row).to include(
              'total_events_count' => 3,
              'code_suggestion_accepted_in_ide_event_count' => 2,
              'code_suggestion_shown_in_ide_event_count' => 1,
              'last_duo_activity_on' => (to - 3.days).to_date
            )
            expect(user2_row).to include(
              'total_events_count' => 1,
              'code_suggestion_shown_in_ide_event_count' => 1,
              'last_duo_activity_on' => (to - 2.days).to_date
            )
            expect(user3_row).to include(
              'total_events_count' => 3,
              'code_suggestion_accepted_in_ide_event_count' => 3,
              'last_duo_activity_on' => (to - 1.day).to_date
            )
          end
        end

        context 'when user_ids is nil' do
          let(:user_ids) { nil }

          it 'returns metrics for all users without filtering by user_ids' do
            expect(service_response).to be_success
            user1_row = raw_results.find { |r| r['user_id'] == user1.id }
            user2_row = raw_results.find { |r| r['user_id'] == user2.id }
            user3_row = raw_results.find { |r| r['user_id'] == user3.id }

            expect(user1_row).to include(
              'total_events_count' => 3,
              'code_suggestion_accepted_in_ide_event_count' => 2,
              'code_suggestion_shown_in_ide_event_count' => 1,
              'last_duo_activity_on' => (to - 3.days).to_date
            )
            expect(user2_row).to include(
              'total_events_count' => 1,
              'code_suggestion_shown_in_ide_event_count' => 1,
              'last_duo_activity_on' => (to - 2.days).to_date
            )
            expect(user3_row).to include(
              'total_events_count' => 3,
              'code_suggestion_accepted_in_ide_event_count' => 3,
              'last_duo_activity_on' => (to - 1.day).to_date
            )
          end
        end

        context 'when user_ids has specific values' do
          let(:user_ids) { [user1.id] }

          it 'returns metrics only for specified users' do
            expect(service_response).to be_success
            expect(raw_results.pluck('user_id')).to contain_exactly(user1.id)
            expect(raw_results.first).to include(
              'total_events_count' => 3,
              'code_suggestion_accepted_in_ide_event_count' => 2,
              'code_suggestion_shown_in_ide_event_count' => 1,
              'last_duo_activity_on' => (to - 3.days).to_date
            )
          end
        end
      end

      context 'with chat data' do
        let(:feature) { :chat }
        let_it_be(:other_namespace) { create(:project).reload.project_namespace }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 6,
              date: (to - 3.days).to_date, occurrences: 2 },
            { user_id: user1.id, namespace_path: other_namespace.traversal_path(with_organization: false), event: 6,
              date: (to - 3.days).to_date, occurrences: 1 },
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 6,
              date: (to - 2.days).to_date, occurrences: 1 }
          ])
        end

        context 'when namespace filtering is disabled' do
          before do
            stub_feature_flags(use_duo_chat_namespace_path_filter: false)
          end

          it 'returns chat metrics across all namespaces' do
            expect(service_response).to be_success
            user1_row = raw_results.find { |r| r['user_id'] == user1.id }
            user2_row = raw_results.find { |r| r['user_id'] == user2.id }

            expect(user1_row).to include(
              'total_events_count' => 3,
              'request_duo_chat_response_event_count' => 3,
              'last_duo_activity_on' => (to - 3.days).to_date
            )
            expect(user2_row).to include(
              'total_events_count' => 1,
              'request_duo_chat_response_event_count' => 1,
              'last_duo_activity_on' => (to - 2.days).to_date
            )
          end
        end

        context 'when namespace filtering is enabled' do
          it 'returns chat metrics only within the specified namespace' do
            expect(service_response).to be_success
            user1_row = raw_results.find { |r| r['user_id'] == user1.id }
            user2_row = raw_results.find { |r| r['user_id'] == user2.id }

            expect(user1_row).to include(
              'total_events_count' => 2,
              'request_duo_chat_response_event_count' => 2,
              'last_duo_activity_on' => (to - 3.days).to_date
            )
            expect(user2_row).to include(
              'total_events_count' => 1,
              'request_duo_chat_response_event_count' => 1,
              'last_duo_activity_on' => (to - 2.days).to_date
            )
          end
        end
      end

      context 'with non-chat data' do
        let(:feature) { :code_review }
        let_it_be(:other_namespace) { create(:project).reload.project_namespace }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 10,
              date: (to - 3.days).to_date, occurrences: 2 }, # encounter_duo_code_review_error_during_review
            { user_id: user1.id, namespace_path: other_namespace.traversal_path(with_organization: false), event: 11,
              date: (to - 3.days).to_date, occurrences: 1 }, # find_no_issues_duo_code_review_after_review
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 12,
              date: (to - 2.days).to_date, occurrences: 1 } # find_nothing_to_review_duo_code_review_on_mr
          ])
        end

        it 'returns code review metrics only within the specified namespace' do
          expect(service_response).to be_success
          user1_row = raw_results.find { |r| r['user_id'] == user1.id }
          user2_row = raw_results.find { |r| r['user_id'] == user2.id }

          expect(user1_row).to include(
            'total_events_count' => 2,
            'encounter_duo_code_review_error_during_review_event_count' => 2
          )
          expect(user2_row).to include(
            'total_events_count' => 1,
            'find_nothing_to_review_duo_code_review_on_mr_event_count' => 1
          )
        end
      end

      context 'when ClickHouse returns unknown event IDs' do
        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 3.days).to_date, occurrences: 2 },
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 999,
              date: (to - 3.days).to_date, occurrences: 5 },
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 2,
              date: (to - 2.days).to_date, occurrences: 1 }
          ])
        end

        it 'skips events that cannot be mapped to event names' do
          expect(service_response).to be_success
          user1_row = raw_results.find { |r| r['user_id'] == user1.id }
          user2_row = raw_results.find { |r| r['user_id'] == user2.id }

          expect(user1_row).to include(
            'total_events_count' => 2,
            'code_suggestion_accepted_in_ide_event_count' => 2,
            'code_suggestion_shown_in_ide_event_count' => 0,
            'last_duo_activity_on' => (to - 3.days).to_date
          )
          expect(user2_row).to include(
            'total_events_count' => 1,
            'code_suggestion_accepted_in_ide_event_count' => 0,
            'code_suggestion_shown_in_ide_event_count' => 1,
            'last_duo_activity_on' => (to - 2.days).to_date
          )
        end
      end

      context 'when user has events but none match the feature filter' do
        let_it_be(:user3) { create(:user, developer_of: group) }
        let(:user_ids) { [user1.id, user2.id, user3.id] }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 3.days).to_date, occurrences: 2 },
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 2,
              date: (to - 2.days).to_date, occurrences: 1 },
            { user_id: user3.id, namespace_path: container.traversal_path(with_organization: false), event: 6,
              date: (to - 1.day).to_date, occurrences: 1 }
          ])
        end

        it 'returns nil for last_duo_activity_on when nullIf matches epoch date' do
          expect(service_response).to be_success
          user1_row = raw_results.find { |r| r['user_id'] == user1.id }
          user2_row = raw_results.find { |r| r['user_id'] == user2.id }
          user3_row = raw_results.find { |r| r['user_id'] == user3.id }

          expect(user1_row).to include('last_duo_activity_on' => (to - 3.days).to_date)
          expect(user2_row).to include('last_duo_activity_on' => (to - 2.days).to_date)
          expect(user3_row).to include('total_events_count' => 0, 'last_duo_activity_on' => nil)
        end
      end

      context 'when sort is nil' do
        let(:sort) { nil }
        let(:user_ids) { nil }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 1.day).to_date, occurrences: 5 },
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 1.day).to_date, occurrences: 3 }
          ])
        end

        it 'returns results ordered by user_id ascending' do
          expect(service_response).to be_success
          result_ids = raw_results.pluck('user_id')
          expect(result_ids).to eq(result_ids.sort)
        end
      end

      context 'with sorting' do
        let_it_be(:user3) { create(:user, developer_of: group) }
        let_it_be(:user4) { create(:user, developer_of: group) }
        let(:user_ids) { nil }

        before do
          clickhouse_fixture(:ai_usage_events_daily, [
            # user1: 5 accepted + 2 shown = 7 total
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 3.days).to_date, occurrences: 5 },
            { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 2,
              date: (to - 3.days).to_date, occurrences: 2 },
            # user2: 3 accepted + 1 shown = 4 total
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 2.days).to_date, occurrences: 3 },
            { user_id: user2.id, namespace_path: container.traversal_path(with_organization: false), event: 2,
              date: (to - 2.days).to_date, occurrences: 1 },
            # user3: 10 accepted + 0 shown = 10 total
            { user_id: user3.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
              date: (to - 1.day).to_date, occurrences: 10 },
            # user4: 0 accepted + 8 shown = 8 total
            { user_id: user4.id, namespace_path: container.traversal_path(with_organization: false), event: 2,
              date: (to - 1.day).to_date, occurrences: 8 }
          ])
        end

        context 'when sorting by total_events_count' do
          let(:sort) { { field: :total_events_count, direction: :asc } }

          context 'in descending order' do
            let(:sort) { { field: :total_events_count, direction: :desc } }

            it 'returns users sorted by total event count in descending order' do
              expect(service_response).to be_success

              # Verify order: user3 (10) > user4 (8) > user1 (7) > user2 (4)
              expect(raw_results.pluck('user_id')).to match_array([user3.id, user4.id, user1.id, user2.id])
              expect(raw_results).to include(
                a_hash_including('user_id' => user3.id, 'total_events_count' => 10,
                  'code_suggestion_accepted_in_ide_event_count' => 10,
                  'last_duo_activity_on' => (to - 1.day).to_date),
                a_hash_including('user_id' => user4.id, 'total_events_count' => 8,
                  'code_suggestion_shown_in_ide_event_count' => 8,
                  'last_duo_activity_on' => (to - 1.day).to_date),
                a_hash_including('user_id' => user1.id, 'total_events_count' => 7,
                  'code_suggestion_accepted_in_ide_event_count' => 5,
                  'code_suggestion_shown_in_ide_event_count' => 2,
                  'last_duo_activity_on' => (to - 3.days).to_date),
                a_hash_including('user_id' => user2.id, 'total_events_count' => 4,
                  'code_suggestion_accepted_in_ide_event_count' => 3,
                  'code_suggestion_shown_in_ide_event_count' => 1,
                  'last_duo_activity_on' => (to - 2.days).to_date)
              )
            end
          end

          it 'returns users sorted by total event count in ascending order' do
            expect(service_response).to be_success

            # Verify order: user2 (4) < user1 (7) < user4 (8) < user3 (10)
            expect(raw_results.pluck('user_id')).to match_array([user2.id, user1.id, user4.id, user3.id])
            expect(raw_results).to include(
              a_hash_including('user_id' => user2.id, 'total_events_count' => 4,
                'code_suggestion_accepted_in_ide_event_count' => 3,
                'code_suggestion_shown_in_ide_event_count' => 1,
                'last_duo_activity_on' => (to - 2.days).to_date),
              a_hash_including('user_id' => user1.id, 'total_events_count' => 7,
                'code_suggestion_accepted_in_ide_event_count' => 5,
                'code_suggestion_shown_in_ide_event_count' => 2,
                'last_duo_activity_on' => (to - 3.days).to_date),
              a_hash_including('user_id' => user4.id, 'total_events_count' => 8,
                'code_suggestion_shown_in_ide_event_count' => 8,
                'last_duo_activity_on' => (to - 1.day).to_date),
              a_hash_including('user_id' => user3.id, 'total_events_count' => 10,
                'code_suggestion_accepted_in_ide_event_count' => 10,
                'last_duo_activity_on' => (to - 1.day).to_date)
            )
          end

          it { expect(service_response.payload).to comply_to_cursor_pagination }
        end

        context 'when sorting by specific feature count' do
          let(:sort) { { field: :code_suggestions, direction: :asc } }

          context 'in descending order' do
            let(:sort) { { field: :code_suggestions, direction: :desc } }

            it 'returns users sorted by code suggestions total count in descending order' do
              expect(service_response).to be_success
              expect(raw_results.pluck('user_id')).to match_array([user3.id, user4.id, user1.id, user2.id])
            end
          end

          it 'returns users sorted by code suggestions total count in ascending order' do
            expect(service_response).to be_success
            expect(raw_results.pluck('user_id')).to match_array([user2.id, user1.id, user4.id, user3.id])
          end

          it { expect(service_response.payload).to comply_to_cursor_pagination }
        end

        context 'when sorting with specific event' do
          let(:sort) { { field: :code_suggestion_accepted_in_ide_event_count, direction: :desc } }

          it 'returns users sorted by code suggestion accepted in IDE event count in descending order' do
            expect(service_response).to be_success
            expect(raw_results.pluck('user_id')).to match_array([user3.id, user1.id, user2.id, user4.id])
          end

          it { expect(service_response.payload).to comply_to_cursor_pagination }
        end

        context 'when sorting with user_ids filter' do
          let(:user_ids) { [user1.id, user3.id] }
          let(:sort) { { field: :total_events_count, direction: :desc } }

          it 'returns only filtered users in sorted order' do
            expect(service_response).to be_success

            expect(raw_results.pluck('user_id')).to match_array([user3.id, user1.id])
            expect(raw_results).to include(
              a_hash_including('user_id' => user3.id, 'total_events_count' => 10,
                'code_suggestion_accepted_in_ide_event_count' => 10,
                'last_duo_activity_on' => (to - 1.day).to_date),
              a_hash_including('user_id' => user1.id, 'total_events_count' => 7,
                'code_suggestion_accepted_in_ide_event_count' => 5,
                'code_suggestion_shown_in_ide_event_count' => 2,
                'last_duo_activity_on' => (to - 3.days).to_date)
            )
          end

          it { expect(service_response.payload).to comply_to_cursor_pagination }
        end

        context 'when sorting with namespace filtering enabled' do
          let_it_be(:other_namespace) { create(:project).reload.project_namespace }
          let(:sort) { { field: :total_events_count, direction: :desc } }

          before do
            clickhouse_fixture(:ai_usage_events_daily, [
              { user_id: user1.id, namespace_path: other_namespace.traversal_path(with_organization: false), event: 3,
                date: (to - 3.days).to_date, occurrences: 100 }
            ])
          end

          it 'sorts based only on events within the specified namespace' do
            expect(service_response).to be_success
            expect(raw_results.pluck('user_id')).to match_array([user3.id, user4.id, user1.id, user2.id])
          end

          it { expect(service_response.payload).to comply_to_cursor_pagination }
        end

        context 'when sorting by a different feature than the current feature' do
          let(:feature) { :code_suggestions }
          let(:sort) { { field: :chat, direction: :desc } }
          let_it_be(:user5) { create(:user, developer_of: group) }

          before do
            # Add chat events (event 6) for sorting
            clickhouse_fixture(:ai_usage_events_daily, [
              # user5: 10 chat events
              { user_id: user5.id, namespace_path: container.traversal_path(with_organization: false), event: 6,
                date: (to - 3.days).to_date, occurrences: 10 },
              # user1: 5 chat events
              { user_id: user1.id, namespace_path: container.traversal_path(with_organization: false), event: 6,
                date: (to - 2.days).to_date, occurrences: 5 }
            ])
          end

          it 'sorts by the specified feature and returns metrics for the current feature' do
            expect(service_response).to be_success

            # Should be sorted by chat events (user5: 10, user1: 5, then others with 0)
            # But returns code_suggestions metrics
            expect(raw_results.first(2).pluck('user_id')).to match_array([user5.id, user1.id])
            user1_row = raw_results.find { |r| r['user_id'] == user1.id }
            expect(user1_row).to include(
              'total_events_count' => 7,
              'code_suggestion_accepted_in_ide_event_count' => 5,
              'code_suggestion_shown_in_ide_event_count' => 2,
              'last_duo_activity_on' => (to - 3.days).to_date
            )
          end

          it { expect(service_response.payload).to comply_to_cursor_pagination }
        end

        context 'when users have equal sort values' do
          let_it_be(:user5) { create(:user, developer_of: group) }
          let_it_be(:user6) { create(:user, developer_of: group) }
          let(:sort) { { field: :total_events_count, direction: :desc } }
          let(:user_ids) { [user5.id, user6.id] }

          before do
            clickhouse_fixture(:ai_usage_events_daily, [
              { user_id: user5.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
                date: (to - 1.day).to_date, occurrences: 5 },
              { user_id: user6.id, namespace_path: container.traversal_path(with_organization: false), event: 3,
                date: (to - 1.day).to_date, occurrences: 5 }
            ])
          end

          it 'breaks ties by user_id in ascending order' do
            expect(service_response).to be_success
            result_ids = raw_results.pluck('user_id')
            expect(result_ids).to eq([user5.id, user6.id].sort)
          end
        end
      end
    end
  end

  context 'for group namespace' do
    let(:container) { group }

    it_behaves_like 'ai user metrics service'
  end

  context 'for project namespace' do
    let(:container) { project.project_namespace.reload }

    it_behaves_like 'ai user metrics service'
  end
end
