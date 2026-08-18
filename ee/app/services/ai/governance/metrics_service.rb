# frozen_string_literal: true

module Ai
  module Governance
    class MetricsService
      EXCLUDED_DEFINITIONS = %w[chat].freeze

      def initialize(container, current_user:, timeframe:, agent_class: :all)
        @container = container
        @current_user = current_user
        @timeframe = MetricsTimeframe.new(timeframe)
        @agent_class = agent_class
      end

      def execute
        # agent_class filters on `agent_type`: INTERNAL_DAP => IS NULL,
        # EXTERNAL => IS NOT NULL, ALL => no filter. Nothing on master writes
        # `agent_type`, so EXTERNAL is structurally zero rather than merely small
        # until the external session API and its glab client hooks ship. The
        # predicate is still correct over an empty set, so no special-casing here.
        backend_class.new(
          @container,
          current_user: @current_user,
          timeframe: @timeframe,
          agent_class: @agent_class
        ).execute
      end

      private

      def backend_class
        if ::Gitlab::ClickHouse.enabled_for_analytics?(analytics_namespace)
          ClickHouseMetricsService
        else
          PostgresqlMetricsService
        end
      end

      def analytics_namespace
        @container.is_a?(Project) ? @container.project_namespace : @container
      end
    end
  end
end
