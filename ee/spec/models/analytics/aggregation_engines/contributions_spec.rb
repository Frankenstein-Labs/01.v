# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AggregationEngines::Contributions, :click_house, time_travel_to: '2026-01-30',
  type: :aggregation_engine,
  feature_category: :product_analytics do
  let(:engine) { described_class.new(context: engine_context) }
  let(:engine_context) { { scope: ClickHouse::Client::QueryBuilder.new(described_class.table_name) } }

  let_it_be(:project1) { create(:project) }

  before do
    clickhouse_fixture(:contributions_new, contributions_data.map { |c| contribution_row(c) })
  end

  def contribution_row(data)
    {
      id: data[:id],
      path: data[:project].project_namespace.traversal_path(with_organization: true).to_s,
      author_id: data[:author_id],
      target_type: data.fetch(:target_type, ''),
      action: data.fetch(:action, 5),
      created_at: data[:created_at],
      updated_at: data.fetch(:updated_at, data[:created_at]),
      version: data.fetch(:updated_at, data[:created_at]),
      deleted: false
    }
  end

  describe '.prepare_base_aggregation_scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project_in_group) { create(:project, group: group) }
    let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }

    let(:contributions_data) do
      [
        { id: 1, author_id: 1, project: project_in_group, created_at: 10.days.ago },
        { id: 2, author_id: 2, project: project_in_subgroup, created_at: 10.days.ago },
        { id: 3, author_id: 3, project: other_project, created_at: 10.days.ago }
      ]
    end

    subject(:result) do
      scope = described_class.prepare_base_aggregation_scope(send(scope_key))
      ClickHouse::Client.select(scope, :main)
    end

    where(:scope_key, :expected_ids) do
      [
        [:project_in_group,  [1]],
        [:group,             [1, 2]],
        [:subgroup,          [2]],
        [:other_project,     [3]]
      ]
    end

    with_them do
      it 'returns records scoped to the provided context object' do
        expect( # -- ClickHouse result is a plain Ruby array, not an ActiveRecord relation
result.map do |r|
  r['id']
end).to match_array(expected_ids)
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

  describe 'metrics' do
    describe 'users_count' do
      let(:contributions_data) do
        [
          { id: 1, author_id: 1, project: project1, created_at: 10.days.ago },
          { id: 2, author_id: 1, project: project1, created_at: 10.days.ago },
          { id: 3, author_id: 2, project: project1, created_at: 10.days.ago },
          { id: 4, author_id: 3, project: project1, created_at: 10.days.ago }
        ]
      end

      it 'counts distinct number of contributors' do
        request = {
          metrics: [{ identifier: :users_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { users_count: 3 }
        ])
      end
    end

    describe 'total_count' do
      let(:contributions_data) do
        [
          { id: 1, author_id: 1, project: project1, created_at: 10.days.ago },
          { id: 2, author_id: 1, project: project1, created_at: 10.days.ago },
          { id: 3, author_id: 2, project: project1, created_at: 10.days.ago }
        ]
      end

      it 'counts total number of contributions' do
        request = {
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end
    end
  end

  describe 'dimensions' do
    describe 'created_at' do
      let(:contributions_data) do
        [
          { id: 1, author_id: 1, project: project1, created_at: 10.days.ago },
          { id: 2, author_id: 1, project: project1, created_at: 10.days.ago },
          { id: 3, author_id: 2, project: project1, created_at: 100.days.ago }
        ]
      end

      it 'groups contributions by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :created_at }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_at: 10.days.ago.beginning_of_month.to_date, total_count: 2 },
          { created_at: 100.days.ago.beginning_of_month.to_date, total_count: 1 }
        ]))
      end

      it 'groups contributions by weekly buckets' do
        request = {
          dimensions: [{ identifier: :created_at, parameters: { granularity: 'weekly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_at_weekly: 10.days.ago.beginning_of_week(:monday).to_date, total_count: 2 },
          { created_at_weekly: 100.days.ago.beginning_of_week(:monday).to_date, total_count: 1 }
        ]))
      end

      it 'groups contributions by daily buckets' do
        request = {
          dimensions: [{ identifier: :created_at, parameters: { granularity: 'daily' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { created_at_daily: 10.days.ago.to_date, total_count: 2 },
          { created_at_daily: 100.days.ago.to_date, total_count: 1 }
        ]))
      end

      it 'rejects invalid granularity values' do
        request = {
          dimensions: [{ identifier: :created_at, parameters: { granularity: 'yearly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).with_errors(include(match(/granularity/i)))
      end
    end
  end

  describe 'filters' do
    let(:contributions_data) do
      [
        { id: 1, author_id: 1, project: project1, created_at: 100.days.ago },
        { id: 2, author_id: 1, project: project1, created_at: 50.days.ago },
        { id: 3, author_id: 2, project: project1, created_at: 10.days.ago },
        { id: 4, author_id: 3, project: project1, created_at: 5.days.ago }
      ]
    end

    describe 'author_id' do
      it 'filters by single author GlobalID' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :author_id, values: "gid://gitlab/User/1" }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'filters by multiple author GlobalIDs' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :author_id, values: %w[gid://gitlab/User/1 gid://gitlab/User/2] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end
    end

    describe 'created_at' do
      it 'filters by start date' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :created_at, values: (30.days.ago..) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'filters by end date' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :created_at, values: (..20.days.ago) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'filters by date range' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :created_at, values: (60.days.ago..20.days.ago) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 1 }
        ])
      end
    end
  end

  describe 'combined metrics and filters' do
    let(:contributions_data) do
      [
        { id: 1, author_id: 1, project: project1, created_at: 100.days.ago },
        { id: 2, author_id: 1, project: project1, created_at: 10.days.ago },
        { id: 3, author_id: 2, project: project1, created_at: 10.days.ago },
        { id: 4, author_id: 2, project: project1, created_at: 10.days.ago },
        { id: 5, author_id: 3, project: project1, created_at: 5.days.ago }
      ]
    end

    it 'returns both metrics with filters applied' do
      request = {
        metrics: [
          { identifier: :users_count },
          { identifier: :total_count }
        ],
        filters: [
          { identifier: :author_id, values: %w[gid://gitlab/User/1 gid://gitlab/User/2] },
          { identifier: :created_at, values: (30.days.ago..) }
        ]
      }

      expect(engine).to execute_aggregation(request).and_return([
        { users_count: 2, total_count: 3 }
      ])
    end
  end
end
