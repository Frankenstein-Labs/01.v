# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::AggregationEngines::CodeSuggestions, :click_house, time_travel_to: '2026-01-30',
  type: :aggregation_engine,
  feature_category: :product_analytics do
  let(:engine) { described_class.new(context: engine_context) }
  let(:engine_context) { { scope: ClickHouse::Client::QueryBuilder.new(described_class.table_name) } }

  let_it_be(:project1) { create(:project) }

  before do
    events_data = suggestions_data.flat_map do |suggestion|
      events_for_suggestion(suggestion)
    end.compact

    clickhouse_fixture(:ai_usage_events, events_data)
  end

  def events_for_suggestion(data)
    data = data.reverse_merge(unique_tracking_id: SecureRandom.uuid)
    events = []

    if data[:shown_at]
      events << event_data(data.merge(
        event: Ai::UsageEvent.events[:code_suggestion_shown_in_ide],
        timestamp: data[:shown_at]
      ))
    end

    if data[:accepted_at]
      events << event_data(data.merge(
        event: Ai::UsageEvent.events[:code_suggestion_accepted_in_ide],
        timestamp: data[:accepted_at]
      ))
    end

    if data[:rejected_at]
      events << event_data(data.merge(
        event: Ai::UsageEvent.events[:code_suggestion_rejected_in_ide],
        timestamp: data[:rejected_at]
      ))
    end

    events
  end

  def event_data(data)
    {
      user_id: data[:user_id],
      event: data[:event],
      timestamp: data[:timestamp],
      namespace_path: data[:project].project_namespace.traversal_path(with_organization: false),
      extras: data.slice(
        *%i[unique_tracking_id suggestion_size language branch_name
          ide_name ide_vendor ide_version extension_name extension_version
          language_server_version model_name model_engine]
      )
    }
  end

  describe '.prepare_base_aggregation_scope' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project_in_group) { create(:project, group: group) }
    let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }

    let(:suggestions_data) do
      [
        { user_id: 1, project: project_in_group, shown_at: 10.days.ago },
        { user_id: 2, project: project_in_subgroup, shown_at: 10.days.ago },
        { user_id: 3, project: other_project, shown_at: 10.days.ago }
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

    context 'with no scope objects' do
      it 'raises an ArgumentError' do
        expect { described_class.prepare_base_aggregation_scope([]) }.to raise_error(ArgumentError)
      end
    end
  end

  describe 'dimensions' do
    describe 'language' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, language: 'ruby', shown_at: 10.days.ago },
          { user_id: 1, project: project1, language: 'ruby', shown_at: 10.days.ago },
          { user_id: 1, project: project1, language: 'python', shown_at: 10.days.ago }
        ]
      end

      it 'groups suggestions by language' do
        request = {
          dimensions: [{ identifier: :language }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { language: 'ruby', total_count: 2 },
          { language: 'python', total_count: 1 }
        ]))
      end
    end

    describe 'ide_name' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, ide_name: 'vscode', shown_at: 10.days.ago },
          { user_id: 1, project: project1, ide_name: 'neovim', shown_at: 10.days.ago }
        ]
      end

      it 'groups suggestions by ide_name' do
        request = {
          dimensions: [{ identifier: :ide_name }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { ide_name: 'vscode', total_count: 1 },
          { ide_name: 'neovim', total_count: 1 }
        ]))
      end
    end

    describe 'user_id' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 2, project: project1, shown_at: 10.days.ago }
        ]
      end

      it 'groups suggestions by user_id' do
        request = {
          dimensions: [{ identifier: :user_id }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { user_id: 1, total_count: 2 },
          { user_id: 2, total_count: 1 }
        ]))
      end

      it 'groups suggestions by user_id with user request' do
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
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 1, project: project1, shown_at: 100.days.ago }
        ]
      end

      it 'groups suggestions by monthly buckets by default' do
        request = {
          dimensions: [{ identifier: :timestamp }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp: 10.days.ago.beginning_of_month.to_date, total_count: 2 },
          { timestamp: 100.days.ago.beginning_of_month.to_date, total_count: 1 }
        ]))
      end

      it 'groups suggestions by monthly buckets explicitly' do
        request = {
          dimensions: [{ identifier: :timestamp, parameters: { granularity: 'monthly' } }],
          metrics: [{ identifier: :total_count }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { timestamp_monthly: 10.days.ago.beginning_of_month.to_date, total_count: 2 },
          { timestamp_monthly: 100.days.ago.beginning_of_month.to_date, total_count: 1 }
        ]))
      end
    end
  end

  describe 'metrics' do
    describe 'users_count' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 2, project: project1, shown_at: 10.days.ago }
        ]
      end

      it 'counts distinct users' do
        request = {
          metrics: [{ identifier: :users_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { users_count: 2 }
        ])
      end
    end

    describe 'acceptance_rate' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 2, project: project1, shown_at: 10.days.ago, accepted_at: 10.days.ago + 3.seconds },
          { user_id: 2, project: project1, shown_at: 10.days.ago }
        ]
      end

      it 'calculates acceptance rate' do
        request = {
          metrics: [{ identifier: :acceptance_rate }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { acceptance_rate: 0.5 }
        ])
      end
    end

    describe 'suggestion_size_sum' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, language: 'ruby', suggestion_size: 10, shown_at: 10.days.ago },
          { user_id: 1, project: project1, language: 'ruby', suggestion_size: 20, shown_at: 10.days.ago },
          { user_id: 2, project: project1, language: 'python', suggestion_size: 15, shown_at: 10.days.ago }
        ]
      end

      it 'sums suggestion sizes' do
        request = {
          metrics: [{ identifier: :suggestion_size_sum }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { suggestion_size_sum: 45 }
        ])
      end

      it 'sums suggestion sizes grouped by language' do
        request = {
          dimensions: [{ identifier: :language }],
          metrics: [{ identifier: :suggestion_size_sum }]
        }

        expect(engine).to execute_aggregation(request).and_return(match_array([
          { language: 'ruby', suggestion_size_sum: 30 },
          { language: 'python', suggestion_size_sum: 15 }
        ]))
      end
    end

    describe 'accepted_count' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 2, project: project1, shown_at: 10.days.ago, accepted_at: 10.days.ago + 3.seconds }
        ]
      end

      it 'counts accepted suggestions' do
        request = {
          metrics: [{ identifier: :accepted_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { accepted_count: 2 }
        ])
      end
    end

    describe 'rejected_count' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, shown_at: 10.days.ago, rejected_at: 10.days.ago + 5.seconds },
          { user_id: 1, project: project1, shown_at: 10.days.ago }
        ]
      end

      it 'counts rejected suggestions' do
        request = {
          metrics: [{ identifier: :rejected_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { rejected_count: 1 }
        ])
      end
    end

    describe 'shown_count' do
      let(:suggestions_data) do
        [
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 1, project: project1, shown_at: 10.days.ago },
          { user_id: 2, project: project1, rejected_at: 10.days.ago }
        ]
      end

      it 'counts shown suggestions' do
        request = {
          metrics: [{ identifier: :shown_count }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { shown_count: 2 }
        ])
      end
    end
  end

  describe 'filters' do
    let(:suggestions_data) do
      [
        { user_id: 1, project: project1, language: 'ruby', ide_name: 'vscode', shown_at: 100.days.ago },
        { user_id: 1, project: project1, language: 'python', ide_name: 'neovim', shown_at: 10.days.ago },
        { user_id: 2, project: project1, language: 'ruby', ide_name: 'vscode', shown_at: 10.days.ago }
      ]
    end

    describe 'user_id' do
      it 'filters by single user GlobalID' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :user_id, values: "gid://gitlab/User/1" }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end

      it 'filters by multiple user GlobalIDs' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :user_id, values: %w[gid://gitlab/User/1 gid://gitlab/User/2] }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 3 }
        ])
      end
    end

    describe 'language' do
      it 'filters by language' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :language, values: 'ruby' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end
    end

    describe 'ide_name' do
      it 'filters by ide_name' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :ide_name, values: 'vscode' }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end
    end

    describe 'timestamp' do
      it 'filters by timestamp range' do
        request = {
          metrics: [{ identifier: :total_count }],
          filters: [{ identifier: :timestamp, values: (30.days.ago..) }]
        }

        expect(engine).to execute_aggregation(request).and_return([
          { total_count: 2 }
        ])
      end
    end
  end

  describe 'comprehensive test with all metrics, dimensions, and filters combined' do
    let(:suggestions_data) do
      [
        { user_id: 1, project: project1, language: 'ruby', suggestion_size: 10,
          shown_at: 10.days.ago, accepted_at: 10.days.ago + 5.seconds },
        { user_id: 1, project: project1, language: 'ruby', suggestion_size: 20,
          shown_at: 10.days.ago, rejected_at: 10.days.ago + 3.seconds },
        { user_id: 2, project: project1, language: 'ruby', suggestion_size: 30,
          shown_at: 10.days.ago, accepted_at: 10.days.ago + 2.seconds },
        { user_id: 1, project: project1, language: 'python', suggestion_size: 40,
          shown_at: 50.days.ago, accepted_at: 50.days.ago + 1.second },
        { user_id: 3, project: project1, language: 'go', suggestion_size: 50, shown_at: 10.days.ago }
      ]
    end

    it 'combined test' do
      request = {
        dimensions: [
          { identifier: :language },
          { identifier: :timestamp, parameters: { granularity: 'monthly' } }
        ],
        metrics: [
          { identifier: :total_count },
          { identifier: :users_count },
          { identifier: :acceptance_rate },
          { identifier: :suggestion_size_sum },
          { identifier: :accepted_count },
          { identifier: :rejected_count },
          { identifier: :shown_count }
        ],
        filters: [
          { identifier: :user_id, values: %w[gid://gitlab/User/1 gid://gitlab/User/2] },
          { identifier: :timestamp, values: (60.days.ago..) }
        ],
        order: [{ identifier: :language, direction: :asc }]
      }

      expect(engine).to execute_aggregation(request).and_return([
        {
          language: 'python',
          timestamp_monthly: 50.days.ago.beginning_of_month.to_date,
          total_count: 1,
          users_count: 1,
          acceptance_rate: 1.0,
          suggestion_size_sum: 40,
          accepted_count: 1,
          rejected_count: 0,
          shown_count: 1
        },
        {
          language: 'ruby',
          timestamp_monthly: 10.days.ago.beginning_of_month.to_date,
          total_count: 3,
          users_count: 2,
          acceptance_rate: 2.0 / 3.0,
          suggestion_size_sum: 60,
          accepted_count: 2,
          rejected_count: 1,
          shown_count: 3
        }
      ])
    end
  end
end
