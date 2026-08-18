# frozen_string_literal: true

module GitlabSubscriptions
  module DuoEnterpriseAlert
    class PremiumComponent < BaseComponent
      private

      def render?
        namespace.premium_plan? && GitlabSubscriptions::Trials.namespace_eligible?(namespace)
      end

      def body
        [s_('BillingPlans|Start an Ultimate trial and try out the full product ' \
          'offering from GitLab, including AI-native features.')]
      end
    end
  end
end
