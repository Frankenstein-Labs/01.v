# frozen_string_literal: true

module Gitlab
  module SubscriptionPortal
    class SecretsManagerConsumerResolveResponse < Data.define(
      :blocked,
      :blocked_reason,
      :cache_ttl
    )
      Error = Class.new(StandardError)

      # `no_billable_source_error` is never surfaced as-is: the entitlement
      # resolver maps it to `:grace` or `:subscription_grace_period_expired`.
      BLOCKED_REASONS = %i[
        credits_exhausted
        on_demand_disabled
        subscription_grace_period_expired
        no_billable_source_error
      ].freeze

      def initialize(blocked:, blocked_reason: nil, cache_ttl: nil)
        validate_blocked_reason!(blocked, blocked_reason)
        super
      end

      private

      def validate_blocked_reason!(blocked, reason)
        return if reason.nil?
        return if blocked && BLOCKED_REASONS.include?(reason)

        raise ArgumentError,
          "Unknown CDot consumer-resolve blocked_reason: #{reason.inspect} " \
            "(expected one of #{BLOCKED_REASONS.inspect}, with blocked: true)"
      end
    end
  end
end
