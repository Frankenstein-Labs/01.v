# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AggregationEngines::AgentPlatformSessions, :click_house, time_travel_to: '2026-01-30',
  type: :aggregation_engine,
  feature_category: :product_analytics do
  let(:engine) { described_class.new(context: engine_context) }
  let(:engine_context) { { scope: ClickHouse::Client::QueryBuilder.new(described_class.table_name) } }

  let_it_be(:project1) { create(:project) }
  let_it_be(:session_events_map) do
    {
      created_at: Ai::UsageEvent.events[:agent_platform_session_created],
      finished_at: Ai::UsageEvent.events[:agent_platform_session_finished],
      dropped_at: Ai::UsageEvent.events[:agent_platform_session_dropped],
      stopped_at: Ai::UsageEvent.events[:agent_platform_session_stopped],
      resumed_at: Ai::UsageEvent.events[:agent_platform_session_resumed]
    }
  end

  before do
    events_data = sessions_data.flat_map do |session|
      session_events_map.map do |timestamp_name, event_value|
        next unless session[timestamp_name]

        event_data(session.merge(
          event: event_value,
          timestamp: session[timestamp_name]))
      end
    end.compact

    clickhouse_fixture(:ai_usage_events, events_data)
  end

  def event_data(data)
    data.slice(*%i[user_id event timestamp]).merge(
      namespace_path: data[:project].project_namespace.traversal_path(with_organization: false),
      extras: data.slice(*%i[environment flow_type session_id]).merge(project_id: data[:project].id)
    )
  end

  describe '.prepare_base_aggregation_scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project_in_group) { create(:project, group: group) }
    let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }

    subject(:result) do
      query = described_class.prepare_base_aggregation_scope(object)
      ClickHouse::Client.select(query, :main)
    end

    context 'when object is a Project' do
      let(:object) { project_in_group }

      let(:sessions_data) do
        [
          { session_id: 1, user_id: 1, flow_type: 'duo_chat', project: project_in_group,
            created_at: 10.days.ago, environment: 'prod' },
          { session_id: 2, user_id: 2, flow_type: 'duo_chat', project: other_project,
            created_at: 10.days.ago, environment: 'prod' }
        ]
      end

      it 'returns only records belonging to that project namespace' do
        expect(result.map { |r| r['session_id'] }).to match_array([1])
      end
    end

    context 'when object is a Group' do
      let(:object) { group }

      let(:sessions_data) do
        [
          { session_id: 1, user_id: 1, flow_type: 'duo_chat', project: project_in_group,
            created_at: 10.days.ago, environment: 'prod' },
          { session_id: 2, user_id: 2, flow_type: 'duo_chat', project: project_in_subgroup,
            created_at: 10.days.ago, environment: 'prod' },
          { session_id: 3, user_id: 3, flow_type: 'duo_chat', project: other_project,
            created_at: 10.days.ago, environment: 'prod' }
        ]
      end

      it 'returns records for all projects within the group hierarchy' do
        expect(result).to have_attributes(size: 2)
        expect(result.map { |r| r['session_id'] }).to match_array([1, 2])
      end
    end

    context 'when object is a subgroup' do
      let(:object) { subgroup }

      let(:sessions_data) do
        [
          { session_id: 1, user_id: 1, flow_type: 'duo_chat', project: project_in_group,
            created_at: 10.days.ago, environment: 'prod' },
          { session_id: 2, user_id: 2, flow_type: 'duo_chat', project: project_in_subgroup,
            created_at: 10.days.ago, environment: 'prod' }
        ]
      end

      it 'returns only records for projects within the subgroup' do
        expect(result).to have_attributes(size: 1)
        expect(result.map { |r| r['session_id'] }).to match_array([2])
      end
    end

    context 'with no scope objects' do
      let(:sessions_data) { [] }

      it 'raises an ArgumentError' do
        expect { described_class.prepare_base_aggregation_scope([]) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'dimensions' do
    describe 'flow_type' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 1,
            flow_type: 'code_review',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          }
        ]
      end

      it 'groups sessions by flow_type' do
        request = {
          dimensions: [{ identifier: :flow_type }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { flow_type: 'duo_chat', total_count: 2 },
          { flow_type: 'code_review', total_count: 1 }
        ]))
      end
    end

    describe 'user_id' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 2,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          }
        ]
      end

      it 'groups sessions by user_id' do
        request = {
          dimensions: [{ identifier: :user_id }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { user_id: 1, total_count: 2 },
          { user_id: 2, total_count: 1 }
        ]))
      end

      it 'groups sessions by user_id with user request' do
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

    describe 'created_event_at' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 100.days.ago,
            environment: 'prod'
          }
        ]
      end

      it 'groups sessions by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :created_event_at }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_event_at: 10.days.ago.beginning_of_month.to_date, total_count: 2 },
          { created_event_at: 100.days.ago.beginning_of_month.to_date, total_count: 1 }
        ]))
      end

      it 'groups sessions by monthly buckets' do
        request = {
          dimensions: [{ identifier: :created_event_at, parameters: { granularity: 'monthly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_event_at_monthly: 10.days.ago.beginning_of_month.to_date, total_count: 2 },
          { created_event_at_monthly: 100.days.ago.beginning_of_month.to_date, total_count: 1 }
        ]))
      end

      it 'groups sessions by weekly buckets' do
        request = {
          dimensions: [{ identifier: :created_event_at, parameters: { granularity: 'weekly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_event_at_weekly: 10.days.ago.beginning_of_week.to_date, total_count: 2 },
          { created_event_at_weekly: 100.days.ago.beginning_of_week.to_date, total_count: 1 }
        ]))
      end
    end
  end

  describe 'metrics' do
    describe 'total_count' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 2,
            flow_type: 'code_review',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          }
        ]
      end

      it 'counts total number of sessions' do
        request = {
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end

      it 'counts sessions grouped by flow_type' do
        request = {
          dimensions: [{ identifier: :flow_type }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { flow_type: 'duo_chat', total_count: 2 },
          { flow_type: 'code_review', total_count: 1 }
        ]))
      end
    end

    describe 'finished_count' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 5.minutes,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 10.minutes,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 2,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          }
        ]
      end

      it 'counts only finished sessions' do
        request = {
          metrics: [{ identifier: :finished_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { finished_count: 2 }
        ])
      end

      it 'counts finished sessions grouped by user_id' do
        request = {
          dimensions: [{ identifier: :user_id }],
          metrics: [{ identifier: :finished_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { user_id: 1, finished_count: 2 },
          { user_id: 2, finished_count: 0 }
        ]))
      end
    end

    describe 'users_count' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 2,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 4,
            user_id: 2,
            flow_type: 'code_review',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          }
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

      it 'counts distinct users grouped by flow_type' do
        request = {
          dimensions: [{ identifier: :flow_type }],
          metrics: [{ identifier: :users_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { flow_type: 'duo_chat', users_count: 2 },
          { flow_type: 'code_review', users_count: 1 }
        ]))
      end
    end

    describe 'duration (mean)' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 60.seconds,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 120.seconds,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 2,
            flow_type: 'code_review',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 180.seconds,
            environment: 'prod'
          }
        ]
      end

      it 'calculates average session duration in seconds' do
        request = {
          metrics: [{ identifier: :mean_duration }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { mean_duration: 120.0 }
        ])
      end

      it 'calculates average duration grouped by flow_type' do
        request = {
          dimensions: [{ identifier: :flow_type }],
          metrics: [{ identifier: :mean_duration }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { flow_type: 'duo_chat', mean_duration: 90.0 },
          { flow_type: 'code_review', mean_duration: 180.0 }
        ]))
      end
    end

    describe 'completion_rate' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 5.minutes,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 10.minutes,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 2,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            environment: 'prod'
          },
          {
            session_id: 4,
            user_id: 2,
            flow_type: 'code_review',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 15.minutes,
            environment: 'prod'
          }
        ]
      end

      it 'calculates session completion rate' do
        request = {
          metrics: [{ identifier: :completion_rate }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { completion_rate: 0.75 }
        ])
      end

      it 'calculates completion rate grouped by flow_type' do
        request = {
          dimensions: [{ identifier: :flow_type }],
          metrics: [{ identifier: :completion_rate }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { flow_type: 'duo_chat', completion_rate: 2.0 / 3.0 },
          { flow_type: 'code_review', completion_rate: 1.0 }
        ]))
      end
    end

    describe 'duration (quantile)' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 30.seconds,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 60.seconds,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 90.seconds,
            environment: 'prod'
          },
          {
            session_id: 4,
            user_id: 2,
            flow_type: 'code_review',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 120.seconds,
            environment: 'prod'
          }
        ]
      end

      it 'calculates 50th percentile (median) duration by default' do
        request = {
          metrics: [{ identifier: :duration_quantile }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { duration_quantile: 75.0 }
        ])
      end

      it 'calculates 95th percentile duration' do
        request = {
          metrics: [{ identifier: :duration_quantile, parameters: { quantile: 0.95 } }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { duration_quantile_22fa3: within(0.1).of(115.5) }
        ])
      end

      it 'calculates quantile duration grouped by flow_type' do
        request = {
          dimensions: [{ identifier: :flow_type }],
          metrics: [{ identifier: :duration_quantile, parameters: { quantile: 0.5 } }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { flow_type: 'duo_chat', duration_quantile_d2cba: 60.0 },
          { flow_type: 'code_review', duration_quantile_d2cba: 120.0 }
        ]))
      end
    end

    describe 'duration measurement' do
      let(:sessions_data) do
        [
          {
            session_id: 1,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 30.seconds,
            environment: 'prod'
          },
          {
            session_id: 2,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 60.seconds,
            environment: 'prod'
          },
          {
            session_id: 3,
            user_id: 1,
            flow_type: 'duo_chat',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 90.seconds,
            environment: 'prod'
          },
          {
            session_id: 4,
            user_id: 2,
            flow_type: 'code_review',
            project: project1,
            created_at: 10.days.ago,
            finished_at: 10.days.ago + 120.seconds,
            environment: 'prod'
          }
        ]
      end

      it 'calculates all measurement aggregates in one request' do
        request = {
          metrics: [
            { identifier: :"duration.min" },
            { identifier: :"duration.max" },
            { identifier: :"duration.mean" },
            { identifier: :"duration.quantile", parameters: { quantile: 0.5 } }
          ]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { duration__min: 30, duration__max: 120, duration__mean: 75.0, duration__quantile_d2cba: 75.0 }
        ])
      end

      it 'calculates measurement aggregates grouped by flow_type' do
        request = {
          dimensions: [{ identifier: :flow_type }],
          metrics: [{ identifier: :"duration.min" }, { identifier: :"duration.max" }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { flow_type: 'duo_chat', duration__min: 30, duration__max: 90 },
          { flow_type: 'code_review', duration__min: 120, duration__max: 120 }
        ]))
      end
    end
  end

  describe 'filters' do
    let(:sessions_data) do
      [
        {
          session_id: 1,
          user_id: 1,
          flow_type: 'duo_chat',
          project: project1,
          created_at: 100.days.ago,
          environment: 'prod'
        },
        {
          session_id: 2,
          user_id: 1,
          flow_type: 'duo_chat',
          project: project1,
          created_at: 50.days.ago,
          environment: 'prod'
        },
        {
          session_id: 3,
          user_id: 1,
          flow_type: 'duo_chat',
          project: project1,
          created_at: 10.days.ago,
          environment: 'prod'
        },
        {
          session_id: 4,
          user_id: 2,
          flow_type: 'code_review',
          project: project1,
          created_at: 10.days.ago,
          environment: 'prod'
        },
        {
          session_id: 5,
          user_id: 3,
          flow_type: 'code_review',
          project: project1,
          created_at: 5.days.ago,
          environment: 'prod'
        },
        {
          session_id: 6,
          user_id: 3,
          flow_type: 'code_generation',
          project: project1,
          created_at: 10.days.ago,
          environment: 'prod'
        }
      ]
    end

    describe 'user_id' do
      it 'filters sessions by single user GlobalID' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :user_id, values: "gid://gitlab/User/1" }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end

      it 'filters sessions by multiple user GlobalIDs' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :user_id, values: %w[gid://gitlab/User/1 gid://gitlab/User/2] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 4 }
        ])
      end
    end

    describe 'flow_type' do
      it 'filters sessions by single flow_type' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :flow_type, values: 'duo_chat' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end

      it 'filters sessions by multiple flow_types' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :flow_type, values: %w[duo_chat code_review] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 5 }
        ])
      end
    end

    describe 'created_event_at' do
      it 'filters sessions by created_event_at start date' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :created_event_at, values: (30.days.ago..) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 4 }
        ])
      end

      it 'filters sessions by created_event_at end date' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :created_event_at, values: (..20.days.ago) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'filters sessions by created_event_at date range' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :created_event_at, values: (60.days.ago..30.days.ago) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 1 }
        ])
      end
    end
  end

  describe '#count' do
    let(:sessions_data) do
      [
        { session_id: 1, user_id: 1, flow_type: 'duo_chat', project: project1, created_at: 10.days.ago,
          environment: 'prod' },
        { session_id: 2, user_id: 1, flow_type: 'duo_chat', project: project1, created_at: 10.days.ago,
          environment: 'prod' },
        { session_id: 3, user_id: 2, flow_type: 'code_review', project: project1, created_at: 10.days.ago,
          environment: 'prod' }
      ]
    end

    it 'returns the number of aggregated rows via a database query' do
      request = Gitlab::Database::Aggregation::Request.new(
        dimensions: [{ identifier: :flow_type }],
        metrics: [{ identifier: :total_count }]
      )
      result = engine.execute(request).payload[:data]

      expect(result.count).to eq(2)
    end
  end

  describe 'comprehensive test with all metrics, dimensions, and filters combined' do
    let(:sessions_data) do
      [
        # User 1, duo_chat sessions
        {
          session_id: 1,
          user_id: 1,
          flow_type: 'duo_chat',
          project: project1,
          created_at: 100.days.ago,
          finished_at: 100.days.ago + 45.seconds,
          environment: 'prod'
        },
        {
          session_id: 2,
          user_id: 1,
          flow_type: 'duo_chat',
          project: project1,
          created_at: 50.days.ago,
          finished_at: 50.days.ago + 90.seconds,
          environment: 'prod'
        },
        {
          session_id: 3,
          user_id: 1,
          flow_type: 'duo_chat',
          project: project1,
          created_at: 15.days.ago,
          finished_at: 15.days.ago + 120.seconds,
          environment: 'prod'
        },
        # User 2, code_review sessions
        {
          session_id: 4,
          user_id: 2,
          flow_type: 'code_review',
          project: project1,
          created_at: 12.days.ago,
          finished_at: 12.days.ago + 60.seconds,
          environment: 'prod'
        },
        {
          session_id: 5,
          user_id: 2,
          flow_type: 'code_review',
          project: project1,
          created_at: 8.days.ago,
          environment: 'prod' # Not finished
        },
        # User 3, (outside filter range)
        {
          session_id: 6,
          user_id: 3,
          flow_type: 'code_generation',
          project: project1,
          created_at: 8.days.ago,
          finished_at: 8.days.ago + 30.seconds,
          environment: 'prod'
        },
        # User 1, code_review session
        {
          session_id: 7,
          user_id: 1,
          flow_type: 'code_review',
          project: project1,
          created_at: 10.days.ago,
          finished_at: 10.days.ago + 150.seconds,
          environment: 'prod'
        },
        # code generation (outside filter range)
        {
          session_id: 8,
          user_id: 1,
          flow_type: 'code_generation',
          project: project1,
          created_at: 8.days.ago,
          finished_at: 8.days.ago + 30.seconds,
          environment: 'prod'
        }
      ]
    end

    it 'combined test' do
      request = {
        dimensions: [
          { identifier: :flow_type },
          { identifier: :user_id },
          { identifier: :created_event_at, parameters: { granularity: 'monthly' } }
        ],
        metrics: [
          { identifier: :total_count },
          { identifier: :finished_count },
          { identifier: :users_count },
          { identifier: :mean_duration },
          { identifier: :completion_rate },
          { identifier: :duration_quantile, parameters: { quantile: 0.5 } },
          { identifier: :duration_quantile, parameters: { quantile: 0.95 } }
        ],
        filters: [
          { identifier: :user_id, values: %w[gid://gitlab/User/1 gid://gitlab/User/2] },
          { identifier: :flow_type, values: %w[duo_chat code_review] },
          { identifier: :created_event_at, values: (60.days.ago..5.days.ago) }
        ],
        order: [{ identifier: :user_id, direction: :desc }, { identifier: :mean_duration, direction: :desc }]
      }

      # Expected results:
      # - User 2, code_review: sessions 4 and 5 (12 and 8 days ago)
      # - User 1, duo_chat: sessions 2 and 3 (50 and 15 days ago)
      # - User 1, code_review: session 7 (10 days ago)
      # Sessions 1,6,8 are outside of date, user_id and flow_type ranges

      expect(engine).to execute_aggregation(request).and_return([
        # User 2, code_review, 12 and 8 days ago month (same month)
        {
          flow_type: 'code_review',
          user_id: 2,
          created_event_at_monthly: 12.days.ago.beginning_of_month.to_date,
          total_count: 2,
          finished_count: 1,
          users_count: 1,
          mean_duration: 60.0,
          completion_rate: 0.5,
          duration_quantile_d2cba: 60.0,
          duration_quantile_22fa3: 60.0
        },
        # User 1, code_review, 10 days ago month
        {
          flow_type: 'code_review',
          user_id: 1,
          created_event_at_monthly: 10.days.ago.beginning_of_month.to_date,
          total_count: 1,
          finished_count: 1,
          users_count: 1,
          mean_duration: 150.0,
          completion_rate: 1.0,
          duration_quantile_d2cba: 150.0,
          duration_quantile_22fa3: 150.0
        },
        # User 1, duo_chat, 15 days ago month
        {
          flow_type: 'duo_chat',
          user_id: 1,
          created_event_at_monthly: 15.days.ago.beginning_of_month.to_date,
          total_count: 1,
          finished_count: 1,
          users_count: 1,
          mean_duration: 120.0,
          completion_rate: 1.0,
          duration_quantile_d2cba: 120.0,
          duration_quantile_22fa3: 120.0
        },
        # User 1, duo_chat, 50 days ago month
        {
          flow_type: 'duo_chat',
          user_id: 1,
          created_event_at_monthly: 50.days.ago.beginning_of_month.to_date,
          total_count: 1,
          finished_count: 1,
          users_count: 1,
          mean_duration: 90.0,
          completion_rate: 1.0,
          duration_quantile_d2cba: 90.0,
          duration_quantile_22fa3: 90.0
        }
      ])
    end
  end
end
