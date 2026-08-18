# frozen_string_literal: true

module Gitlab
  module Timebox
    # The class represents a data point on the burnchart for a timebox.
    # A data point can be built from a Gitlab::Timebox::Snapshot containing -
    # the ending states of issues/tasks associated with the timebox.
    class BurnchartDataPoint
      include Gitlab::Utils::StrongMemoize

      attr_reader :date,
        :scope_count, # the total number of items in the timebox on the date.
        :scope_weight, # the total weight of items in the timebox on the date
        :completed_count, # the number of items in the timebox that were completed on the date
        :completed_weight # the total weight of items in the timebox that were completed on the date

      # @params timebox [Milestone, Iteration] the timebox for which a burndown/up chart is being charted.
      # @params snapshot [Gitlab::Timebox::Snapshot]
      def initialize(timebox, snapshot)
        @date = snapshot.date
        @item_states = snapshot.item_states
        @timebox_id = timebox.id
      end

      def build!
        # For now, only issues can have tasks as children.
        issues, tasks = items_in_timebox.partition { |item| item[:parent_id].nil? }
        issue_ids = issues.to_set { |i| i[:item_id] }
        top_level_tasks = tasks.reject { |task| issue_ids.include?(task[:parent_id]) }
        completed_issues = issues.filter { |i| issue_closed?(i) }
        completed_top_level_tasks = top_level_tasks.filter { |t| closed?(t) }

        @scope_count = issues.count + top_level_tasks.count
        @scope_weight = issues.sum { |i| rollup_weight(i) } + top_level_tasks.pluck(:weight).sum # rubocop:disable CodeReuse/ActiveRecord -- Enumerable#pluck
        @completed_count = completed_issues.count + completed_top_level_tasks.count
        @completed_weight = issues.sum { |i| completed_rollup_weight(i) } + completed_top_level_tasks.pluck(:weight).sum # rubocop:disable CodeReuse/ActiveRecord -- Enumerable#pluck

        self
      end

      def to_h
        {
          date: date,
          scope_count: scope_count,
          scope_weight: scope_weight,
          completed_count: completed_count,
          completed_weight: completed_weight
        }
      end

      # A helper method to map `Gitlab::Timebox::Snapshot`s to BurnchartDataPoints
      #
      # @params timebox [Milestone, Iteration] the timebox for which a burndown/up chart is being charted.
      # @params snapshots [Array<Gitlab::Timebox::Snapshot>] An array of snapshots.
      #
      # @return [Array<BurnchartDataPoint>]
      def self.build_data(timebox, snapshots)
        snapshots.map { |snapshot| new(timebox, snapshot).build! }
      end

      private

      def items_in_timebox
        @item_states.filter { |item| item[:timebox_id] == @timebox_id }
      end

      def items_by_id
        @item_states.index_by { |item| item[:item_id] }
      end
      strong_memoize_attr :items_by_id

      def rollup_weight(issue)
        tasks = rollup_tasks(issue)

        return issue[:weight] if tasks.empty? || none_weighted?(tasks)

        tasks.pluck(:weight).sum # rubocop:disable CodeReuse/ActiveRecord -- Enumerable#pluck
      end

      def completed_rollup_weight(issue)
        tasks = rollup_tasks(issue)

        return issue[:weight] if closed?(issue) && (tasks.empty? || none_weighted?(tasks))

        tasks.filter { |t| closed?(t) }.pluck(:weight).sum # rubocop:disable CodeReuse/ActiveRecord -- Enumerable#pluck
      end

      def rollup_tasks(issue)
        strong_memoize_with(:rollup_tasks, issue) do
          issue[:children_ids].filter_map do |id|
            item = items_by_id[id]
            item if item && item[:timebox_id] == issue[:timebox_id]
          end
        end
      end

      def issue_closed?(issue)
        tasks = rollup_tasks(issue)

        return closed?(issue) if tasks.empty?

        closed?(issue) && tasks.all? { |task| closed?(task) }
      end

      def closed?(item)
        item[:end_state] == ResourceStateEvent.states[:closed]
      end

      def none_weighted?(tasks)
        tasks.all? { |task| task[:weight] == 0 }
      end
    end
  end
end
