# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AggregationEngines::Deployments, :click_house, time_travel_to: '2026-01-30',
  type: :aggregation_engine,
  feature_category: :dora_metrics do
  let(:engine) { described_class.new(context: engine_context) }
  let(:engine_context) { { scope: ClickHouse::Client::QueryBuilder.new(described_class.table_name) } }

  let_it_be(:project1) { create(:project) }
  let_it_be(:project2) { create(:project) }

  let(:s) { ::Deployment.statuses }

  before do
    clickhouse_fixture(:siphon_deployments, deployments_data.map do |d|
      d.reverse_merge(
        iid: d[:id],
        project_id: (d[:project] || project1).id,
        ref: 'main',
        tag: false,
        sha: 'abc123',
        user_id: nil,
        updated_at: d[:created_at],
        traversal_path: (d[:project] || project1).project_namespace.traversal_path(with_organization: true).to_s,
        _siphon_replicated_at: d[:created_at],
        _siphon_deleted: false
      ).except(:project)
    end)
  end

  describe '.prepare_base_aggregation_scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project_in_group) { create(:project, group: group) }
    let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }

    let(:deployments_data) do
      [
        { id: 1, project: project_in_group,    status: s[:success], environment_id: 1, created_at: 10.days.ago,
          finished_at: 10.days.ago },
        { id: 2, project: project_in_subgroup, status: s[:success], environment_id: 1, created_at: 10.days.ago,
          finished_at: 10.days.ago },
        { id: 3, project: other_project,       status: s[:success], environment_id: 1, created_at: 10.days.ago,
          finished_at: 10.days.ago }
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

    context 'with multiple scope objects' do
      it 'combines the scopes with OR' do
        scope = described_class.prepare_base_aggregation_scope([subgroup, other_project])
        result = ClickHouse::Client.select(scope, :main)

        expect(result.map { |r| r['id'] }).to match_array([2, 3])
      end
    end

    context 'with no scope objects' do
      it 'raises an ArgumentError' do
        expect { described_class.prepare_base_aggregation_scope([]) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'versioning' do
    let(:deployments_data) do
      [
        { id: 1, status: s[:running], environment_id: 1, created_at: 10.days.ago, finished_at: nil,
          _siphon_replicated_at: 10.days.ago },
        { id: 1, status: s[:success], environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago,
          _siphon_replicated_at: 9.days.ago },
        { id: 2, status: s[:running], environment_id: 1, created_at: 10.days.ago, finished_at: nil,
          _siphon_replicated_at: 10.days.ago },
        { id: 2, status: s[:failed],  environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago,
          _siphon_replicated_at: 9.days.ago, _siphon_deleted: true }
      ]
    end

    it 'aggregates only the latest non-deleted version per primary key' do
      request = {
        dimensions: [{ identifier: :status }],
        metrics: [{ identifier: :total_count }]
      }

      expect(engine).to execute_aggregation(request).and_return(match_array([
        { status: 'success', total_count: 1 }
      ]))
    end
  end

  describe 'dimensions' do
    describe 'status' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success], environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 2, status: s[:success], environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 3, status: s[:failed],  environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago }
        ]
      end

      it 'groups deployments by status' do
        request = {
          dimensions: [{ identifier: :status }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { status: 'success', total_count: 2 },
          { status: 'failed',  total_count: 1 }
        ]))
      end
    end

    describe 'environment_id' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success], environment_id: 10, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 2, status: s[:success], environment_id: 20, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 3, status: s[:success], environment_id: 10, created_at: 10.days.ago, finished_at: 10.days.ago }
        ]
      end

      it 'groups deployments by environment_id' do
        request = {
          dimensions: [{ identifier: :environment_id }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { environment_id: 10, total_count: 2 },
          { environment_id: 20, total_count: 1 }
        ]))
      end

      it 'groups deployments by environment with environment request' do
        request = {
          dimensions: [{ identifier: :environment }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { environment_id: 10, total_count: 2 },
          { environment_id: 20, total_count: 1 }
        ]))
      end
    end

    describe 'ref' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success], environment_id: 1, ref: 'main',    created_at: 10.days.ago,
            finished_at: 10.days.ago },
          { id: 2, status: s[:success], environment_id: 1, ref: 'develop', created_at: 10.days.ago,
            finished_at: 10.days.ago }
        ]
      end

      it 'groups deployments by ref' do
        request = {
          dimensions: [{ identifier: :ref }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { ref: 'main',    total_count: 1 },
          { ref: 'develop', total_count: 1 }
        ]))
      end
    end

    describe 'finished_at' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success], environment_id: 1, created_at: 10.days.ago,  finished_at: 10.days.ago },
          { id: 2, status: s[:success], environment_id: 1, created_at: 10.days.ago,  finished_at: 10.days.ago },
          { id: 3, status: s[:success], environment_id: 1, created_at: 100.days.ago, finished_at: 100.days.ago }
        ]
      end

      it 'groups deployments by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :finished_at }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { finished_at: 10.days.ago.beginning_of_month,  total_count: 2 },
          { finished_at: 100.days.ago.beginning_of_month, total_count: 1 }
        ]))
      end

      it 'groups deployments by weekly buckets' do
        request = {
          dimensions: [{ identifier: :finished_at, parameters: { granularity: 'weekly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { finished_at_weekly: 10.days.ago.beginning_of_week,  total_count: 2 },
          { finished_at_weekly: 100.days.ago.beginning_of_week, total_count: 1 }
        ]))
      end

      it 'groups deployments by daily buckets' do
        request = {
          dimensions: [{ identifier: :finished_at, parameters: { granularity: 'daily' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { finished_at_daily: 10.days.ago.beginning_of_day,  total_count: 2 },
          { finished_at_daily: 100.days.ago.beginning_of_day, total_count: 1 }
        ]))
      end
    end

    describe 'created_at' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success], environment_id: 1, created_at: 10.days.ago,  finished_at: 10.days.ago },
          { id: 2, status: s[:success], environment_id: 1, created_at: 100.days.ago, finished_at: 100.days.ago }
        ]
      end

      it 'groups deployments by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :created_at }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_at: 10.days.ago.beginning_of_month,  total_count: 1 },
          { created_at: 100.days.ago.beginning_of_month, total_count: 1 }
        ]))
      end

      it 'groups deployments by daily buckets' do
        request = {
          dimensions: [{ identifier: :created_at, parameters: { granularity: 'daily' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_at_daily: 10.days.ago.beginning_of_day,  total_count: 1 },
          { created_at_daily: 100.days.ago.beginning_of_day, total_count: 1 }
        ]))
      end
    end
  end

  describe 'metrics' do
    describe 'total_count' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success],  environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 2, status: s[:failed],   environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 3, status: s[:canceled], environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago }
        ]
      end

      it 'counts total deployments' do
        request = { metrics: [{ identifier: :total_count }] }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end
    end

    describe 'deployment_duration_quantile' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success], environment_id: 1, created_at: 10.days.ago,
            finished_at: 10.days.ago + 100.seconds },
          { id: 2, status: s[:success], environment_id: 1, created_at: 10.days.ago,
            finished_at: 10.days.ago + 200.seconds },
          { id: 3, status: s[:success], environment_id: 1, created_at: 10.days.ago,
            finished_at: 10.days.ago + 300.seconds }
        ]
      end

      it 'calculates deployment duration quantile in milliseconds' do
        request = {
          metrics: [{ identifier: :deployment_duration_quantile, parameters: { quantile: 0.5 } }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { deployment_duration_quantile_d2cba: 200_000.0 }
        ])
      end

      context 'when all rows have NULL finished_at' do
        let(:deployments_data) do
          [
            { id: 1, status: s[:running], environment_id: 1, created_at: 10.days.ago, finished_at: nil }
          ]
        end

        it 'returns nil for the quantile' do
          request = { metrics: [{ identifier: :deployment_duration_quantile, parameters: { quantile: 0.5 } }] }

          expect(engine).to execute_aggregation(request).and_return([
            { deployment_duration_quantile_d2cba: nil }
          ])
        end
      end
    end

    describe 'success_rate' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success],  environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 2, status: s[:success],  environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 3, status: s[:failed],   environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 4, status: s[:canceled], environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago }
        ]
      end

      it 'calculates success rate out of finished deployments' do
        request = { metrics: [{ identifier: :success_rate }] }

        expect(engine).to execute_aggregation(request).and_return([
          { success_rate: 0.5 }
        ])
      end
    end

    describe 'failure_rate' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success],  environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 2, status: s[:failed],   environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 3, status: s[:failed],   environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 4, status: s[:canceled], environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago }
        ]
      end

      it 'calculates failure rate out of finished deployments' do
        request = { metrics: [{ identifier: :failure_rate }] }

        expect(engine).to execute_aggregation(request).and_return([
          { failure_rate: 0.5 }
        ])
      end
    end

    describe 'canceled_rate' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success],  environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 2, status: s[:canceled], environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago }
        ]
      end

      it 'calculates canceled rate out of finished deployments' do
        request = { metrics: [{ identifier: :canceled_rate }] }

        expect(engine).to execute_aggregation(request).and_return([
          { canceled_rate: 0.5 }
        ])
      end
    end

    describe 'finished deployments as denominator' do
      let(:deployments_data) do
        [
          { id: 1, status: s[:success],  environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 2, status: s[:failed],   environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 3, status: s[:canceled], environment_id: 1, created_at: 10.days.ago, finished_at: 10.days.ago },
          { id: 4, status: s[:running],  environment_id: 1, created_at: 10.days.ago, finished_at: nil },
          { id: 5, status: s[:blocked],  environment_id: 1, created_at: 10.days.ago, finished_at: nil }
        ]
      end

      it 'uses finished deployments as denominator for success_rate' do
        request = { metrics: [{ identifier: :success_rate }] }

        expect(engine).to execute_aggregation(request).and_return([
          { success_rate: be_within(0.01).of(1.0 / 3.0) }
        ])
      end
    end
  end

  describe 'filters' do
    let(:deployments_data) do
      [
        { id: 1, status: s[:success],  environment_id: 10, ref: 'main',    created_at: 10.days.ago,
          finished_at: 10.days.ago },
        { id: 2, status: s[:failed],   environment_id: 10, ref: 'develop', created_at: 100.days.ago,
          finished_at: 100.days.ago },
        { id: 3, status: s[:canceled], environment_id: 20, ref: 'main',    created_at: 10.days.ago,
          finished_at: 10.days.ago }
      ]
    end

    describe 'status' do
      it 'filters by status' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :status, values: 'success' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 1 }
        ])
      end

      it 'filters by multiple statuses' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :status, values: %w[success failed] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end
    end

    describe 'environment_id' do
      it 'filters by single environment Global ID' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :environment_id, values: 'gid://gitlab/Environment/10' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'filters by multiple environment Global IDs' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :environment_id,
                      values: %w[gid://gitlab/Environment/10 gid://gitlab/Environment/20] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end
    end

    describe 'ref' do
      it 'filters by ref' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :ref, values: 'main' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end
    end

    describe 'finished_at' do
      it 'filters by finished_at range' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :finished_at, values: (30.days.ago..) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
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
  end

  describe 'comprehensive test with all metrics, dimensions, and filters combined' do
    let(:deployments_data) do
      [
        { id: 1, status: s[:success],  environment_id: 10, ref: 'main',    created_at: 10.days.ago,
          finished_at: 10.days.ago },
        { id: 2, status: s[:success],  environment_id: 10, ref: 'main',    created_at: 10.days.ago,
          finished_at: 10.days.ago },
        { id: 3, status: s[:failed],   environment_id: 10, ref: 'main',    created_at: 10.days.ago,
          finished_at: 10.days.ago },
        { id: 4, status: s[:canceled], environment_id: 10, ref: 'main',    created_at: 10.days.ago,
          finished_at: 10.days.ago },
        { id: 5, status: s[:success],  environment_id: 10, ref: 'main',    created_at: 50.days.ago,
          finished_at: 50.days.ago },
        { id: 6, status: s[:running],  environment_id: 20, ref: 'develop', created_at: 10.days.ago, finished_at: nil }
      ]
    end

    it 'applies dimensions, metrics, and filters together' do
      request = {
        dimensions: [
          { identifier: :status },
          { identifier: :finished_at }
        ],
        metrics: [
          { identifier: :total_count },
          { identifier: :success_rate },
          { identifier: :failure_rate },
          { identifier: :canceled_rate }
        ],
        filters: [
          { identifier: :ref, values: 'main' },
          { identifier: :finished_at, values: (60.days.ago..) }
        ],
        order: [
          { identifier: :status,      direction: :asc },
          { identifier: :finished_at, direction: :asc }
        ]
      }

      expect(engine).to execute_aggregation(request).and_return(match_array([
        {
          status: 'canceled',
          finished_at: Date.new(2026, 1, 1),
          total_count: 1,
          success_rate: 0.0,
          failure_rate: 0.0,
          canceled_rate: 1.0
        },
        {
          status: 'failed',
          finished_at: Date.new(2026, 1, 1),
          total_count: 1,
          success_rate: 0.0,
          failure_rate: 1.0,
          canceled_rate: 0.0
        },
        {
          status: 'success',
          finished_at: Date.new(2026, 1, 1),
          total_count: 2,
          success_rate: 1.0,
          failure_rate: 0.0,
          canceled_rate: 0.0
        },
        {
          status: 'success',
          finished_at: Date.new(2025, 12, 1),
          total_count: 1,
          success_rate: 1.0,
          failure_rate: 0.0,
          canceled_rate: 0.0
        }
      ]))
    end
  end
end
