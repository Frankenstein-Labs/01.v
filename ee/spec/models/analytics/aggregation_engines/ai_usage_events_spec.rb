# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AggregationEngines::AiUsageEvents, :click_house, time_travel_to: '2026-01-30',
  type: :aggregation_engine,
  feature_category: :product_analytics do
  let(:engine) { described_class.new(context: engine_context) }
  let(:engine_context) { { scope: ClickHouse::Client::QueryBuilder.new(described_class.table_name) } }

  let_it_be(:project1) { create(:project) }

  before do
    clickhouse_fixture(:ai_usage_events, events_data)
  end

  def event_data(user_id:, event:, timestamp:, project: project1)
    {
      user_id: user_id,
      event: Ai::UsageEvent.events[event],
      timestamp: timestamp,
      namespace_path: project.project_namespace.traversal_path(with_organization: false)
    }
  end

  describe '.prepare_base_aggregation_scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project_in_group) { create(:project, group: group) }
    let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }

    let(:events_data) do
      [
        event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago, project: project_in_group),
        event_data(user_id: 2, event: :request_duo_chat_response, timestamp: 10.days.ago, project: project_in_subgroup),
        event_data(user_id: 3, event: :troubleshoot_job, timestamp: 10.days.ago, project: other_project)
      ]
    end

    subject(:result) do
      ClickHouse::Client.select(described_class.prepare_base_aggregation_scope(send(scope_key)), :main)
    end

    where(:scope_key, :expected_user_ids) do
      [
        [:project_in_group, [1]],
        [:group, [1, 2]],
        [:subgroup, [2]]
      ]
    end

    with_them do
      it 'returns records scoped to provided context object' do
        expect(result.map { |r| r['user_id'] }).to match_array(expected_user_ids)
      end
    end

    context 'with multiple scope objects' do
      it 'combines the scopes with OR' do
        scope = described_class.prepare_base_aggregation_scope([subgroup, other_project])
        result = ClickHouse::Client.select(scope, :main)

        expect(result.map { |r| r['user_id'] }).to match_array([2, 3])
      end
    end

    context 'with no scope objects' do
      it 'raises an ArgumentError' do
        expect { described_class.prepare_base_aggregation_scope([]) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'dimensions' do
    describe 'event' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide,
            timestamp: 10.days.ago + 1.second),
          event_data(user_id: 2, event: :request_duo_chat_response, timestamp: 10.days.ago)
        ]
      end

      it 'groups events by event type and formats as string' do
        request = {
          dimensions: [{ identifier: :event }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { event: 'code_suggestion_shown_in_ide', total_count: 2 },
          { event: 'request_duo_chat_response', total_count: 1 }
        ]))
      end
    end

    describe 'feature' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 1, event: :code_suggestion_accepted_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 2, event: :request_duo_chat_response, timestamp: 10.days.ago),
          event_data(user_id: 3, event: :troubleshoot_job, timestamp: 10.days.ago)
        ]
      end

      it 'groups events by feature' do
        request = {
          dimensions: [{ identifier: :feature }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { feature: 'code_suggestions', total_count: 2 },
          { feature: 'chat', total_count: 1 },
          { feature: 'troubleshoot_job', total_count: 1 }
        ]))
      end

      context 'when the table contains an event with an unregistered event ID' do
        let(:unknown_event_id) { 99999 }
        let(:events_data) do
          [
            event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
            {
              user_id: 2,
              event: unknown_event_id,
              timestamp: 10.days.ago,
              namespace_path: project1.project_namespace.traversal_path(with_organization: false)
            }
          ]
        end

        it 'returns nil feature for unrecognized event IDs' do
          request = {
            dimensions: [{ identifier: :feature }],
            metrics: [{ identifier: :total_count }]
          }

          expect(engine).to execute_aggregation(request).and_return(match_array([
            { feature: 'code_suggestions', total_count: 1 },
            { feature: nil, total_count: 1 }
          ]))
        end
      end
    end

    describe 'user_id' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 1, event: :request_duo_chat_response, timestamp: 10.days.ago),
          event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago)
        ]
      end

      it 'groups events by user_id' do
        request = {
          dimensions: [{ identifier: :user_id }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { user_id: 1, total_count: 2 },
          { user_id: 2, total_count: 1 }
        ]))
      end

      it 'groups events by user with user request' do
        request = {
          dimensions: [{ identifier: :user }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { user_id: 1, total_count: 2 },
          { user_id: 2, total_count: 1 }
        ]))
      end
    end

    describe 'timestamp' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide,
            timestamp: 10.days.ago + 1.second),
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 100.days.ago)
        ]
      end

      it 'groups events by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :timestamp }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp: 10.days.ago.beginning_of_month.to_date, total_count: 2 },
          { timestamp: 100.days.ago.beginning_of_month.to_date, total_count: 1 }
        ]))
      end

      it 'groups events by monthly buckets' do
        request = {
          dimensions: [{ identifier: :timestamp, parameters: { granularity: 'monthly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp_monthly: 10.days.ago.beginning_of_month.to_date, total_count: 2 },
          { timestamp_monthly: 100.days.ago.beginning_of_month.to_date, total_count: 1 }
        ]))
      end

      it 'groups events by weekly buckets' do
        request = {
          dimensions: [{ identifier: :timestamp, parameters: { granularity: 'weekly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp_weekly: 10.days.ago.beginning_of_week.to_date, total_count: 2 },
          { timestamp_weekly: 100.days.ago.beginning_of_week.to_date, total_count: 1 }
        ]))
      end

      it 'groups events by daily buckets' do
        request = {
          dimensions: [{ identifier: :timestamp, parameters: { granularity: 'daily' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp_daily: 10.days.ago.to_date, total_count: 2 },
          { timestamp_daily: 100.days.ago.to_date, total_count: 1 }
        ]))
      end
    end
  end

  describe 'metrics' do
    describe 'total_count' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 1, event: :request_duo_chat_response, timestamp: 10.days.ago),
          event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago)
        ]
      end

      it 'counts total number of events' do
        request = {
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end

      it 'counts events grouped by event type' do
        request = {
          dimensions: [{ identifier: :event }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { event: 'code_suggestion_shown_in_ide', total_count: 2 },
          { event: 'request_duo_chat_response', total_count: 1 }
        ]))
      end
    end

    describe 'users_count' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 1, event: :request_duo_chat_response, timestamp: 10.days.ago),
          event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 2, event: :request_duo_chat_response, timestamp: 10.days.ago)
        ]
      end

      it 'counts distinct number of users' do
        request = {
          metrics: [{ identifier: :users_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { users_count: 2 }
        ])
      end

      it 'counts distinct users grouped by event type' do
        request = {
          dimensions: [{ identifier: :event }],
          metrics: [{ identifier: :users_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { event: 'code_suggestion_shown_in_ide', users_count: 2 },
          { event: 'request_duo_chat_response', users_count: 2 }
        ]))
      end
    end

    describe 'features_count' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 1, event: :code_suggestion_accepted_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 1, event: :request_duo_chat_response, timestamp: 10.days.ago),
          event_data(user_id: 2, event: :troubleshoot_job, timestamp: 10.days.ago),
          event_data(user_id: 2, event: nil, timestamp: 10.days.ago)
        ]
      end

      it 'counts distinct features' do
        request = {
          dimensions: [{ identifier: :user_id }],
          metrics: [{ identifier: :features_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { user_id: 1, features_count: 2 },
          { user_id: 2, features_count: 1 }
        ]))
      end
    end

    describe 'returning_users_count' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
          event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 3, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago)
        ]
      end

      it 'counts users present in both the current and previous weekly period' do
        request = {
          dimensions: [{ identifier: :timestamp, parameters: { granularity: 'weekly' } }],
          metrics: [{ identifier: :returning_users_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp_weekly: 20.days.ago.beginning_of_week.to_date, returning_users_count: 0 },
          { timestamp_weekly: 10.days.ago.beginning_of_week.to_date, returning_users_count: 1 }
        ]))
      end

      context 'with monthly granularity spanning two months' do
        let(:events_data) do
          [
            event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 50.days.ago),
            event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 50.days.ago),
            event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
            event_data(user_id: 3, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago)
          ]
        end

        it 'counts users present in both the current and previous monthly period' do
          request = {
            dimensions: [{ identifier: :timestamp, parameters: { granularity: 'monthly' } }],
            metrics: [{ identifier: :returning_users_count }]
          }

          expect(engine).to execute_aggregation(request).and_return(match_array([
            { timestamp_monthly: 50.days.ago.beginning_of_month.to_date, returning_users_count: 0 },
            { timestamp_monthly: 10.days.ago.beginning_of_month.to_date, returning_users_count: 1 }
          ]))
        end
      end

      context 'with feature dimension (verifies PARTITION BY prevents cross-feature lag)' do
        # Without PARTITION BY, lag would spill across feature rows ordered by timestamp,
        # returning wrong intersection values (e.g. chat users intersected with code_suggestions users)
        # With PARTITION BY feature, each feature has its own independent lag window
        #
        # Data layout (week Jan 5 / Jan 19):
        #   code_suggestions week Jan 5:  users [1, 2]
        #   chat             week Jan 5:  user  [3]
        #   code_suggestions week Jan 19: users [1, 4]
        #   chat             week Jan 19: users [3, 5]
        let(:events_data) do
          [
            event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
            event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
            event_data(user_id: 3, event: :request_duo_chat_response,    timestamp: 20.days.ago),
            event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
            event_data(user_id: 4, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
            event_data(user_id: 3, event: :request_duo_chat_response,    timestamp: 10.days.ago),
            event_data(user_id: 5, event: :request_duo_chat_response,    timestamp: 10.days.ago)
          ]
        end

        it 'partitions the lag window by feature so each feature is computed independently' do
          request = {
            dimensions: [
              { identifier: :feature },
              { identifier: :timestamp, parameters: { granularity: 'weekly' } }
            ],
            metrics: [{ identifier: :returning_users_count }]
          }

          expect(engine).to execute_aggregation(request).and_return(match_array([
            { feature: 'code_suggestions', timestamp_weekly: 20.days.ago.beginning_of_week.to_date,
              returning_users_count: 0 },
            { feature: 'code_suggestions', timestamp_weekly: 10.days.ago.beginning_of_week.to_date,
              returning_users_count: 1 },
            { feature: 'chat', timestamp_weekly: 20.days.ago.beginning_of_week.to_date,
              returning_users_count: 0 },
            { feature: 'chat', timestamp_weekly: 10.days.ago.beginning_of_week.to_date,
              returning_users_count: 1 }
          ]))
        end
      end
    end

    describe 'previous_period_users_count' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
          event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 3, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago)
        ]
      end

      it 'returns the distinct user count from the previous weekly period' do
        request = {
          dimensions: [{ identifier: :timestamp, parameters: { granularity: 'weekly' } }],
          metrics: [{ identifier: :previous_period_users_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp_weekly: 20.days.ago.beginning_of_week.to_date, previous_period_users_count: 0 },
          { timestamp_weekly: 10.days.ago.beginning_of_week.to_date, previous_period_users_count: 2 }
        ]))
      end

      context 'with feature dimension (verifies PARTITION BY prevents cross-feature lag)' do
        # Without PARTITION BY, lag would inherit values from the previous chronological row
        # regardless of feature, mixing chat and code_suggestions counts
        let(:events_data) do
          [
            event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
            event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
            event_data(user_id: 3, event: :request_duo_chat_response,    timestamp: 20.days.ago),
            event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
            event_data(user_id: 4, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
            event_data(user_id: 3, event: :request_duo_chat_response,    timestamp: 10.days.ago),
            event_data(user_id: 5, event: :request_duo_chat_response,    timestamp: 10.days.ago)
          ]
        end

        it 'partitions the lag window by feature so each feature is computed independently' do
          request = {
            dimensions: [
              { identifier: :feature },
              { identifier: :timestamp, parameters: { granularity: 'weekly' } }
            ],
            metrics: [{ identifier: :previous_period_users_count }]
          }

          expect(engine).to execute_aggregation(request).and_return(match_array([
            { feature: 'code_suggestions', timestamp_weekly: 20.days.ago.beginning_of_week.to_date,
              previous_period_users_count: 0 },
            { feature: 'code_suggestions', timestamp_weekly: 10.days.ago.beginning_of_week.to_date,
              previous_period_users_count: 2 },
            { feature: 'chat', timestamp_weekly: 20.days.ago.beginning_of_week.to_date,
              previous_period_users_count: 0 },
            { feature: 'chat', timestamp_weekly: 10.days.ago.beginning_of_week.to_date,
              previous_period_users_count: 1 }
          ]))
        end
      end
    end

    describe 'returning + previous_period together' do
      let(:events_data) do
        [
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
          event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 20.days.ago),
          event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
          event_data(user_id: 3, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago)
        ]
      end

      it 'computes both window metrics in a single request' do
        request = {
          dimensions: [{ identifier: :timestamp, parameters: { granularity: 'weekly' } }],
          metrics: [
            { identifier: :returning_users_count },
            { identifier: :previous_period_users_count }
          ]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp_weekly: 20.days.ago.beginning_of_week.to_date,
            returning_users_count: 0, previous_period_users_count: 0 },
          { timestamp_weekly: 10.days.ago.beginning_of_week.to_date,
            returning_users_count: 1, previous_period_users_count: 2 }
        ]))
      end
    end
  end

  describe 'filters' do
    let(:events_data) do
      [
        event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 100.days.ago),
        event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 50.days.ago),
        event_data(user_id: 1, event: :request_duo_chat_response, timestamp: 10.days.ago),
        event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 10.days.ago),
        event_data(user_id: 3, event: :request_duo_chat_response, timestamp: 5.days.ago),
        event_data(user_id: 3, event: :troubleshoot_job, timestamp: 10.days.ago)
      ]
    end

    describe 'user_id' do
      it 'filters events by single user GlobalID' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :user_id, values: "gid://gitlab/User/1" }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end

      it 'filters events by user GlobalIDs' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :user_id, values: %w[gid://gitlab/User/1 gid://gitlab/User/2] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 4 }
        ])
      end
    end

    describe 'event' do
      it 'filters events by single event type' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :event, values: 'code_suggestion_shown_in_ide' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end

      it 'filters events by multiple event types' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{
            identifier: :event,
            values: %w[code_suggestion_shown_in_ide request_duo_chat_response]
          }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 5 }
        ])
      end
    end

    describe 'feature' do
      it 'filters events by single feature' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :feature, values: 'code_suggestions' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end

      it 'filters events by multiple features' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :feature, values: %w[code_suggestions chat] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 5 }
        ])
      end
    end

    describe 'timestamp' do
      it 'filters events by start date' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :timestamp, values: (30.days.ago..) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 4 }
        ])
      end

      it 'filters events by end date' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :timestamp, values: (..20.days.ago) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'filters events by date range' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :timestamp, values: (60.days.ago..30.days.ago) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 1 }
        ])
      end
    end
  end

  describe 'comprehensive test with all metrics, dimensions, and filters combined' do
    let(:events_data) do
      [
        event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 100.days.ago),
        event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 50.days.ago),
        event_data(user_id: 1, event: :code_suggestion_shown_in_ide, timestamp: 15.days.ago),
        event_data(user_id: 1, event: :request_duo_chat_response, timestamp: 10.days.ago),
        event_data(user_id: 2, event: :code_suggestion_shown_in_ide, timestamp: 12.days.ago),
        event_data(user_id: 2, event: :request_duo_chat_response, timestamp: 8.days.ago),
        event_data(user_id: 3, event: :troubleshoot_job, timestamp: 8.days.ago),
        event_data(user_id: 1, event: :troubleshoot_job, timestamp: 8.days.ago)
      ]
    end

    it 'combined test' do
      request = {
        dimensions: [
          { identifier: :event },
          { identifier: :user_id },
          { identifier: :timestamp, parameters: { granularity: 'monthly' } }
        ],
        metrics: [
          { identifier: :total_count },
          { identifier: :users_count }
        ],
        filters: [
          { identifier: :user_id, values: %w[gid://gitlab/User/1 gid://gitlab/User/2] },
          {
            identifier: :event,
            values: %w[code_suggestion_shown_in_ide request_duo_chat_response]
          },
          { identifier: :timestamp, values: (60.days.ago..5.days.ago) }
        ],
        order: [{ identifier: :user_id, direction: :desc }, { identifier: :event, direction: :asc }]
      }

      expect(engine).to execute_aggregation(request).and_return([
        {
          event: 'code_suggestion_shown_in_ide',
          user_id: 2,
          timestamp_monthly: 12.days.ago.beginning_of_month.to_date,
          total_count: 1,
          users_count: 1
        },
        {
          event: 'request_duo_chat_response',
          user_id: 2,
          timestamp_monthly: 8.days.ago.beginning_of_month.to_date,
          total_count: 1,
          users_count: 1
        },
        {
          event: 'code_suggestion_shown_in_ide',
          user_id: 1,
          timestamp_monthly: 50.days.ago.beginning_of_month.to_date,
          total_count: 1,
          users_count: 1
        },
        {
          event: 'code_suggestion_shown_in_ide',
          user_id: 1,
          timestamp_monthly: 15.days.ago.beginning_of_month.to_date,
          total_count: 1,
          users_count: 1
        },
        {
          event: 'request_duo_chat_response',
          user_id: 1,
          timestamp_monthly: 10.days.ago.beginning_of_month.to_date,
          total_count: 1,
          users_count: 1
        }
      ])
    end
  end
end
