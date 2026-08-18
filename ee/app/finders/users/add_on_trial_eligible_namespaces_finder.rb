# frozen_string_literal: true

module Users
  class AddOnTrialEligibleNamespacesFinder
    def initialize(user, add_on:)
      @user = user
      @add_on = add_on
    end

    def execute
      validate_add_on!
      return Namespace.none unless add_on_exists?

      user.owned_groups
          .in_specific_plans(eligible_plans)
          .id_not_in(namespace_ids_with_add_on)
          .ordered_by_name
    end

    private

    attr_reader :user, :add_on

    def validate_add_on!
      return if add_on == :duo || add_on == :duo_enterprise

      raise ArgumentError, "Unknown add_on: #{add_on}"
    end

    def duo_add_on
      add_on == :duo
    end

    def namespace_ids_with_add_on
      purchases = GitlabSubscriptions::AddOnPurchase.by_namespace(user.owned_groups)
      for_addons = duo_add_on ? purchases.for_duo_pro_or_duo_enterprise : purchases.for_duo_enterprise
      for_addons.select(:namespace_id)
    end

    def add_on_exists?
      if duo_add_on
        GitlabSubscriptions::AddOn.code_suggestions.or(GitlabSubscriptions::AddOn.duo_enterprise).exists?
      else
        GitlabSubscriptions::AddOn.duo_enterprise.exists?
      end
    end

    def eligible_plans
      if duo_add_on
        GitlabSubscriptions::DuoPro::ELIGIBLE_PLAN
      else
        GitlabSubscriptions::DuoEnterprise::ELIGIBLE_PLANS
      end
    end
  end
end
