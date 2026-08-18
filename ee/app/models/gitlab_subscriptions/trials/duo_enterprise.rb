# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoEnterprise
      def self.any_add_on_purchase_for_namespace(namespace)
        GitlabSubscriptions::NamespaceAddOnPurchasesFinder
          .new(namespace, add_on: :duo_enterprise, trial: true, only_active: false)
          .execute
          .first
      end

      def self.active_add_on_purchase_for_namespace?(namespace)
        GitlabSubscriptions::NamespaceAddOnPurchasesFinder
          .new(namespace, add_on: :duo_enterprise, trial: true, only_active: true).execute.any?
      end

      def self.show_duo_enterprise_discover?(namespace, user)
        return false unless namespace.present?
        return false unless user.present?

        ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
          user.can?(:admin_namespace, namespace) &&
          GitlabSubscriptions::Trials::AddOnStatus.new(
            add_on_purchase: any_add_on_purchase_for_namespace(namespace.root_ancestor)
          ).show?
      end
    end
  end
end
