# frozen_string_literal: true

module SecretsManagement
  # Read-only value object describing the Secrets Manager entitlement state
  # for a top-level group (or instance). Resolved from CDot for SaaS and
  # from the local `GitlabSubscriptions::AddOnPurchase` mirror on
  # self-managed installs. No DB, no persistence, no state machine -- this
  # PORO observes, it does not transition.
  class Entitlement < Data.define(
    :state,
    :blocked_reason,
    :trial_started_at,
    :trial_expires_at,
    :credits_remaining,
    :credits_total,
    :on_demand_enabled,
    :beta_program_ended
  )
    STATES = %i[trial_eligible trial paid offline_paid blocked ineligible].freeze
    BLOCKED_REASONS = %i[
      trial_expired
      credits_exhausted
      on_demand_disabled
      grace
      subscription_grace_period_expired
    ].freeze

    # Read-only (`:grace`) window past the subscription end_date, derived
    # from the .com plan-downgrade grace so the two cannot drift apart.
    GRACE_DAYS = ::GitlabSubscription::SUBSCRIPTION_GRACE_PERIOD.in_days.to_i

    def self.for(namespace, user: nil)
      Resolver.new(namespace, user: user).resolve
    end

    # Like `.for`, but raises on resolution failure instead of failing closed
    # to `:ineligible` -- for callers (billing-event metadata) where an absent
    # state is honest and a wrong `:ineligible` is not. `http_timeout` bounds
    # each underlying CDot call, for latency-sensitive paths. `cache_ttl` opts
    # into a cross-request Rails.cache layer for hot paths that tolerate a stale state.
    def self.for!(namespace, user: nil, http_timeout: nil, cache_ttl: nil)
      Resolver.new(namespace, user: user, http_timeout: http_timeout, cache_ttl: cache_ttl).resolve!
    end

    # Entitlement is only meaningful for top-level groups: a personal
    # namespace's `root_ancestor` is itself (not a Group), so it maps to
    # instance-level entitlement (nil). `namespace` is any Group or Project.
    # Shared by callers that need to resolve the entitlement-relevant
    # namespace for a Group/Project before calling `.for`.
    def self.root_namespace_for(namespace)
      return unless namespace

      root = namespace.root_ancestor
      root.is_a?(::Group) ? root : nil
    end

    # Only `state` is required; every other field defaults to nil so that
    # state-specific constructions (e.g. `:ineligible`) don't have to spell
    # out inapplicable trial / paid fields. `state` and `blocked_reason` are
    # enforced against `STATES` / `BLOCKED_REASONS` so the constants are a
    # contract rather than documentation.
    def initialize(
      state:,
      blocked_reason: nil,
      trial_started_at: nil,
      trial_expires_at: nil,
      credits_remaining: nil,
      credits_total: nil,
      on_demand_enabled: nil,
      beta_program_ended: nil
    )
      validate_state!(state)
      validate_blocked_reason!(state, blocked_reason)
      super
    end

    def permits_writes?
      %i[trial paid offline_paid].include?(state)
    end

    def permits_access?
      %i[trial_eligible trial paid offline_paid].include?(state)
    end

    # Broader than `permits_access?`: `blocked` still permits reads, only `:ineligible` denies them.
    # Used by reads that stay inside Rails (Web UI, GraphQL); paths that hand the
    # client a credential to read straight from OpenBao use `permits_direct_read?`
    # instead (see below).
    def permits_read?
      permits_access? || state == :blocked
    end

    def in_grace?
      state == :blocked && blocked_reason == :grace
    end

    # Narrower than `permits_read?`: only the `grace` window permits direct reads,
    # every other `blocked_reason` denies them. Gates any path that issues a JWT
    # for reading straight from OpenBao (CI pipeline JWT, the non-CI/CD REST
    # access-token endpoint). Web/GraphQL intentionally stay on the broader
    # `permits_read?` since Rails brokers those reads itself.
    #
    # `trial_eligible` loses direct reads once the beta program ends
    # (`beta_program_ended`, resolved from the `end_secrets_manager_beta_program`
    # flag): non-converted beta namespaces keep metadata-only visibility via
    # Rails-brokered surfaces, but their pipelines stop reading secrets for free.
    def permits_direct_read?
      return false if state == :trial_eligible && beta_program_ended

      permits_access? || in_grace?
    end

    # Structured reason a write was denied, so callers can surface it
    # without re-querying the resolver. `nil` when writes are permitted.
    # `:blocked` carries its own (always-present) `blocked_reason`;
    # `:trial_eligible` is a state, not a blocked reason, so it maps to
    # `:trial_required` (the actionable reason from the caller's
    # perspective). Anything else left after `permits_writes?` is
    # `:ineligible`. Every branch returns a value from
    # `WriteActionDenialReasonEnum::VALUES`.
    def write_action_denial_reason
      return if permits_writes?

      { blocked: blocked_reason, trial_eligible: :trial_required }.fetch(state, :ineligible)
    end

    private

    def validate_state!(state)
      return if STATES.include?(state)

      raise ArgumentError, "Unknown state: #{state.inspect} (expected one of #{STATES.inspect})"
    end

    # `blocked_reason` is required when `state` is `:blocked` -- this is
    # what lets `write_action_denial_reason` avoid ever falling back to the
    # raw `:blocked` state, which isn't a valid `WriteActionDenialReasonEnum`
    # value.
    def validate_blocked_reason!(state, blocked_reason)
      if blocked_reason.nil?
        return unless state == :blocked

        raise ArgumentError,
          "blocked_reason is required when state is :blocked (expected one of #{BLOCKED_REASONS.inspect})"
      end

      return if BLOCKED_REASONS.include?(blocked_reason)

      raise ArgumentError,
        "Unknown blocked_reason: #{blocked_reason.inspect} (expected one of #{BLOCKED_REASONS.inspect})"
    end
  end
end
