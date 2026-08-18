# frozen_string_literal: true

module Security
  module ScanProfiles
    class Configuration < ::SecApplicationRecord
      self.table_name = 'security_scan_profile_configurations'

      DEFAULTS_BY_TYPE = {
        dependency_scanning_post_processing:
          Defaults::DependencyScanningPostProcessing::VALUES
      }.freeze

      # Anything not listed here is validated against EMPTY_CONFIGURATION_SCHEMA (no keys allowed).
      SCHEMA_BY_SCAN_TYPE = {
        dependency_scanning_post_processing: 'security_profile_dependency_scanning_post_processing_configuration',
        secret_detection: 'security_profile_secret_detection_configuration'
      }.freeze

      EMPTY_CONFIGURATION_SCHEMA = 'security_profile_scan_configuration'

      belongs_to :scan_profile, class_name: 'Security::ScanProfile',
        foreign_key: :security_scan_profile_id, inverse_of: :configurations, optional: false
      belongs_to :namespace, optional: false
      has_many :scan_profile_triggers, class_name: 'Security::ScanProfileTrigger',
        foreign_key: :security_scan_profile_configuration_id, inverse_of: :configuration

      delegate :scan_type, to: :scan_profile, allow_nil: true

      validates :configuration, json_schema: {
        filename: EMPTY_CONFIGURATION_SCHEMA,
        size_limit: 64.kilobytes,
        detail_errors: true
      }, unless: :type_specific_schema?
      validate :validate_type_specific_configuration, if: :type_specific_schema?

      def self.defaults_for(scan_type)
        return {} if scan_type.blank?

        DEFAULTS_BY_TYPE.fetch(scan_type.to_sym, {})
      end

      def self.strip_defaults(values, defaults)
        values.to_h.deep_symbolize_keys.each_with_object({}) do |(key, value), result|
          default = defaults[key]

          if value.is_a?(Hash) && default.is_a?(Hash)
            nested = strip_defaults(value, default)
            result[key] = nested unless nested.empty?
          elsif value != default
            result[key] = value
          end
        end
      end

      def self.effective_for(profile, trigger, project: nil)
        return {} unless profile

        config = defaults_for(profile.scan_type)
                   .deep_merge((trigger&.configuration&.configuration || {}).deep_symbolize_keys)

        config = apply_duo_overrides(config, project) if profile.post_processing? && project

        config
      end

      def self.apply_duo_overrides(config, project)
        return config unless resolve_dependency_bump_enabled?(project)

        auto_remediation = (config[:auto_remediation] || {}).merge(upgrade_policy: 'major')
        config.merge(auto_remediation: auto_remediation)
      end
      private_class_method :apply_duo_overrides

      def self.resolve_dependency_bump_enabled?(project)
        return false unless project

        project.duo_dependency_bump_breaking_changes_available?
      end
      private_class_method :resolve_dependency_bump_enabled?

      private

      def type_specific_schema?
        SCHEMA_BY_SCAN_TYPE.key?(scan_type&.to_sym)
      end

      def validate_type_specific_configuration
        JsonSchemaValidator.new(
          attributes: :configuration,
          filename: SCHEMA_BY_SCAN_TYPE.fetch(scan_type.to_sym),
          size_limit: 64.kilobytes,
          detail_errors: true
        ).validate(self)
      end
    end
  end
end
