# frozen_string_literal: true

module GitlabSubscriptions
  module DuoPro
    ELIGIBLE_PLAN = ::Plan::PREMIUM

    def self.add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(namespace, add_on: :duo_pro).execute.first
    end

    def self.any_add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo_pro, only_active: false).execute.first
    end

    def self.no_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo_pro, only_active: false).execute.none?
    end

    def self.namespace_eligible?(namespace)
      namespace.actual_plan_name == ELIGIBLE_PLAN
    end
  end
end
