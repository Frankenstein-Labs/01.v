# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AggregationEngines::MergeRequests, :click_house, time_travel_to: '2026-01-30',
  type: :aggregation_engine,
  feature_category: :value_stream_management do
  let(:engine) { described_class.new(context: engine_context) }
  let(:engine_context) { { scope: ClickHouse::Client::QueryBuilder.new(described_class.table_name) } }

  let_it_be(:project1) { create(:project) }

  let(:state) { MergeRequest.available_states }

  def metric_key(identifier, parameters: {})
    described_class.metrics.find { |metric| metric.identifier == identifier }
      .instance_key(parameters: parameters).to_sym
  end

  before do
    insert_merge_requests_to_click_house(merge_requests_data, default_project: project1)
  end

  describe '.prepare_base_aggregation_scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project_in_group) { create(:project, group: group) }
    let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }

    let(:merge_requests_data) do
      [
        { id: 1, project: project_in_group, state_id: state[:opened], created_at: 10.days.ago },
        { id: 2, project: project_in_subgroup, state_id: state[:opened], created_at: 10.days.ago },
        { id: 3, project: other_project, state_id: state[:opened], created_at: 10.days.ago }
      ]
    end

    subject(:result) do
      scope = described_class.prepare_base_aggregation_scope(send(scope_key))
      ClickHouse::Client.select(scope, :main)
    end

    where(:scope_key, :expected_ids) do
      [
        [:project_in_group,    [1]],
        [:group,               [1, 2]],
        [:subgroup,            [2]],
        [:other_project,       [3]]
      ]
    end

    with_them do
      it 'returns records scoped to the provided context object' do
        expect(result.map { |r| r['id'] }).to match_array(expected_ids)
      end
    end

    context 'with no scope objects' do
      it 'raises an ArgumentError' do
        expect { described_class.prepare_base_aggregation_scope([]) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'versioning' do
    let(:merge_requests_data) do
      [
        { id: 1, state_id: state[:opened], created_at: 10.days.ago,
          _siphon_replicated_at: 10.days.ago },
        { id: 1, state_id: state[:merged], created_at: 10.days.ago, metric_merged_at: 9.days.ago,
          _siphon_replicated_at: 9.days.ago },
        { id: 2, state_id: state[:opened], created_at: 10.days.ago,
          _siphon_replicated_at: 10.days.ago },
        { id: 2, state_id: state[:closed], created_at: 10.days.ago,
          _siphon_replicated_at: 9.days.ago, _siphon_deleted: true }
      ]
    end

    it 'aggregates only the latest non-deleted version per primary key' do
      request = {
        dimensions: [{ identifier: :state_id }],
        metrics: [{ identifier: :total_count }]
      }

      expect(engine).to execute_aggregation(request).and_return(match_array([
        { state_id: 'merged', total_count: 1 }
      ]))
    end
  end

  describe 'dimensions' do
    describe 'created_at' do
      let(:merge_requests_data) do
        [
          { id: 1, state_id: state[:opened], created_at: 10.days.ago },
          { id: 2, state_id: state[:opened], created_at: 10.days.ago },
          { id: 3, state_id: state[:opened], created_at: 100.days.ago }
        ]
      end

      it 'groups merge requests by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :created_at }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_at: 10.days.ago.beginning_of_month,  total_count: 2 },
          { created_at: 100.days.ago.beginning_of_month, total_count: 1 }
        ]))
      end

      it 'groups merge requests by daily buckets' do
        request = {
          dimensions: [{ identifier: :created_at, parameters: { granularity: 'daily' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_at_daily: 10.days.ago.beginning_of_day,  total_count: 2 },
          { created_at_daily: 100.days.ago.beginning_of_day, total_count: 1 }
        ]))
      end
    end

    describe 'metric_merged_at' do
      let(:merge_requests_data) do
        [
          { id: 1, state_id: state[:merged], created_at: 20.days.ago, metric_merged_at: 10.days.ago },
          { id: 2, state_id: state[:merged], created_at: 20.days.ago, metric_merged_at: 10.days.ago },
          { id: 3, state_id: state[:merged], created_at: 110.days.ago, metric_merged_at: 100.days.ago }
        ]
      end

      it 'groups merge requests by monthly merge time buckets by default' do
        request = {
          dimensions: [{ identifier: :metric_merged_at }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { metric_merged_at: 10.days.ago.beginning_of_month,  total_count: 2 },
          { metric_merged_at: 100.days.ago.beginning_of_month, total_count: 1 }
        ]))
      end

      it 'groups merge requests by daily merge time buckets' do
        request = {
          dimensions: [{ identifier: :metric_merged_at, parameters: { granularity: 'daily' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { metric_merged_at_daily: 10.days.ago.beginning_of_day,  total_count: 2 },
          { metric_merged_at_daily: 100.days.ago.beginning_of_day, total_count: 1 }
        ]))
      end
    end
  end

  describe 'metrics' do
    describe 'time_to_merge_quantile' do
      let(:merge_requests_data) do
        [
          { id: 1, state_id: state[:merged], created_at: 10.days.ago,
            metric_merged_at: 10.days.ago + 100.seconds },
          { id: 2, state_id: state[:merged], created_at: 10.days.ago,
            metric_merged_at: 10.days.ago + 200.seconds },
          { id: 3, state_id: state[:merged], created_at: 10.days.ago,
            metric_merged_at: 10.days.ago + 300.seconds }
        ]
      end

      it 'calculates time to merge quantile in milliseconds' do
        request = {
          metrics: [{ identifier: :time_to_merge_quantile, parameters: { quantile: 0.5 } }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { metric_key(:time_to_merge_quantile, parameters: { quantile: 0.5 }) => 200_000.0 }
        ])
      end

      context 'when metric_merged_at is NULL' do
        let(:merge_requests_data) do
          [{ id: 1, state_id: state[:opened], created_at: 10.days.ago, metric_merged_at: nil }]
        end

        it 'returns nil for the quantile' do
          request = {
            metrics: [{ identifier: :time_to_merge_quantile, parameters: { quantile: 0.5 } }]
          }

          expect(engine).to execute_aggregation(request).and_return([
            { metric_key(:time_to_merge_quantile, parameters: { quantile: 0.5 }) => nil }
          ])
        end
      end
    end
  end

  describe 'filters' do
    let(:merge_requests_data) do
      [
        { id: 1, state_id: state[:opened], target_branch: 'main',    created_at: 10.days.ago },
        { id: 2, state_id: state[:merged], target_branch: 'main',    created_at: 100.days.ago,
          metric_merged_at: 100.days.ago },
        { id: 3, state_id: state[:closed], target_branch: 'develop', created_at: 10.days.ago }
      ]
    end

    describe 'target_branch' do
      it 'filters by target branch' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :target_branch, values: 'main' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'filters by multiple target branches' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :target_branch, values: %w[main develop] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end
    end

    describe 'state_id' do
      it 'filters by state name string' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :state_id, values: 'merged' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 1 }
        ])
      end

      it 'filters by multiple state name strings' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :state_id, values: %w[opened closed] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'returns no results when all state names are unrecognized' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :state_id, values: 'invalid' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 0 }
        ])
      end

      it 'silently drops unrecognized state names mixed with valid ones' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :state_id, values: %w[merged invalid] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 1 }
        ])
      end
    end

    describe 'created_at' do
      it 'filters by created_at range' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :created_at, values: (30.days.ago..) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end
    end

    describe 'metric_merged_at' do
      it 'filters by metric_merged_at range' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :metric_merged_at, values: (30.days.ago..) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 0 }
        ])
      end
    end
  end

  describe 'comprehensive test with all metrics, dimensions, and filters combined' do
    let(:merge_requests_data) do
      [
        # Pass filters: main branch, within 30 days
        { id: 1, state_id: state[:merged], target_branch: 'main', created_at: 10.days.ago,
          metric_merged_at: 10.days.ago + 100.seconds },
        { id: 2, state_id: state[:merged], target_branch: 'main', created_at: 10.days.ago,
          metric_merged_at: 10.days.ago + 200.seconds },
        # Excluded: created_at outside 30-day window
        { id: 3, state_id: state[:merged], target_branch: 'main', created_at: 50.days.ago,
          metric_merged_at: 50.days.ago + 300.seconds },
        # Excluded: different target branch
        { id: 4, state_id: state[:merged], target_branch: 'develop', created_at: 10.days.ago,
          metric_merged_at: 10.days.ago + 400.seconds }
      ]
    end

    it 'applies dimensions, metrics, and filters together' do
      request = {
        dimensions: [
          { identifier: :target_branch },
          { identifier: :metric_merged_at }
        ],
        metrics: [
          { identifier: :total_count },
          { identifier: :throughput_count }
        ],
        filters: [
          { identifier: :target_branch, values: 'main' },
          { identifier: :created_at, values: (30.days.ago..) }
        ],
        order: [
          { identifier: :target_branch,    direction: :asc },
          { identifier: :metric_merged_at, direction: :asc }
        ]
      }

      expect(engine).to execute_aggregation(request).and_return(match_array([
        {
          target_branch: 'main',
          metric_merged_at: 10.days.ago.beginning_of_month,
          total_count: 2,
          throughput_count: 2
        }
      ]))
    end
  end
end
