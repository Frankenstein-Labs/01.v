# frozen_string_literal: true

# This cron worker runs every minute
# It enqueues a job for each `ActiveContext.raw_queues` if `ActiveContext.indexing?` is true
# For each job it fetches references from the queue, processes them and removes them from the queue
# The job will re-enqueue itself until the queue is empty
# Please see ActiveContext::Concerns::BulkAsyncProcess for the details

module Ai
  module ActiveContext
    class BulkProcessWorker
      include ::ActiveContext::Concerns::BulkAsyncProcess
      include ::ApplicationWorker
      include ::CronjobQueue
      include Search::Worker
      include Gitlab::ExclusiveLeaseHelpers
      prepend ::Geo::SkipSecondary

      pause_control :active_context

      idempotent!
      worker_resource_boundary :cpu
      urgency :low
      data_consistency :sticky
      loggable_arguments 0, 1
      defer_on_database_health_signal :gitlab_main
      concurrency_limit -> { 200 }
    end
  end
end
