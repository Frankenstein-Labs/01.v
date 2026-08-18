# frozen_string_literal: true

module GitlabSubscriptions
  module SubscriptionHelpers
    # Creates or replaces a GitlabSubscription for the given namespace.
    #
    # Use this helper when you need to ensure a specific subscription exists,
    # even if the application code has auto-generated one. This can happen when:
    # - Adding members triggers event tracking, which calls namespace.actual_plan
    # - actual_plan auto-generates a FREE subscription if none exists
    # - You then need to create a different subscription (e.g., ULTIMATE)
    #
    # WARNING: Only use this when you specifically need to replace an auto-generated
    # subscription. In most cases, create the subscription BEFORE operations that
    # might trigger auto-generation (e.g., before adding members).
    #
    # @param namespace [Namespace] The namespace to create/replace the subscription for
    # @param traits [Array<Symbol>] Traits to pass to the factory (e.g., :ultimate)
    # @param attributes [Hash] Additional attributes to pass to the factory
    # @return [GitlabSubscription] The created subscription
    #
    # @example Replace auto-generated subscription
    #   project.add_developer(user) # This might auto-generate a FREE subscription
    #   create_or_replace_subscription(group, :ultimate, seats: 10)
    #
    def create_or_replace_subscription(namespace, *traits, **attributes)
      # Delete any existing subscription for this namespace
      GitlabSubscription.where(namespace_id: namespace.id).delete_all

      # Create the new subscription
      create(:gitlab_subscription, *traits, namespace: namespace, **attributes)
    end
  end
end
