# frozen_string_literal: true

module EE
  module Organizations
    module OrganizationSetting
      extend ActiveSupport::Concern

      prepended do
        jsonb_accessor :settings,
          security_tracked_context_quota: :integer

        validates :security_tracked_context_quota,
          numericality: { only_integer: true, greater_than_or_equal_to: 1, allow_nil: true }
      end

      def security_tracked_context_quota_with_default
        return security_tracked_context_quota if security_tracked_context_quota.present?
        return unless ::Gitlab::Saas.feature_available?(:gitlab_saas_features)

        ::Gitlab::CurrentSettings.default_security_tracked_context_quota || 2
      end

      def security_tracked_context_quota_explicitly_set?
        security_tracked_context_quota.present?
      end
    end
  end
end
