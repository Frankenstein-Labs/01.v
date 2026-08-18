# frozen_string_literal: true

module Ai
  module ActiveContext
    class DisableWorker
      include ::ApplicationWorker
      prepend ::Geo::SkipSecondary

      idempotent!
      worker_resource_boundary :cpu
      urgency :low
      data_consistency :sticky
      feature_category :global_search
      defer_on_database_health_signal :gitlab_main, [:ai_active_context_connections], 10.minutes

      def perform
        connection = ::ActiveContext.adapter&.connection

        return false unless connection

        connection.deactivate!
      end
    end
  end
end
