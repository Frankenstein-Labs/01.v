# frozen_string_literal: true

module Elastic
  class MetricsUpdateService
    def execute
      incremental_gauge = Gitlab::Metrics.gauge(:search_advanced_bulk_cron_queue_size, 'Number of incremental database updates waiting to be synchronized to Elasticsearch', {}, :max)
      incremental_gauge.set({}, ::Elastic::ProcessBookkeepingService.queue_size)

      initial_gauge = Gitlab::Metrics.gauge(:search_advanced_bulk_cron_initial_queue_size, 'Number of initial database updates waiting to be synchronized to Elasticsearch', {}, :max)
      initial_gauge.set({}, ::Elastic::ProcessInitialBookkeepingService.queue_size)

      dead_gauge = Gitlab::Metrics.gauge(:search_advanced_bulk_cron_dead_queue_size, 'Number of failed items in the dead queue requiring manual intervention', {}, :max)
      dead_gauge.set({}, ::Search::Elastic::DeadQueue.queue_size)
    end
  end
end
