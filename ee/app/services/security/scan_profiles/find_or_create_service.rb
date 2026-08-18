# frozen_string_literal: true

module Security
  module ScanProfiles
    class FindOrCreateService
      UNIQUE_INDEX = :index_security_scan_profiles_unique_name_not_deleted

      def self.execute(...)
        new(...).execute
      end

      def initialize(namespace:, identifier:)
        @namespace = namespace
        @identifier = identifier.to_s
      end

      def execute
        return error_response('Namespace must be a root namespace') unless namespace.root?

        profile = find_or_create_profile
        return error_response('Could not find a default scan profile for this type') unless profile

        success_response(profile)
      rescue ActiveRecord::StatementInvalid => e
        error_response("Failed to create scan profile: #{e.message}")
      end

      private

      attr_reader :namespace, :identifier

      def find_or_create_profile
        if Enums::Security.security_profile_types.key?(identifier.to_sym)
          find_or_create_default_profile
        else
          ::Security::ScanProfile.not_deleted.by_namespace(namespace).id_in(identifier).first
        end
      end

      def find_or_create_default_profile
        default_profile = Security::DefaultScanProfiles.find_by_scan_type(identifier)
        return unless default_profile
        return if default_profile.post_processing? && Feature.disabled?(:security_remediation_profiles, namespace)

        Security::ScanProfile.transaction do
          upsert_profile(default_profile)
          profile = fetch_profile_by_scan_type_identifier
          upsert_triggers(profile, default_profile)
          profile.reset
        end
      end

      def upsert_profile(default_profile)
        Security::ScanProfile.upsert(
          {
            namespace_id: namespace.id,
            gitlab_recommended: true,
            scan_type: default_profile.scan_type,
            name: default_profile.name,
            description: default_profile.description
          },
          # The partial unique index covers (namespace_id, scan_type, lower(name)) WHERE
          # deleted_at IS NULL; Rails includes that predicate in the ON CONFLICT target. Inserts
          # always set deleted_at to NULL, so conflicts resolve against it.
          unique_by: UNIQUE_INDEX
        )
      end

      def fetch_profile_by_scan_type_identifier
        Security::ScanProfile.by_namespace(namespace).by_type(identifier).by_gitlab_recommended.first
      end

      def upsert_triggers(profile, default_profile)
        return if default_profile.scan_profile_triggers.empty?

        trigger_attrs = default_profile.scan_profile_triggers.map do |trigger|
          {
            security_scan_profile_id: profile.id,
            trigger_type: trigger.trigger_type,
            namespace_id: namespace.id
          }
        end

        ScanProfileTrigger.insert_all(trigger_attrs, unique_by: [:security_scan_profile_id, :trigger_type])
      end

      def success_response(profile)
        ServiceResponse.success(payload: { scan_profile: profile })
      end

      def error_response(message)
        ServiceResponse.error(message: message)
      end
    end
  end
end
