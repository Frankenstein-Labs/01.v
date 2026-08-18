# frozen_string_literal: true

module EE
  module InstanceConfiguration # rubocop:disable Gitlab/BoundedContexts -- class that we are extending is not namespaced
    extend ::Gitlab::Utils::Override

    private

    override :configuration
    def configuration
      super.merge(ai_gateway_url: ::Gitlab::AiGateway.url)
    end

    override :rate_limits
    def rate_limits
      super.merge(
        incident_management_notification: {
          enabled: application_settings[:throttle_incident_management_notification_enabled],
          requests_per_period: application_settings[:throttle_incident_management_notification_per_period],
          period_in_seconds: application_settings[:throttle_incident_management_notification_period_in_seconds]
        }
      )
    end
  end
end
