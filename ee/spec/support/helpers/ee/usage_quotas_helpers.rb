# frozen_string_literal: true

module EE
  module UsageQuotasHelpers
    include NamespacesHelper
    include SubscriptionPortalHelpers

    def buy_minutes_subscriptions_link(group)
      buy_additional_minutes_path(group)
    end

    def setup_usage_quotas_env(namespace_id)
      stub_signing_key
      stub_subscription_permissions_data(namespace_id)
    end
  end
end
