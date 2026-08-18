# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoPro
      def self.show_duo_pro_discover?(namespace, user)
        return false unless namespace.present?
        return false unless user.present?

        ::Gitlab::Saas.feature_available?(:subscriptions_trials) &&
          user.can?(:admin_namespace, namespace) &&
          GitlabSubscriptions::Trials::AddOnStatus.new(
            add_on_purchase: any_add_on_purchase_for_namespace(namespace.root_ancestor)
          ).show?
      end

      def self.show_duo_usage_settings?(namespace)
        add_on_purchase = GitlabSubscriptions::DuoPro.any_add_on_purchase_for_namespace(namespace)
        return false unless add_on_purchase.present?

        if add_on_purchase.trial?
          GitlabSubscriptions::Trials::AddOnStatus.new(add_on_purchase: add_on_purchase).show?
        else
          add_on_purchase.active?
        end
      end

      def self.active_add_on_purchase_for_namespace?(namespace)
        GitlabSubscriptions::NamespaceAddOnPurchasesFinder
          .new(namespace, add_on: :duo_pro, trial: true, only_active: true).execute.any?
      end

      def self.any_add_on_purchase_for_namespace(namespace)
        GitlabSubscriptions::NamespaceAddOnPurchasesFinder
          .new(namespace, add_on: :duo_pro, trial: true, only_active: false)
          .execute
          .first
      end
    end
  end
end
