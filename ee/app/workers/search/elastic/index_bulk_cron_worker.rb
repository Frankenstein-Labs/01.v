# frozen_string_literal: true

module Search
  module Elastic
    class IndexBulkCronWorker # rubocop:disable Scalability/IdempotentWorker -- cron worker
      include ::Elastic::BulkCronWorker

      worker_resource_boundary :cpu
      urgency :low
      defer_on_database_health_signal :gitlab_main
      # Must read from primary: refs are queued via Redis (no Sidekiq LSN), so `:sticky` reads
      # from lagged replicas and indexes stale rows.
      data_consistency :always

      private

      def service
        ::Elastic::ProcessBookkeepingService.new
      end
    end
  end
end
