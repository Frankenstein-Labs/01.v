# frozen_string_literal: true

module ClickHouse
  class CiFinishedBuildsSyncWorker
    include ApplicationWorker
    include ClickHouseWorker

    idempotent!
    data_consistency :sticky
    urgency :throttled
    sidekiq_options retry: false
    feature_category :fleet_visibility
    tags :clickhouse

    # NOTE: `_mode` is a deprecated argument kept for one release for Sidekiq
    # backward compatibility with in-flight jobs enqueued by the old mode-split
    # cron path. It is ignored and will be removed in 19.4 (see #604160).
    def perform(worker_index = 0, total_workers = 1, _mode = nil)
      response = ::ClickHouse::DataIngestion::CiFinishedBuildsSyncService.new(
        worker_index: worker_index, total_workers: total_workers
      ).execute

      result = response.success? ? response.payload : response.deconstruct_keys(%i[message reason])
      log_extra_metadata_on_done(:result, result)
    end
  end
end
