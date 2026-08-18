# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AggregationEngines::FinishedPipelines, :click_house, time_travel_to: '2026-01-30',
  type: :aggregation_engine,
  feature_category: :pipeline_composition do
  let(:engine) { described_class.new(context: engine_context) }
  let(:engine_context) { { scope: ClickHouse::Client::QueryBuilder.new(described_class.table_name) } }

  let_it_be(:project1) { create(:project) }
  let_it_be(:project2) { create(:project) }

  before do
    clickhouse_fixture(:ci_finished_pipelines, pipelines_data.map do |pipeline|
      pipeline.reverse_merge(
        path: (pipeline[:project] || project1).project_namespace.traversal_path(with_organization: false),
        source: 'push',
        ref: 'main',
        committed_at: pipeline[:started_at],
        created_at: pipeline[:started_at],
        finished_at: pipeline[:started_at] + pipeline.fetch(:duration, 0).seconds
      ).except(:project)
    end)
  end

  describe '.prepare_base_aggregation_scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project_in_group) { create(:project, group: group) }
    let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }

    let(:pipelines_data) do
      [
        { id: 1, path: project_in_group.project_namespace.traversal_path(with_organization: false),
          status: 'success', duration: 60, started_at: 10.days.ago },
        { id: 2, path: project_in_subgroup.project_namespace.traversal_path(with_organization: false),
          status: 'success', duration: 60, started_at: 10.days.ago },
        { id: 3, path: other_project.project_namespace.traversal_path(with_organization: false),
          status: 'success', duration: 60, started_at: 10.days.ago }
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
  end

  describe 'dimensions' do
    describe 'status' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'success', duration: 200, started_at: 10.days.ago },
          { id: 3, status: 'failed', duration: 50, started_at: 10.days.ago }
        ]
      end

      it 'groups pipelines by status' do
        request = {
          dimensions: [{ identifier: :status }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { status: 'success', total_count: 2 },
          { status: 'failed', total_count: 1 }
        ]))
      end
    end

    describe 'source' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, source: 'push', started_at: 10.days.ago },
          { id: 2, status: 'success', duration: 200, source: 'schedule', started_at: 10.days.ago }
        ]
      end

      it 'groups pipelines by source' do
        request = {
          dimensions: [{ identifier: :source }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { source: 'push', total_count: 1 },
          { source: 'schedule', total_count: 1 }
        ]))
      end
    end

    describe 'ref' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, ref: 'main', started_at: 10.days.ago },
          { id: 2, status: 'success', duration: 200, ref: 'develop', started_at: 10.days.ago }
        ]
      end

      it 'groups pipelines by ref' do
        request = {
          dimensions: [{ identifier: :ref }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { ref: 'main', total_count: 1 },
          { ref: 'develop', total_count: 1 }
        ]))
      end
    end

    describe 'project_id' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, project: project1, started_at: 10.days.ago },
          { id: 2, status: 'success', duration: 200, project: project1, started_at: 10.days.ago },
          { id: 3, status: 'failed', duration: 50, project: project2, started_at: 10.days.ago }
        ]
      end

      it 'groups pipelines by project_id' do
        request = {
          dimensions: [{ identifier: :project_id }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { project_id: project1.project_namespace_id, total_count: 2 },
          { project_id: project2.project_namespace_id, total_count: 1 }
        ]))
      end

      context 'when only one project is in scope' do
        let(:pipelines_data) do
          [
            { id: 1, status: 'success', duration: 100, project: project1, started_at: 10.days.ago },
            { id: 2, status: 'failed', duration: 50, project: project1, started_at: 10.days.ago }
          ]
        end

        it 'returns a single project_id group' do
          request = {
            dimensions: [{ identifier: :project_id }],
            metrics: [{ identifier: :total_count }]
          }

          expect(engine).to execute_aggregation(request).and_return([
            { project_id: project1.project_namespace_id, total_count: 2 }
          ])
        end
      end

      it 'groups pipelines by project_id with project request' do
        request = {
          dimensions: [{ identifier: :project }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { project_id: project1.project_namespace_id, total_count: 2 },
          { project_id: project2.project_namespace_id, total_count: 1 }
        ]))
      end
    end

    describe 'started_at' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'success', duration: 200, started_at: 10.days.ago },
          { id: 3, status: 'success', duration: 50, started_at: 100.days.ago }
        ]
      end

      it 'groups pipelines by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :started_at }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { started_at: 10.days.ago.beginning_of_month, total_count: 2 },
          { started_at: 100.days.ago.beginning_of_month, total_count: 1 }
        ]))
      end

      it 'groups pipelines by weekly buckets' do
        request = {
          dimensions: [{ identifier: :started_at, parameters: { granularity: 'weekly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { started_at_weekly: 10.days.ago.beginning_of_week, total_count: 2 },
          { started_at_weekly: 100.days.ago.beginning_of_week, total_count: 1 }
        ]))
      end
    end

    describe 'finished_at' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'success', duration: 200, started_at: 10.days.ago },
          { id: 3, status: 'success', duration: 50, started_at: 100.days.ago }
        ]
      end

      it 'groups pipelines by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :finished_at }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { finished_at: 10.days.ago.beginning_of_month, total_count: 2 },
          { finished_at: 100.days.ago.beginning_of_month, total_count: 1 }
        ]))
      end
    end
  end

  describe 'metrics' do
    describe 'total_count' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'failed', duration: 50, started_at: 10.days.ago },
          { id: 3, status: 'canceled', duration: 30, started_at: 10.days.ago }
        ]
      end

      it 'counts total pipelines' do
        request = {
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end
    end

    describe 'duration_quantile' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'success', duration: 200, started_at: 10.days.ago },
          { id: 3, status: 'success', duration: 300, started_at: 10.days.ago }
        ]
      end

      it 'calculates duration quantile' do
        request = {
          metrics: [{ identifier: :duration_quantile, parameters: { quantile: 0.5 } }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { duration_quantile_d2cba: 200.0 }
        ])
      end
    end

    describe 'success_rate' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'success', duration: 200, started_at: 10.days.ago },
          { id: 3, status: 'failed', duration: 50, started_at: 10.days.ago },
          { id: 4, status: 'canceled', duration: 30, started_at: 10.days.ago }
        ]
      end

      it 'calculates success rate' do
        request = {
          metrics: [{ identifier: :success_rate }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { success_rate: 0.5 }
        ])
      end
    end

    describe 'failure_rate' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'failed', duration: 50, started_at: 10.days.ago },
          { id: 3, status: 'failed', duration: 60, started_at: 10.days.ago },
          { id: 4, status: 'canceled', duration: 30, started_at: 10.days.ago }
        ]
      end

      it 'calculates failure rate' do
        request = {
          metrics: [{ identifier: :failure_rate }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { failure_rate: 0.5 }
        ])
      end
    end

    describe 'canceled_rate' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'canceled', duration: 30, started_at: 10.days.ago }
        ]
      end

      it 'calculates canceled rate' do
        request = {
          metrics: [{ identifier: :canceled_rate }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { canceled_rate: 0.5 }
        ])
      end
    end

    describe 'skipped_rate' do
      let(:pipelines_data) do
        [
          { id: 1, status: 'success', duration: 100, started_at: 10.days.ago },
          { id: 2, status: 'skipped', duration: 0, started_at: 10.days.ago }
        ]
      end

      it 'calculates skipped rate' do
        request = {
          metrics: [{ identifier: :skipped_rate }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { skipped_rate: 0.5 }
        ])
      end
    end
  end

  describe 'filters' do
    let(:pipelines_data) do
      [
        { id: 1, status: 'success', duration: 100, source: 'push', ref: 'main', started_at: 10.days.ago },
        { id: 2, status: 'failed', duration: 50, source: 'schedule', ref: 'develop', started_at: 100.days.ago },
        { id: 3, status: 'canceled', duration: 30, source: 'push', ref: 'main', started_at: 10.days.ago }
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
    end

    describe 'source' do
      it 'filters by source' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :source, values: 'push' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
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

    describe 'started_at' do
      it 'filters by started_at range' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :started_at, values: (30.days.ago..) }]
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
  end

  describe 'comprehensive test with all metrics, dimensions, and filters combined' do
    let(:pipelines_data) do
      [
        { id: 1, status: 'success', duration: 100, source: 'push', ref: 'main', started_at: 10.days.ago },
        { id: 2, status: 'success', duration: 200, source: 'push', ref: 'main', started_at: 10.days.ago },
        { id: 3, status: 'failed', duration: 50, source: 'push', ref: 'main', started_at: 10.days.ago },
        { id: 4, status: 'canceled', duration: 30, source: 'push', ref: 'main', started_at: 10.days.ago },
        { id: 5, status: 'success', duration: 150, source: 'schedule', ref: 'main', started_at: 50.days.ago },
        { id: 6, status: 'skipped', duration: 0, source: 'push', ref: 'develop', started_at: 10.days.ago }
      ]
    end

    it 'combined test' do
      request = {
        dimensions: [
          { identifier: :status },
          { identifier: :started_at }
        ],
        metrics: [
          { identifier: :total_count },
          { identifier: :duration_quantile },
          { identifier: :success_rate },
          { identifier: :failure_rate },
          { identifier: :canceled_rate },
          { identifier: :skipped_rate }
        ],
        filters: [
          { identifier: :source, values: 'push' },
          { identifier: :started_at, values: (60.days.ago..) },
          { identifier: :finished_at, values: (..Time.current) }
        ],
        order: [{ identifier: :status, direction: :asc },
          { identifier: :started_at, direction: :asc }]
      }

      expect(engine).to execute_aggregation(request).and_return([
        {
          status: 'canceled',
          started_at: 10.days.ago.beginning_of_month,
          total_count: 1,
          duration_quantile: 30.0,
          success_rate: 0.0,
          failure_rate: 0.0,
          canceled_rate: 1.0,
          skipped_rate: 0.0
        },
        {
          status: 'failed',
          started_at: 10.days.ago.beginning_of_month,
          total_count: 1,
          duration_quantile: 50.0,
          success_rate: 0.0,
          failure_rate: 1.0,
          canceled_rate: 0.0,
          skipped_rate: 0.0
        },
        {
          status: 'skipped',
          started_at: 10.days.ago.beginning_of_month,
          total_count: 1,
          duration_quantile: 0.0,
          success_rate: 0.0,
          failure_rate: 0.0,
          canceled_rate: 0.0,
          skipped_rate: 1.0
        },
        {
          status: 'success',
          started_at: 10.days.ago.beginning_of_month,
          total_count: 2,
          duration_quantile: 150.0,
          success_rate: 1.0,
          failure_rate: 0.0,
          canceled_rate: 0.0,
          skipped_rate: 0.0
        }
      ])
    end
  end
end
