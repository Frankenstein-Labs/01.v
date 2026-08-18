# frozen_string_literal: true

module Geo
  class PackagesHelmMetadataCacheReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    event ::Geo::ReplicatorEvents::EVENT_UPDATED

    def self.model
      ::Packages::Helm::MetadataCache
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|Helm Metadata Cache')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|Helm Metadata Caches')
    end

    def carrierwave_uploader
      model_record.file
    end

    # Called by Gitlab::Geo::Replicator#consume
    def consume_event_updated(...)
      consume_event_created(...)
    end

    def immutable?
      false
    end
  end
end
