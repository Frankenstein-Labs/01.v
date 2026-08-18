# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module FixIncompleteInstanceExternalAuditDestinationsV2
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class InstanceExternalAuditEventDestination < ::ApplicationRecord
          include ::Gitlab::EncryptedAttribute

          self.table_name = 'audit_events_instance_external_audit_event_destinations'

          attr_accessor :verification_token

          attr_encrypted :verification_token,
            mode: :per_attribute_iv,
            algorithm: 'aes-256-gcm',
            key: :db_key_base_32,
            encode: false,
            encode_iv: false
        end

        class LegacyInstanceHeader < ::ApplicationRecord
          self.table_name = 'instance_audit_events_streaming_headers'
        end

        class LegacyInstanceEventTypeFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_instance_event_type_filters'
        end

        class LegacyInstanceNamespaceFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_http_instance_namespace_filters'
        end

        class InstanceStreamingDestination < ::ApplicationRecord
          include ::Gitlab::EncryptedAttribute

          self.table_name = 'audit_events_instance_external_streaming_destinations'
          enum :category, { http: 0, gcp: 1, aws: 2 }

          attr_accessor :secret_token

          attr_encrypted :secret_token,
            mode: :per_attribute_iv,
            key: :db_key_base_32,
            algorithm: 'aes-256-gcm',
            encode: false,
            encode_iv: false
        end

        class InstanceEventTypeFilter < ::ApplicationRecord
          self.table_name = 'audit_events_instance_streaming_event_type_filters'
        end

        class InstanceNamespaceFilter < ::ApplicationRecord
          self.table_name = 'audit_events_streaming_instance_namespace_filters'
        end

        prepended do
          operation_name :fix_instance_external_audit_destinations_v2
          feature_category :audit_events

          scope_to ->(relation) { relation }
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            process_batch(sub_batch)
          end
        end

        private

        def process_batch(sub_batch)
          sub_batch.each do |legacy_destination|
            process_legacy_destination(legacy_destination)
          rescue StandardError => e
            ::Gitlab::ErrorTracking.track_exception(
              e,
              legacy_destination_id: legacy_destination.id
            )
          end
        end

        def process_legacy_destination(legacy_destination)
          ::ApplicationRecord.transaction do
            if legacy_destination.stream_destination_id.present?
              sync_migrated_record(legacy_destination)
            else
              migrate_new_record(legacy_destination)
            end
          end
        end

        def sync_migrated_record(legacy_destination)
          destination = InstanceStreamingDestination.find_by(id: legacy_destination.stream_destination_id)
          return unless destination

          sync_custom_headers(legacy_destination, destination)
          sync_event_type_filters(legacy_destination, destination)
          sync_namespace_filters(legacy_destination, destination)
        end

        def migrate_new_record(legacy_destination)
          token = decrypt_verification_token(legacy_destination) || SecureRandom.base58(18)

          destination = find_or_create_instance_streaming_destination(legacy_destination, token)
          return unless destination

          legacy_destination.update_column(:stream_destination_id, destination.id)

          migrate_event_type_filters(legacy_destination, destination)
          migrate_namespace_filters(legacy_destination, destination)

          destination
        end

        def find_or_create_instance_streaming_destination(legacy_destination, token)
          destination = InstanceStreamingDestination.find_by(
            category: :http,
            name: legacy_destination.name
          )

          return destination if destination

          InstanceStreamingDestination.find_or_create_by!(
            category: :http,
            name: legacy_destination.name
          ) do |dest|
            dest.config = build_config(legacy_destination, token)
            dest.legacy_destination_ref = legacy_destination.id
            dest.secret_token = token
            dest.created_at = legacy_destination.created_at
            dest.updated_at = legacy_destination.updated_at
          end
        rescue ActiveRecord::RecordNotUnique
          InstanceStreamingDestination.find_by(
            category: :http,
            name: legacy_destination.name
          )
        end

        def decrypt_verification_token(legacy_destination)
          return unless legacy_destination.encrypted_verification_token.present? &&
            legacy_destination.encrypted_verification_token_iv.present?

          return if legacy_destination.encrypted_verification_token.bytesize < 16

          ::Gitlab::CryptoHelper.aes256_gcm_decrypt(
            legacy_destination.encrypted_verification_token,
            nonce: legacy_destination.encrypted_verification_token_iv
          )
        rescue OpenSSL::Cipher::CipherError, TypeError, ArgumentError, StandardError
          nil
        end

        def build_config(legacy_destination, token)
          headers = LegacyInstanceHeader.where(
            instance_external_audit_event_destination_id: legacy_destination.id
          ).pluck(:key, :value, :active)

          header_config = {
            'X-Gitlab-Event-Streaming-Token' => {
              'value' => token,
              'active' => true
            }
          }

          headers.each do |key, value, active|
            header_config[key] = {
              'value' => value,
              'active' => active
            }
          end

          {
            'url' => legacy_destination.destination_url,
            'headers' => header_config
          }
        end

        def sync_custom_headers(legacy_destination, destination)
          headers = LegacyInstanceHeader.where(
            instance_external_audit_event_destination_id: legacy_destination.id
          ).pluck(:key, :value, :active)

          return if headers.empty?

          update_destination_headers(legacy_destination, destination, headers)
        rescue ActiveRecord::StaleObjectError
          destination = InstanceStreamingDestination.find(destination.id)
          update_destination_headers(legacy_destination, destination, headers)
        end

        def update_destination_headers(legacy_destination, destination, headers)
          config = destination.config.deep_dup
          config['headers'] ||= {}

          token = decrypt_verification_token(legacy_destination)
          if token.present? && !config['headers'].key?('X-Gitlab-Event-Streaming-Token')
            config['headers']['X-Gitlab-Event-Streaming-Token'] = {
              'value' => token,
              'active' => true
            }
          end

          headers.each do |key, value, active|
            next if config['headers'].key?(key)

            config['headers'][key] = {
              'value' => value,
              'active' => active
            }
          end

          destination.update!(config: config)
        end

        def sync_event_type_filters(legacy_destination, destination)
          legacy_filters = LegacyInstanceEventTypeFilter
                          .where(instance_external_audit_event_destination_id: legacy_destination.id)
                          .pluck(:audit_event_type, :created_at, :updated_at)

          return if legacy_filters.empty?

          existing_types = InstanceEventTypeFilter
                            .where(external_streaming_destination_id: destination.id)
                            .pluck(:audit_event_type)
                            .to_set

          missing_filters = legacy_filters.reject { |type, _, _| existing_types.include?(type) }

          return if missing_filters.empty?

          attributes = missing_filters.map do |audit_event_type, created_at, updated_at|
            {
              audit_event_type: audit_event_type,
              created_at: created_at,
              updated_at: updated_at,
              external_streaming_destination_id: destination.id
            }
          end

          InstanceEventTypeFilter.insert_all(
            attributes,
            unique_by: [:external_streaming_destination_id, :audit_event_type]
          )
        end

        def migrate_event_type_filters(legacy_destination, destination)
          filters = LegacyInstanceEventTypeFilter.where(
            instance_external_audit_event_destination_id: legacy_destination.id
          ).pluck(:audit_event_type, :created_at, :updated_at)

          return if filters.empty?

          attributes = filters.map do |audit_event_type, created_at, updated_at|
            {
              audit_event_type: audit_event_type,
              created_at: created_at,
              updated_at: updated_at,
              external_streaming_destination_id: destination.id
            }
          end

          InstanceEventTypeFilter.insert_all(
            attributes,
            unique_by: [:external_streaming_destination_id, :audit_event_type]
          )
        end

        def sync_namespace_filters(legacy_destination, destination)
          legacy_filters = LegacyInstanceNamespaceFilter
                            .where(audit_events_instance_external_audit_event_destination_id: legacy_destination.id)
                            .pluck(:namespace_id, :created_at, :updated_at)

          return if legacy_filters.empty?

          existing_namespace_ids = InstanceNamespaceFilter
                                    .where(external_streaming_destination_id: destination.id)
                                    .pluck(:namespace_id)
                                    .to_set

          missing_filters = legacy_filters.reject { |namespace_id, _, _| existing_namespace_ids.include?(namespace_id) }

          return if missing_filters.empty?

          attributes = missing_filters.map do |namespace_id, created_at, updated_at|
            {
              namespace_id: namespace_id,
              external_streaming_destination_id: destination.id,
              created_at: created_at,
              updated_at: updated_at
            }
          end

          InstanceNamespaceFilter.insert_all(
            attributes,
            unique_by: [:external_streaming_destination_id, :namespace_id]
          )
        end

        def migrate_namespace_filters(legacy_destination, destination)
          filters = LegacyInstanceNamespaceFilter.where(
            audit_events_instance_external_audit_event_destination_id: legacy_destination.id
          ).pluck(:namespace_id, :created_at, :updated_at)

          return if filters.empty?

          attributes = filters.map do |namespace_id, created_at, updated_at|
            {
              namespace_id: namespace_id,
              external_streaming_destination_id: destination.id,
              created_at: created_at,
              updated_at: updated_at
            }
          end

          InstanceNamespaceFilter.insert_all(
            attributes,
            unique_by: [:external_streaming_destination_id, :namespace_id]
          )
        end
      end
    end
  end
end
