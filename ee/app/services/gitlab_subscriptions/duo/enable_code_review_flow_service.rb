# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    class EnableCodeReviewFlowService
      def initialize(namespace:)
        @namespace = namespace
        @namespace_settings = namespace.namespace_settings
      end

      def execute
        return cannot_enable_code_review_error unless namespace_eligible?

        if should_enable_code_review_flow?
          seed_foundational_flows
          enable_code_review_flow
        else
          ServiceResponse.success
        end
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e, namespace_id: namespace.id)
        ServiceResponse.error(message: e.message)
      end

      private

      attr_reader :namespace, :namespace_settings

      def cannot_enable_code_review_error
        ServiceResponse.error(
          message: s_('GitlabSubscriptions|Cannot enable the Code Review flow for this namespace'),
          reason: :cannot_enable_code_review_error
        )
      end

      def namespace_eligible?
        namespace.root? &&
          namespace.duo_features_enabled &&
          namespace.duo_agent_platform_enabled &&
          namespace.duo_foundational_flows_enabled
      end

      def should_enable_code_review_flow?
        namespace_settings.enable_duo_code_review_by_default_pending?
      end

      def enable_code_review_flow
        ::Ai::CascadeDuoSettingsService.new(settings_payload).cascade_for_group(namespace)

        namespace_settings.enable_duo_code_review_by_default_enabled!

        ServiceResponse.success
      rescue ActiveRecord::RecordInvalid => e
        ::Gitlab::ErrorTracking.track_exception(e, namespace_id: namespace.id)
        ServiceResponse.error(message: e.message)
      end

      def seed_foundational_flows
        Ai::Catalog::Flows::SeedFoundationalFlowsService.new(
          organization: namespace.organization
        ).execute
      end

      def settings_payload
        {
          auto_duo_code_review_enabled: true,
          enabled_foundational_flows: [
            ::Ai::Catalog::FoundationalFlow.code_review.foundational_flow_reference
          ]
        }
      end
    end
  end
end
