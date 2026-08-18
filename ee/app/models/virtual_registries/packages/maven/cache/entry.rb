# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      module Cache
        class Entry < ::VirtualRegistries::Cache::Entry
          include ::UpdateNamespaceStatistics

          belongs_to :upstream,
            class_name: 'VirtualRegistries::Packages::Maven::Upstream',
            optional: false

          update_namespace_statistics namespace_statistics_name: :dependency_proxy_size

          sha_attribute :file_md5

          validates :file_md5, length: { is: 32 }, allow_nil: true

          attribute :file_store, default: -> { VirtualRegistries::Cache::EntryUploader.default_store }

          def stale?
            return true unless upstream

            validity_hours = if relative_path.end_with?('maven-metadata.xml')
                               upstream.metadata_cache_validity_hours
                             else
                               upstream.cache_validity_hours
                             end

            return false if validity_hours == 0

            (upstream_checked_at + validity_hours.hours).past?
          end
        end
      end
    end
  end
end
