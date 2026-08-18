# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    FREE_TRIAL_TYPE = 'ultimate_with_gitlab_duo_enterprise'
    FREE_TRIAL_TYPE_V2 = 'ultimate_with_dap'
    PREMIUM_TRIAL_TYPE = 'ultimate_on_premium_with_gitlab_duo_enterprise'
    PREMIUM_TRIAL_TYPE_V2 = 'ultimate_on_premium_with_dap'
    DUO_ENTERPRISE_TRIAL_TYPE = 'gitlab_duo_enterprise'
    TRIAL_TYPES = [FREE_TRIAL_TYPE, FREE_TRIAL_TYPE_V2, PREMIUM_TRIAL_TYPE, PREMIUM_TRIAL_TYPE_V2].freeze

    TIME_FRAME_AFTER_EXPIRATION = 10.days
    private_constant :TIME_FRAME_AFTER_EXPIRATION

    def self.single_eligible_namespace?(eligible_namespaces)
      return false unless eligible_namespaces.any? # executes query and now relation is loaded

      eligible_namespaces.one?
    end

    def self.creating_group_trigger?(namespace_id)
      # The value of 0 is the option in the select for creating a new group
      namespace_id.to_s == '0'
    end

    def self.eligible_namespace?(namespace_id, eligible_namespaces)
      return true if namespace_id.blank?

      namespace_id.to_i.in?(eligible_namespaces.pluck_primary_key)
    end

    def self.namespace_eligible?(namespace)
      namespace_plan_eligible?(namespace) && namespace_add_on_eligible?(namespace)
    end

    def self.namespace_plan_eligible?(namespace)
      namespace.actual_plan_name.in?(::Plan::PLANS_ELIGIBLE_FOR_TRIAL)
    end

    def self.namespace_plan_eligible_for_active?(namespace)
      namespace.actual_plan_name.in?(::Plan::ULTIMATE_TRIAL_PLANS)
    end

    def self.trial_type_for_namespace(namespace)
      namespace.premium_plan? ? PREMIUM_TRIAL_TYPE_V2 : FREE_TRIAL_TYPE_V2
    end

    def self.eligible_namespaces_for_user(user)
      Namespaces::TrialEligibleFinder.new(user:).execute
    end

    def self.no_eligible_namespaces_for_user?(user)
      eligible_namespaces_for_user(user).none?
    end

    def self.namespace_add_on_eligible?(namespace)
      Namespaces::TrialEligibleFinder.new(namespace:).execute.any?
    end

    def self.recently_expired?(namespace)
      free_plan_expired?(namespace) &&
        namespace.trial_ends_on > TIME_FRAME_AFTER_EXPIRATION.ago
    end

    def self.free_plan_expired?(namespace)
      namespace.free_plan? && namespace.trial_expired?
    end

    def self.self_managed_non_dedicated_ultimate_trial?(license)
      return false unless license
      return false if ::Gitlab::Dedicated.feature_available?(:skip_ultimate_trial_experience)

      license.ultimate? && !!license.trial?
    end

    def self.self_managed_non_dedicated_active_ultimate_trial?(license)
      self_managed_non_dedicated_ultimate_trial?(license) && license.active?
    end

    def self.self_managed_non_dedicated_expired_ultimate_trial?(license)
      self_managed_non_dedicated_ultimate_trial?(license) && license.expired?
    end
  end
end
