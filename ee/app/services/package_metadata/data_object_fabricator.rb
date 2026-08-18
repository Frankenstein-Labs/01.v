# frozen_string_literal: true

module PackageMetadata
  class DataObjectFabricator
    include Enumerable

    def initialize(data_file:, sync_config:)
      @data_file = data_file
      @sync_config = sync_config
    end

    def each
      data_file.each do |data|
        obj = create_object(data)
        yield obj unless obj.nil?
      end
    end

    private

    attr_reader :data_file, :sync_config

    def create_object(data)
      data_object_class.create(data, sync_config.purl_type)
    rescue ArgumentError => e
      Gitlab::ErrorTracking.track_exception(e, data: data)
      nil
    end

    def data_object_class
      if sync_config.cve_enrichment?
        DataObjects::CveEnrichment
      elsif sync_config.advisories?
        AdvisoryDataObject
      elsif sync_config.v2?
        v2_license_data_object_class
      else
        v1_license_data_object_class
      end
    end

    def v2_license_data_object_class
      CompressedPackageDataObject
    end

    def v1_license_data_object_class
      DataObject
    end
  end
end
