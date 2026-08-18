# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Timebox::BurnchartDataPoint, :aggregate_failures, feature_category: :team_planning do
  let_it_be(:timebox) { build_stubbed(:milestone) }
  let_it_be(:other_timebox) { build_stubbed(:milestone) }

  describe '#build!' do
    shared_examples 'building chart data point' do
      let(:snapshot) do
        snapshot = Gitlab::Timebox::Snapshot.new(date: Date.current)
        item_states.each { |s| snapshot.add_item(**build_item_state(s)) }

        snapshot
      end

      subject(:data_point) { described_class.new(timebox, snapshot).build!.to_h }

      it 'builds correct chart data point' do
        default_chart_data = {
          date: snapshot.date,
          scope_count: 0,
          scope_weight: 0,
          completed_count: 0,
          completed_weight: 0
        }

        expect(data_point).to eq(default_chart_data.merge(expected_chart_data))
      end
    end

    context 'when snapshot has an empty item_states' do
      let(:item_states) { [] }
      let(:expected_chart_data) { {} }

      it_behaves_like 'building chart data point'
    end

    context 'when only issues are in the snapshot' do
      let(:issues) { build_stubbed_list(:issue, 5) }

      context 'when issues are all open' do
        let(:item_states) do
          [{ item: issues[0], timebox: timebox, weight: 1 },
            { item: issues[1], timebox: timebox, weight: 2, start_state: :closed, end_state: :reopened },
            { item: issues[2], timebox: nil, weight: 100 },
            { item: issues[3], timebox: other_timebox, weight: 200 },
            { item: issues[4], timebox: timebox, weight: 0 }]
        end

        # Only issues[0], issues[1], issues[4] count.
        # issues[2] and issues[3] don't count since they are not in `timebox`
        let(:expected_chart_data) { { scope_count: 3, scope_weight: 3, completed_count: 0, completed_weight: 0 } }

        it_behaves_like 'building chart data point'
      end

      context 'with closed issues' do
        let(:item_states) do
          [{ item: issues[0], timebox: timebox, weight: 1, start_state: :opened, end_state: :closed },
            { item: issues[1], timebox: timebox, weight: 2, start_state: :reopened, end_state: :closed },
            { item: issues[2], timebox: timebox, weight: 3, start_state: :closed, end_state: :closed },
            { item: issues[3], timebox: nil, weight: 100 },
            { item: issues[4], timebox: timebox, weight: 0, start_state: :closed, end_state: :closed }]
        end

        let(:expected_chart_data) { { scope_count: 4, scope_weight: 6, completed_count: 4, completed_weight: 6 } }

        it_behaves_like 'building chart data point'
      end
    end

    context 'when tasks exist' do
      let(:issue1) { build_stubbed(:issue) }
      let(:issue2) { build_stubbed(:issue) }
      let(:task1) { build_stubbed(:work_item, :task) }
      let(:task2) { build_stubbed(:work_item, :task) }
      let(:task3) { build_stubbed(:work_item, :task) }
      let(:task4) { build_stubbed(:work_item, :task) }
      let(:task5) { build_stubbed(:work_item, :task) }

      context 'when both parent (issue) and children (tasks) are weighted' do
        let(:item_states) do
          [
            {
              item: issue1,
              timebox: timebox,
              weight: 7,
              children: [task1, task2, task3, task4]
            },
            { item: task1, timebox: timebox, weight: 1, parent: issue1 },
            { item: task2, timebox: timebox, weight: 10, parent: issue1 },
            { item: task3, timebox: nil, weight: 100, parent: issue1 },
            { item: task4, timebox: other_timebox, weight: 200, parent: issue1 },
            { item: task5, timebox: timebox, weight: 1000, parent: issue2 }
          ]
        end

        let(:expected_chart_data) do
          {
            # `issue1` and its tasks should count as one item for `timebox`
            # `task5` is a top-level task, directly assigned to `timebox`.
            scope_count: 2,
            # The weights of `issue1`'s tasks assigned to the same timebox
            # (i.e., `task1`, `task2`, `task3`) should be summed to derive the weight for `issue1`.
            # Then `task5`'s weight should be counted on its own
            scope_weight: 1 + 10 + 1000,
            completed_count: 0,
            completed_weight: 0
          }
        end

        it_behaves_like 'building chart data point'
      end

      context 'when tasks for an issue are unweighted' do
        let(:item_states) do
          [
            {
              item: issue1,
              timebox: timebox,
              weight: 1,
              children: [task1]
            },
            { item: task1, timebox: timebox, weight: 0, parent: issue1 }
          ]
        end

        let(:expected_chart_data) do
          {
            scope_count: 1,
            scope_weight: 1,
            completed_count: 0,
            completed_weight: 0
          }
        end

        it_behaves_like 'building chart data point'
      end

      context "when the tasks for an issue in the same timebox aren't all closed" do
        let(:item_states) do
          [
            {
              item: issue1, timebox: timebox, weight: 7,
              children: [task1, task2, task3],
              # `issue1`'s state changed from :opened to :closed but -
              # its child tasks that are in the same timebox aren't all closed.
              start_state: :opened, end_state: :closed
            },
            { item: task1, timebox: timebox, weight: 1, parent: issue1, start_state: :opened, end_state: :closed },
            { item: task2, timebox: timebox, weight: 10, parent: issue1, start_state: :opened, end_state: :opened },
            { item: task3, timebox: timebox, weight: 100, parent: issue1, start_state: :closed, end_state: :reopened }
          ]
        end

        let(:expected_chart_data) do
          {
            scope_count: 1,
            scope_weight: 111,
            completed_count: 0,
            completed_weight: 1
          }
        end

        it_behaves_like 'building chart data point'
      end

      context 'when issue and its tasks become all closed' do
        let(:item_states) do
          [
            {
              item: issue1, timebox: timebox, weight: 7,
              children: [task1, task2, task3],
              # `issue1`'s state changed from :opened to :closed but -
              # its child tasks that are in the same timebox aren't all closed.
              start_state: :opened, end_state: :closed
            },
            { item: task1, timebox: timebox, weight: 1, parent: issue1, start_state: :opened, end_state: :closed },
            { item: task2, timebox: timebox, weight: 10, parent: issue1, start_state: :reopened, end_state: :closed },
            { item: task3, timebox: timebox, weight: 100, parent: issue1, start_state: :closed, end_state: :closed }
          ]
        end

        let(:expected_chart_data) do
          {
            scope_count: 1,
            scope_weight: 111,
            completed_count: 1,
            completed_weight: 111
          }
        end

        it_behaves_like 'building chart data point'
      end

      context 'with a closed top-level task' do
        let(:item_states) do
          [
            {
              item: issue1,
              timebox: timebox,
              weight: 7,
              children: [task1],
              start_state: :opened, end_state: :closed
            },
            { item: task1, timebox: timebox, weight: 1, parent: issue1, start_state: :opened, end_state: :closed },
            { item: task2, timebox: timebox, weight: 10, parent: issue2, start_state: :opened, end_state: :closed }
          ]
        end

        let(:expected_chart_data) do
          {
            scope_count: 2,
            scope_weight: 11,
            completed_count: 2,
            completed_weight: 11
          }
        end

        it_behaves_like 'building chart data point'
      end
    end
  end

  describe '.build_data' do
    let(:issues) { build_stubbed_list(:issue, 2) }

    let(:snapshots) do
      [
        Gitlab::Timebox::Snapshot.new(date: Date.current)
          .add_item(**build_item_state(item: issues[0], timebox: timebox, weight: 1)),
        Gitlab::Timebox::Snapshot.new(date: Date.current + 1)
          .add_item(**build_item_state(item: issues[0], timebox: timebox, weight: 1, end_state: :closed))
          .add_item(**build_item_state(item: issues[1], timebox: timebox, weight: 1))
      ]
    end

    subject(:data_points) { described_class.build_data(timebox, snapshots).map(&:to_h) }

    it 'builds correct chart data points' do
      expect(data_points.first).to eq({
        date: Date.current,
        scope_count: 1,
        scope_weight: 1,
        completed_count: 0,
        completed_weight: 0
      })
      expect(data_points.last).to eq({
        date: Date.current + 1,
        scope_count: 2,
        scope_weight: 2,
        completed_count: 1,
        completed_weight: 1
      })
    end
  end

  def build_item_state(opts)
    start_state = ResourceStateEvent.states[opts.delete(:start_state)] if opts.has_key?(:start_state)
    end_state = ResourceStateEvent.states[opts.delete(:end_state)] if opts.has_key?(:end_state)

    {
      item_id: opts.delete(:item).id,
      timebox_id: opts.delete(:timebox)&.id,
      weight: 0,
      start_state: start_state || ResourceStateEvent.states[:opened],
      end_state: end_state || ResourceStateEvent.states[:opened],
      parent_id: opts.delete(:parent)&.id,
      children_ids: Set.new(opts.delete(:children)&.map(&:id))
    }.merge(opts)
  end
end
