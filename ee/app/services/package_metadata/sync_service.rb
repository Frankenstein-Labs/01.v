# frozen_string_literal: true

module PackageMetadata
  class SyncService
    UnknownAdapterError = Class.new(StandardError)
    MAX_LEASE_LENGTH = 6.minutes
    MAX_SYNC_DURATION = 4.minutes
    INGEST_SLICE_SIZE = 200
    THROTTLE_RATE = 0.75.seconds

    def self.execute(data_type:, lease:)
      signal = PackageMetadata::StopSignal.new(lease, MAX_LEASE_LENGTH, MAX_SYNC_DURATION)
      SyncConfiguration.configs_for(data_type).each do |sync_config|
        if signal.stop?
          break Gitlab::AppJsonLogger.debug(class: name,
            message: "Stop signal before sync of #{sync_config}")
        end

        new(sync_config, signal).execute
      end
    end

    def initialize(sync_config, signal)
      @sync_config = sync_config
      @signal = signal
    end

    def execute
      full_sync = full_dataset_sync?

      connector.data_after(checkpoint).each do |file|
        Gitlab::AppJsonLogger.debug(class: self.class.name, message: "Evaluating data for #{sync_config}/#{file}")

        ingest_file(file)
        checkpoint.update(**checkpoint_position(file, full_sync))

        return log_stop_signal if signal.stop?
      end

      # The loop drained without a stop signal, so the full dataset is ingested.
      finalize_full_sync if full_sync
    end

    private

    # The malware connectors pull the whole /all snapshot while first_sync?
    # holds. Pinning full_sync_target_sequence on the first shard keeps
    # first_sync? true for the entire first sync, so an interrupted run resumes
    # the snapshot instead of flipping to /delta and dropping the remaining
    # shards; the marker is cleared once the dataset finishes ingesting. Only the
    # malware connectors use the marker; other data types leave it nil.
    # https://gitlab.com/gitlab-org/gitlab/-/work_items/603628
    def full_dataset_sync?
      sync_config.malware_advisories? && checkpoint.first_sync?
    end

    def checkpoint_position(file, full_sync)
      position = { sequence: file.sequence, chunk: file.chunk }
      position[:full_sync_target_sequence] = file.sequence if full_sync && checkpoint.full_sync_target_sequence.nil?
      position
    end

    def finalize_full_sync
      return if checkpoint.full_sync_target_sequence.nil?

      checkpoint.update(full_sync_target_sequence: nil)
    end

    def ingest_file(file)
      DataObjectFabricator.new(data_file: file, sync_config: sync_config)
        .each_slice(INGEST_SLICE_SIZE) do |data_objects|
          ingest(data_objects)
          throttle
        end
    end

    def log_stop_signal
      Gitlab::AppJsonLogger.debug(class: self.class.name,
        message: "Stop signal after checkpointing")
    end

    attr_accessor :sync_config, :signal

    def ingest(data)
      if sync_config.cve_enrichment?
        PackageMetadata::Ingestion::CveEnrichment::IngestionService.execute(data)
      elsif sync_config.advisories?
        PackageMetadata::Ingestion::Advisory::IngestionService.execute(data)
      elsif sync_config.v2?
        PackageMetadata::Ingestion::CompressedPackage::IngestionService.execute(data)
      else
        PackageMetadata::Ingestion::IngestionService.execute(data)
      end
    end

    def checkpoint
      if sync_config.cve_enrichment?
        @checkpoint ||= PackageMetadata::NullCheckpoint.new
      else
        @checkpoint ||= PackageMetadata::Checkpoint
          .with_path_components(sync_config.data_type, sync_config.version_format, sync_config.purl_type)
      end
    end

    def connector
      @connector ||= case sync_config.storage_type
                     when :gcp
                       Gitlab::PackageMetadata::Connector::Gcp.new(sync_config)
                     when :pds
                       Gitlab::PackageMetadata::Connector::MalwarePds.new(sync_config)
                     when :offline
                       offline_connector
                     else
                       raise UnknownAdapterError, "unable to find '#{sync_config.storage_type}' connector"
                     end
    end

    def offline_connector
      if sync_config.malware_advisories?
        Gitlab::PackageMetadata::Connector::MalwareOffline.new(sync_config)
      else
        Gitlab::PackageMetadata::Connector::Offline.new(sync_config)
      end
    end

    def throttle
      return if ENV['PM_SYNC_IN_DEV'] == 'true'

      sleep(THROTTLE_RATE)
    end
  end
end

# Added for JiHu
# Used in https://jihulab.com/gitlab-cn/gitlab/-/blob/main-jh/jh/app/services/jh/package_metadata/sync_service.rb
PackageMetadata::SyncService.prepend_mod
