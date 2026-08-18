# frozen_string_literal: true

module Security
  module ScanProfiles
    class Configuration
      module CiVariables
        SERIALIZERS = {
          boolean: ->(value) { value ? 'true' : 'false' },
          string: ->(value) { value.to_s },
          comma_separated_strings: ->(value) { Array(value).join(',') }
        }.freeze

        # rubocop:disable Layout/HashAlignment -- aligned as a table for readability
        MAPPINGS = {
          secret_detection: {
            secure_analyzers_prefix: { env: 'SECURE_ANALYZERS_PREFIX',                type: :string },
            image_suffix:            { env: 'SECRET_DETECTION_IMAGE_SUFFIX',          type: :string },
            historic_scan:           { env: 'SECRET_DETECTION_HISTORIC_SCAN',         type: :boolean },
            log_options:             { env: 'SECRET_DETECTION_LOG_OPTIONS',           type: :string },
            excluded_paths:          { env: 'SECRET_DETECTION_EXCLUDED_PATHS',        type: :comma_separated_strings },
            ruleset_git_reference:   { env: 'SECRET_DETECTION_RULESET_GIT_REFERENCE', type: :string }
          }
        }.freeze
        # rubocop:enable Layout/HashAlignment

        def self.build(scan_type, config)
          symbolized = config.to_h.deep_symbolize_keys

          MAPPINGS.fetch(scan_type&.to_sym, {}).each_with_object({}) do |(key, definition), variables|
            next if symbolized[key].nil?

            variables[definition[:env]] = SERIALIZERS.fetch(definition[:type]).call(symbolized[key])
          end
        end
      end
    end
  end
end
