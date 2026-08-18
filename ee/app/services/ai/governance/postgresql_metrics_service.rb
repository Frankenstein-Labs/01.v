# frozen_string_literal: true

module Ai
  module Governance
    class PostgresqlMetricsService
      def initialize(container, current_user:, timeframe:, agent_class: :all)
        @container = container
        @current_user = current_user
        @timeframe = timeframe
        @agent_class = agent_class
      end

      def execute
        sessions_count, sessions_previous, agents_count, agents_previous =
          windowed_scope.count_current_and_previous(timeframe.from)

        buckets = current_window.counts_by_created_at_bucket(hourly: timeframe.hourly?)

        ServiceResponse.success(payload: {
          sessions: kpi(sessions_count, sessions_previous, buckets, :sessions),
          agents: kpi(agents_count, agents_previous, buckets, :agents)
        })
      end

      private

      attr_reader :container, :current_user, :timeframe, :agent_class

      def base_scope
        scope = if container.is_a?(Project)
                  Ai::DuoWorkflows::Workflow.for_project(container)
                else
                  Ai::DuoWorkflows::Workflow.in_namespace_hierarchy(container)
                end

        scope
          .without_workflow_definition(MetricsService::EXCLUDED_DEFINITIONS)
          .for_agent_class(agent_class)
      end

      # Spans both windows so one aggregate can split the totals at timeframe.from.
      def windowed_scope
        base_scope.created_between(timeframe.previous_from, timeframe.to)
      end

      def current_window
        base_scope.created_between(timeframe.from, timeframe.to)
      end

      def kpi(count, previous_count, buckets, metric)
        {
          count: count.to_i,
          previous_count: previous_count.to_i,
          trend: zero_filled_trend(buckets, metric)
        }
      end

      def zero_filled_trend(buckets, metric)
        timeframe.bucket_starts.map do |bucket_start|
          { bucket_start: bucket_start, count: buckets.dig(bucket_start, metric).to_i }
        end
      end
    end
  end
end
