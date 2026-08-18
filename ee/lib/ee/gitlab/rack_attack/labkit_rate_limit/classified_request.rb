# frozen_string_literal: true

module EE
  module Gitlab
    module RackAttack
      module LabkitRateLimit
        # Adds the EE-only facts to ClassifiedRequest:
        #   - setting_incident_management_notification: the incident throttle's enable
        #     setting (its match is otherwise all CE facts: the alerts/notify path).
        #   - verified_geo_request: the geo-JWT skips (verified_geo_request? and
        #     geo_proxy_workhorse_request?), the parts of EE's should_be_skipped? that
        #     verify a JWT and so cannot be a path matcher. Lives here, not in CE,
        #     because those predicates are EE-only - referencing them from CE would
        #     raise under FOSS.
        module ClassifiedRequest
          extend ::Gitlab::Utils::Override

          private

          # Extends the classification facts (not labkit_facts) so the strict-boolean
          # coercion in Gitlab::RackAttack::LabkitRateLimit::ClassifiedRequest#labkit_facts
          # applies to these facts too.
          override :classification_facts
          def classification_facts
            super.merge(
              setting_incident_management_notification:
                ::Gitlab::Throttle.settings.throttle_incident_management_notification_enabled,
              verified_geo_request: verified_geo_request? || geo_proxy_workhorse_request?
            )
          end
        end
      end
    end
  end
end
