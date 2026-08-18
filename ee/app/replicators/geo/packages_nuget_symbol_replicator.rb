# frozen_string_literal: true

module Geo
  class PackagesNugetSymbolReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Packages::Nuget::Symbol
    end

    # @return [String] human-readable title.
    def self.replicable_title
      s_('Geo|NuGet Symbol')
    end

    # @return [String] pluralized human-readable title.
    def self.replicable_title_plural
      s_('Geo|NuGet Symbols')
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
