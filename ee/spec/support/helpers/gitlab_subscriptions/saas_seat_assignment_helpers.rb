# frozen_string_literal: true

module GitlabSubscriptions
  module SaasSetAssignmentHelpers
    def setup_addon_purchase_and_seat_assignment(user, group, add_on_type)
      gitlab_duo_add_on = create(:gitlab_subscription_add_on, add_on_type)

      active_gitlab_duo_purchase = create(
        :gitlab_subscription_add_on_purchase,
        add_on: gitlab_duo_add_on,
        namespace: group
      )

      create(
        :gitlab_subscription_user_add_on_assignment,
        user: user,
        add_on_purchase: active_gitlab_duo_purchase
      )
    end

    def add_user_to_group(user, addon)
      create(
        :gitlab_subscription_user_add_on_assignment,
        user: user,
        add_on_purchase: addon
      )
    end
  end
end
