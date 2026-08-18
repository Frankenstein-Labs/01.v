# frozen_string_literal: true

module SecretsManagement
  class Entitlement
    # Resolves `SecretsManagement::Entitlement` for a top-level group (or
    # instance).
    #
    # Routing splits on live CDot connectivity:
    #
    # - gitlab.com + online-cloud-licensed self-managed
    #   -> online branch. Authoritative source is CDot; the local
    #   `AddOnPurchase` mirror only carries quantity and does not surface
    #   trial / on-demand / grace state. Stubbed to `:ineligible` until the
    #   SubscriptionPortal client lands.
    #
    # - offline-cloud-licensed self-managed (air-gapped)
    #   -> local `GitlabSubscriptions::AddOnPurchase` mirror. No CDot
    #   connectivity means trial / on-demand / grace are unreachable;
    #   the only states observable here are `:offline_paid` and
    #   `:blocked + :subscription_grace_period_expired`.
    #
    # `Gitlab.com?` is OR'd alongside `online_cloud_license?` defensively:
    # staging / dev environments simulating gitlab.com may ship with a
    # non-online-cloud license shape, and we want them routed to the online
    # branch rather than silently falling through to offline.
    class Resolver
      INELIGIBLE = Entitlement.new(state: :ineligible).freeze

      MEMOIZATION_KEY = :secrets_management_entitlement

      def initialize(namespace, user: nil, http_timeout: nil, cache_ttl: nil)
        validate_namespace!(namespace)
        @namespace = namespace
        @user = user
        @http_timeout = http_timeout
        @cache_ttl = cache_ttl
      end

      def resolve
        ::Gitlab::SafeRequestStore.fetch(cache_key) do
          resolve_uncached
        end
      end

      # Same resolution as `resolve`, but propagates failures instead of
      # failing closed to `:ineligible`. Nothing is cached when the block
      # raises, so a later `resolve` in the same request retries.
      # With `cache_ttl`, adds a Rails.cache layer on the same key, caching plain attributes (deploy-safe).
      def resolve!
        ::Gitlab::SafeRequestStore.fetch(cache_key) do
          next resolve_uncached! unless @cache_ttl

          attributes = Rails.cache.fetch(cache_key, expires_in: @cache_ttl) { resolve_uncached!.to_h }
          Entitlement.new(**attributes)
        end
      end

      private

      # Cache key reflects what actually varies the result.
      #
      # - SaaS: each top-level namespace has its own CDot-tracked entitlement
      #   (CDot keys by namespace_id), so the key includes `@namespace&.id`.
      # - Self-managed (online cloud or offline): entitlement is install-wide.
      #   Online cloud installs ask CDot per-instance (`/trials(instance_id)`)
      #   and offline installs read the instance-level AddOnPurchase mirror --
      #   either way, every namespace in the same request shares one entry.
      def cache_key
        if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          [MEMOIZATION_KEY, :saas, @namespace&.id]
        else
          [MEMOIZATION_KEY, :self_managed]
        end
      end

      def validate_namespace!(namespace)
        return if namespace.nil?
        return if namespace.is_a?(::Group) && namespace.root?

        raise ArgumentError,
          "SecretsManagement::Entitlement.for expects a top-level Group or nil (got #{namespace.class})"
      end

      def resolve_uncached
        resolve_uncached!
      rescue StandardError => e
        ::Gitlab::ErrorTracking.log_exception(
          e,
          issue_type: 'secrets_management_entitlement_fail_closed',
          gl_namespace_id: @namespace&.id
        )
        INELIGIBLE
      end

      def resolve_uncached!
        license = ::License.current
        return INELIGIBLE if license.nil?

        # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- gitlab.com is its own routing axis; license shape alone isn't guaranteed in staging/dev
        # Unlike self-managed, SaaS has no instance-level entitlement, so a nil namespace has nothing to resolve.
        return INELIGIBLE if ::Gitlab.com? && @namespace.nil?

        # A trial subscription has no Premium/Ultimate base charge, so CDot can never deem it
        # eligible -- don't ask. SaaS trials ride on the namespace plan, not the license.
        return INELIGIBLE if !::Gitlab.com? && license.trial?

        if ::Gitlab.com? || license.online_cloud_license?
          resolve_online
        else
          resolve_offline
        end
        # rubocop:enable Gitlab/AvoidGitlabInstanceChecks
      end

      # Merges the two CDot responses: /consumers/resolve decides blocked
      # yes/no + reason, /trials supplies lifecycle state and quota counters.
      def resolve_online
        return INELIGIBLE unless ::Feature.enabled?(:secrets_manager_paid_experience, @namespace)

        kwargs = cdot_identifier_kwargs
        kwargs[:timeout] = @http_timeout if @http_timeout
        trial = ::Gitlab::SubscriptionPortal::Client.secrets_manager_trial(**kwargs)
        # /consumers/resolve is the per-actor authorization check, so it also
        # needs the requesting user; /trials is namespace/instance-wide.
        resolve = ::Gitlab::SubscriptionPortal::Client.secrets_manager_consumer_resolve(**kwargs, user_id: @user&.id)
        return INELIGIBLE unless trial && resolve

        map_cdot_response(trial, resolve)
      end

      # gitlab.com asks CDot per top-level namespace; self-managed online-cloud
      # asks CDot per instance. Routing already gated on
      # `License.current.online_cloud_license?` upstream, so we only need to
      # disambiguate SaaS from SM here.
      # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- per-namespace (SaaS) vs per-instance (SM) CDot identity
      def cdot_identifier_kwargs
        if ::Gitlab.com?
          { namespace_id: @namespace&.id }
        else
          { instance_id: ::Gitlab::CurrentSettings.uuid }
        end
      end
      # rubocop:enable Gitlab/AvoidGitlabInstanceChecks

      def map_cdot_response(trial, resolve)
        return blocked_entitlement(trial, resolve) if resolve.blocked && !pre_trial_block?(trial, resolve)

        case trial.state
        when :trial_eligible
          Entitlement.new(
            state: :trial_eligible,
            trial_expires_at: trial.trial_expires_at,
            beta_program_ended: beta_program_ended?,
            on_demand_enabled: trial.on_demand_enabled
          )
        when :trial
          Entitlement.new(
            state: :trial,
            trial_started_at: trial.trial_started_at,
            trial_expires_at: trial.trial_expires_at,
            credits_remaining: trial.credits_remaining,
            credits_total: trial.credits_total,
            on_demand_enabled: trial.on_demand_enabled
          )
        when :expired
          Entitlement.new(
            state: :paid,
            trial_started_at: trial.trial_started_at,
            trial_expires_at: trial.trial_expires_at,
            on_demand_enabled: trial.on_demand_enabled
          )
        when :ineligible
          INELIGIBLE
        else
          raise ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error,
            "Unhandled CDot trial state: #{trial.state.inspect}"
        end
      end

      # `on_demand_disabled` is CDot's default answer for a subscription with no
      # credits and no overage terms -- the normal pre-trial shape, not enforcement.
      # Mapping it to :blocked would hide the trial CTA from eligible namespaces.
      def pre_trial_block?(trial, resolve)
        resolve.blocked_reason == :on_demand_disabled && trial.state == :trial_eligible
      end

      # Only `:trial_eligible` consults this: the beta cutoff exists to stop
      # free direct reads by non-converted beta namespaces, and every other
      # state already carries its own direct-read answer.
      def beta_program_ended?
        ::Feature.enabled?(:end_secrets_manager_beta_program, @namespace)
      end

      def blocked_entitlement(trial, resolve)
        Entitlement.new(
          state: :blocked,
          blocked_reason: blocked_reason_from(trial, resolve),
          trial_started_at: trial.trial_started_at,
          trial_expires_at: trial.trial_expires_at,
          credits_remaining: trial.credits_remaining,
          credits_total: trial.credits_total,
          on_demand_enabled: trial.on_demand_enabled
        )
      end

      # Expired never-bought SM trials arrive as on_demand_disabled -- relabel.
      # An active trial blocked as on_demand_disabled means its credits ran out.
      # Only a paid subscription opens the grace window; else fail closed.
      def blocked_reason_from(trial, resolve)
        return :credits_exhausted if resolve.blocked_reason == :on_demand_disabled && trial.state == :trial
        return :trial_expired if resolve.blocked_reason == :on_demand_disabled && trial.state == :expired
        return resolve.blocked_reason unless resolve.blocked_reason == :no_billable_source_error

        subscription = @namespace&.gitlab_subscription
        end_date = subscription.end_date if subscription&.has_a_paid_hosted_plan?

        return :subscription_grace_period_expired if end_date.nil?

        Date.current <= end_date + GRACE_DAYS ? :grace : :subscription_grace_period_expired
      end

      # Offline (air-gapped) self-managed installs have no CDot connection,
      # so the local AddOnPurchase mirror (populated from the license payload)
      # is the only signal. Trial state, on-demand billing, grace periods
      # cannot be observed here -- only `:offline_paid` and
      # `:blocked + :subscription_grace_period_expired` are reachable.
      def resolve_offline
        active = ::GitlabSubscriptions::AddOnPurchase
          .for_secrets_manager
          .for_self_managed
          .active
          .exists?

        return Entitlement.new(state: :blocked, blocked_reason: :subscription_grace_period_expired) unless active

        Entitlement.new(state: :offline_paid)
      end
    end
  end
end
