# frozen_string_literal: true

module Types
  module Security
    module ScanProfiles
      class ConfigurationType < BaseUnion
        graphql_name 'ScanProfileConfiguration'
        description 'Effective configuration for a scan profile trigger, resolved by scan type.'

        possible_types ::Types::Security::ScanProfiles::AutoRemediationConfigurationType,
          ::Types::Security::ScanProfiles::SecretDetectionConfigurationType

        # Authorization happens at the parent level (ScanProfileType); each possible type skips
        # granular-token auth for the same reason, so the union authorizes unconditionally.
        # This override is also required because GitLab's BaseUnion.authorized? delegates to
        # `resolve_type(...).authorized?`, which would break on the `[type, value]` tuple below.
        def self.authorized?(_object, _context)
          true
        end

        # `object` is a Security::ScanProfileTrigger. The effective configuration is the scan-type
        # defaults deep-merged with the trigger's stored overrides. Both the concrete type and the
        # value it reads from are selected by the profile's scan type; scan types without a typed
        # configuration resolve to `nil`, so the field is `null`.
        #
        # When the query is scoped to a project (see ProjectType#security_scan_profiles), the project
        # is threaded through so project-specific overrides (e.g. the Duo dependency-bump upgrade
        # policy) are reflected; at group level no single project applies, so it is nil.
        def self.resolve_type(object, context)
          effective = ::Security::ScanProfiles::Configuration.effective_for(
            object.scan_profile, object, project: context[:scan_profile_project]
          )

          case object.scan_profile.scan_type&.to_sym
          when :dependency_scanning_post_processing
            [AutoRemediationConfigurationType, effective[:auto_remediation]]
          when :secret_detection
            [SecretDetectionConfigurationType, effective]
          end
        end
      end
    end
  end
end
