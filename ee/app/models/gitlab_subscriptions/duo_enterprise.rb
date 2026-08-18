# frozen_string_literal: true

module GitlabSubscriptions
  module DuoEnterprise
    ELIGIBLE_PLANS = [::Plan::ULTIMATE].freeze

    def self.no_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, only_active: false, add_on: :duo_enterprise).execute.none?
    end

    def self.active_add_on_purchase_for_self_managed?
      GitlabSubscriptions::AddOnPurchase.for_self_managed.for_duo_enterprise.active.exists?
    end

    def self.namespace_eligible?(namespace)
      namespace_plan_eligible?(namespace) && no_add_on_purchase_for_namespace?(namespace)
    end

    def self.namespace_plan_eligible?(namespace)
      namespace.actual_plan_name.in?(ELIGIBLE_PLANS)
    end
  end
end
