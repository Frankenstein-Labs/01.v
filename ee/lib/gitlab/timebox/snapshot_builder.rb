# frozen_string_literal: true

module Gitlab
  module Timebox
    # SnapshotBuilder can build snapshots (`Gitlab::Timebox::Snapshot`s) of issues and tasks for a timebox.
    # As of March 2024, SnapshotBuilder was designed to work with issues and tasks, not generally with work items.
    #
    # The `issues` table only captures the latest state of an issue/task.
    # SnapshotBuilder can reconstruct the ending states of issues and tasks
    #  assigned to a timebox using resource events records (e.g., ResourceStateEvent) for each date in the timebox.
    #
    # Example. Given some timebox, say Milestone A (starts on date N and ends on date N + 2),
    # SnapshotBuilder can reconstruct the end states of the issues/tasks assigned to the timebox on each date.
    #
    #   Snapshot on Date N:
    #     Issue 1 was open (open => open) and assigned to Milestone A.
    #
    #   Snapshot on Date N+1:
    #     Issue 1 got closed (open => closed) and still assigned to Milestone A.
    #       Task 1 was added to Issue 1
    #
    #   Snapshot on Date N+2:
    #     Issue 1 got reopened (closed => reopened).
    #       Task 1 was removed from Issue 1
    #     Issue 2 was added to Milestone A
    #
    class SnapshotBuilder
      ArgumentError = Class.new(StandardError)
      FieldsError = Class.new(StandardError)
      UnsupportedTimeboxError = Class.new(StandardError)

      REQUIRED_RESOURCE_EVENT_FIELDS = %w[id event_type issue_id value action created_at].freeze

      # @params timebox [Milestone, Iteration] the timebox of interest
      # @params resource_events [PG::Result] the query result for resource events.
      #   Resource event models must select the correct columns
      #   using the scope "aliased_for_timebox_report" and ordered by creation date.
      def initialize(timebox, resource_events)
        @resource_events = resource_events
        @timebox = timebox
        @item_states = {}
      end

      # @return [Array<Snapshot>] An array of snapshots.
      #                           Each snapshot captures the end states of issues and tasks for the timebox on a date.
      def build
        check_arguments!

        @snapshots = []

        return @snapshots if @resource_events.ntuples < 1

        cursor = 0

        timebox_date_range.each do |snapshot_date|
          next_date = snapshot_date + 1.day

          # Events are ordered by created_at, so a single forward cursor suffices.
          while cursor < @resource_events.ntuples && (event = @resource_events[cursor])['created_at'] < next_date
            apply_event(event)
            cursor += 1
          end

          take_snapshot(snapshot_date: snapshot_date)
        end

        @snapshots
      end

      private

      attr_reader :timebox, :item_states

      def check_arguments!
        raise ArgumentError unless timebox.is_a?(Milestone) || timebox.is_a?(Iteration)
        raise UnsupportedTimeboxError if timebox.start_date.blank? || timebox.due_date.blank?
        raise ArgumentError unless @resource_events.is_a? PG::Result
        raise FieldsError unless valid_resource_event_columns?
      end

      def valid_resource_event_columns?
        REQUIRED_RESOURCE_EVENT_FIELDS
          .map { |column| @resource_events.fields.include? column }
          .all? true
      end

      def timebox_date_range
        due_date = [
          [Date.current, timebox.due_date].compact.min,
          timebox.start_date
        ].compact.max

        timebox.start_date..due_date
      end

      def take_snapshot(snapshot_date:)
        snapshot = Snapshot.new(date: snapshot_date)

        item_states.each do |id, item|
          snapshot.add_item(
            item_id: id,
            timebox_id: item[:timebox],
            start_state: item[:prev_end_state] || ResourceStateEvent.states[:opened],
            end_state: item[:state],
            parent_id: item[:parent_id],
            children_ids: Set.new(item[:children_ids]),
            weight: item[:weight]
          )

          # This snapshot's end_state becomes the next snapshot's start_state.
          item[:prev_end_state] = item[:state]
        end

        @snapshots.push(snapshot)
      end

      def apply_event(event)
        case event['event_type']
        when ::Timebox::EventAggregationService::EVENT_TYPE[:timebox]
          handle_resource_timebox_event(event)
        when ::Timebox::EventAggregationService::EVENT_TYPE[:state]
          handle_state_event(event)
        when ::Timebox::EventAggregationService::EVENT_TYPE[:weight]
          handle_weight_event(event)
        when ::Timebox::EventAggregationService::EVENT_TYPE[:link]
          handle_resource_link_event(event)
        end
      end

      def handle_resource_timebox_event(event)
        item_state = find_or_build_state(event['issue_id'])

        is_add_event = event['action'] == ResourceTimeboxEvent.actions[:add]
        target_timebox_id = event['value']

        return if item_state[:timebox] == timebox.id && is_add_event && target_timebox_id == timebox.id

        item_state[:timebox] = is_add_event ? target_timebox_id : nil

        # If the issue is currently assigned to the timebox(milestone or iteration),
        # then treat any event here as a removal.
        # We do not have a separate `:remove` event when replacing timebox(milestone or iteration) with another one.
        item_state[:timebox] = target_timebox_id if item_state[:timebox] == timebox.id
      end

      def handle_state_event(event)
        item_state = find_or_build_state(event['issue_id'])
        item_state[:state] = event['value']
      end

      def handle_weight_event(event)
        item_state = find_or_build_state(event['issue_id'])
        item_state[:weight] = event['value'] || 0
      end

      def handle_resource_link_event(event)
        child_id = event['value']
        parent_id = event['issue_id']
        child = find_or_build_state(child_id)
        parent = find_or_build_state(parent_id)

        case event['action']
        when ::WorkItems::ResourceLinkEvent.actions[:add]
          child[:parent_id] = parent_id
          parent[:children_ids] << child_id
        when ::WorkItems::ResourceLinkEvent.actions[:remove]
          parent[:children_ids].delete(child_id)
          child[:parent_id] = nil
        end
      end

      def find_or_build_state(issue_id)
        item_states[issue_id] ||= {
          timebox: nil,
          weight: 0,
          state: ResourceStateEvent.states[:opened],
          prev_end_state: nil,
          parent_id: nil,
          children_ids: Set.new
        }
      end
    end
  end
end
