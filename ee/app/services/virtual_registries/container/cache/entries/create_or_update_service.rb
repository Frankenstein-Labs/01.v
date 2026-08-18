# frozen_string_literal: true

module VirtualRegistries
  module Container
    module Cache
      module Entries
        class CreateOrUpdateService < BaseCreateOrUpdateCacheEntriesService
          extend ::Gitlab::Utils::Override

          override :entry_class
          def entry_class
            ::VirtualRegistries::Container::Cache::Remote::Entry
          end

          private

          override :skip_md5?
          def skip_md5?
            true
          end

          override :existing_entry_response
          def existing_entry_response
            return unless deduplicatable_request? && existing_cache_entry_by_digest

            existing_cache_entry_by_digest.bump_downloads_count
            ServiceResponse.success(payload: { cache_entry: existing_cache_entry_by_digest })
          end

          override :customize_updates
          def customize_updates(updates)
            updates[:digest] = digest if digest.present?
          end

          def digest
            VirtualRegistries::Container.extract_digest_from_path(path) || extract_digest_from_etag(etag)
          end
          strong_memoize_attr :digest

          def extract_digest_from_etag(value)
            return if value.blank?

            value if value.match?(VirtualRegistries::Container::OCI_DIGEST_VALIDATION_REGEX)
          end

          def deduplicatable_request?
            path.include?('/blobs/') || manifest_digest_request?
          end

          def manifest_digest_request?
            path.include?('/manifests/') &&
              VirtualRegistries::Container.extract_digest_from_path(path).present?
          end

          def existing_cache_entry_by_digest
            return unless digest.present?

            ::VirtualRegistries::Container::Cache::Remote::Entry
              .default
              .for_upstream(upstream)
              .for_group(upstream.group)
              .for_digest(digest)
              .first
          end
          strong_memoize_attr :existing_cache_entry_by_digest
        end
      end
    end
  end
end
