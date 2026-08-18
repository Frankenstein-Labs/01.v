# frozen_string_literal: true

module Mutations
  module Security
    module ScanProfiles
      module TriggerArguments
        extend ActiveSupport::Concern

        private

        def build_triggers(triggers, scan_type)
          triggers.map do |trigger|
            {
              trigger_type: trigger.trigger_type,
              configuration: configuration_for(trigger.configuration, scan_type)
            }
          end
        end

        def configuration_for(configuration_input, scan_type)
          return if configuration_input.nil?

          # ConfigurationInputType is a `one_of` input, so exactly one member is set here.
          member, value = configuration_input.to_h.first

          if member.nil? || member.to_s != scan_type
            raise ::Gitlab::Graphql::Errors::ArgumentError,
              "Configuration '#{member}' does not match scan type '#{scan_type}'"
          end

          value
        end
      end
    end
  end
end
