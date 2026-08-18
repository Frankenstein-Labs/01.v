# frozen_string_literal: true

module Gitlab
  module SubscriptionPortal
    module Clients
      module Rest
        extend ActiveSupport::Concern

        class_methods do
          SubscriptionPortalRESTException = Class.new(RuntimeError)

          def generate_trial(params)
            return request_disabled_error unless requests_enabled?

            trial_user_params = params[:trial_user] ? params : { trial_user: params }
            http_post('trials/gitlab_com/ultimates', admin_headers, trial_user_params)
          end

          def generate_self_managed_ultimate_trial(params)
            http_post("trials/self_managed/ultimates", json_headers, params)
          end

          def create_self_managed_welcome_contact(params)
            http_post("leads/self_managed/welcome_contacts", json_headers, params)
          end

          def generate_trial_lead(params)
            return request_disabled_error unless requests_enabled?

            trial_user_params = params[:trial_user] ? params : { trial_user: params }
            http_post("leads/gitlab_com/ultimates", admin_headers, trial_user_params)
          end

          def generate_addon_trial_lead(params)
            return request_disabled_error unless requests_enabled?

            trial_user_params = params[:trial_user] ? params : { trial_user: params }
            http_post("leads/gitlab_com/addons", admin_headers, trial_user_params)
          end

          def generate_addon_trial(params)
            return request_disabled_error unless requests_enabled?

            trial_user_params = params[:trial_user] ? params : { trial_user: params }
            http_post("trials/gitlab_com/addons", admin_headers, trial_user_params)
          end

          def generate_lead(params)
            return request_disabled_error unless requests_enabled?

            http_post("leads/gitlab_com/hand_raises", admin_headers, params)
          end

          def generate_iterable(params)
            return request_disabled_error unless requests_enabled?

            http_post("trials/create_iterable", admin_headers, params)
          end

          def opt_in_lead(params)
            http_post("api/marketo_leads/opt_in", admin_headers, params)
          end

          def payment_form_params(payment_type, user_id)
            http_get("payment_forms/#{payment_type}", admin_headers, { user_id: user_id }.compact)
          end

          def validate_payment_method(id, params)
            http_post("api/payment_methods/#{id}/validate", admin_headers, params)
          end

          def create_seat_link(seat_link)
            raise TypeError unless seat_link.is_a?(Gitlab::SeatLinkData)

            http_post("api/v1/seat_links", json_headers, seat_link)
          end

          def namespace_eligible_trials(params)
            return request_disabled_error unless requests_enabled?

            http_get('api/v1/gitlab/namespaces/trials/eligibility', admin_headers, params)
          end

          def namespace_trial_types
            return request_disabled_error unless requests_enabled?

            http_get('api/v1/gitlab/namespaces/trials/trial_types', admin_headers)
          end

          def verify_usage_quota(params)
            headers = if Gitlab.com? # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- Available on gitlab.com only
                        admin_headers
                      else
                        license_checksum_headers
                      end

            http_head('api/v1/consumers/resolve', headers, params, base_url_to_call: usage_quota_base_url)
          end

          # Fallback cross-request cache TTL when CDot's Cache-Control header
          # carries no max-age; deliberately short and easy to tune.
          SECRETS_MANAGER_CACHE_FALLBACK_TTL = 120.seconds

          def secrets_manager_trial(namespace_id: nil, instance_id: nil, timeout: nil)
            validate_secrets_manager_identifiers!(namespace_id, instance_id)
            key = secrets_manager_cache_key(:trial, namespace_id, instance_id)

            ::Gitlab::SafeRequestStore.fetch(key) do
              secrets_manager_cross_request_cache(key) do
                fetch_secrets_manager_trial(namespace_id: namespace_id, instance_id: instance_id, timeout: timeout)
              end
            end
          end

          def secrets_manager_consumer_resolve(namespace_id: nil, instance_id: nil, user_id: nil, timeout: nil)
            validate_secrets_manager_identifiers!(namespace_id, instance_id)
            key = secrets_manager_cache_key(:consumer_resolve, namespace_id, instance_id)

            ::Gitlab::SafeRequestStore.fetch(key) do
              secrets_manager_cross_request_cache(key) do
                fetch_secrets_manager_consumer_resolve(
                  namespace_id: namespace_id, instance_id: instance_id, user_id: user_id, timeout: timeout
                )
              end
            end
          end

          # POST counterpart to `secrets_manager_trial`: asks CDot to start a
          # Secrets Manager trial. Unlike the GETs this is a state change, so it
          # is never memoized via SafeRequestStore. Eligibility is enforced
          # server-side by CDot's `Billing::Usage::Trials::EligibilityService`;
          # this method only forwards and normalizes the outcome.
          def start_secrets_manager_trial(namespace_id: nil, instance_id: nil)
            validate_secrets_manager_identifiers!(namespace_id, instance_id)

            post_secrets_manager_trial(namespace_id: namespace_id, instance_id: instance_id)
          end

          # A blocked resolve stays cacheable for minutes while granted answers
          # are not cached at all, so a caller that changes the CDot state has to
          # drop these entries or the stale block outlives the change.
          def expire_secrets_manager_cache(namespace_id: nil, instance_id: nil)
            [:trial, :consumer_resolve].each do |endpoint|
              key = secrets_manager_cache_key(endpoint, namespace_id, instance_id)

              ::Gitlab::SafeRequestStore.delete(key)
              Rails.cache.delete(key)
            end
          end

          private

          # Cross-request TTL cache for the CDot entitlement GETs, so read
          # volume (one OpenBao audit callback per secret read) does not
          # translate 1:1 into CDot request volume. TTL honors CDot's
          # Cache-Control max-age when present (0 disables caching); failures
          # raise before the write, so errors are never cached.
          def secrets_manager_cross_request_cache(key)
            cached = Rails.cache.read(key)
            return cached unless cached.nil?

            yield.tap do |response|
              ttl = response.cache_ttl&.seconds || SECRETS_MANAGER_CACHE_FALLBACK_TTL
              Rails.cache.write(key, response, expires_in: ttl) if ttl > 0
            end
          end

          def fetch_secrets_manager_trial(namespace_id:, instance_id:, timeout: nil)
            url = "#{base_url}/api/v1/billing/usage/trials"
            headers = cdot_identity_headers
            query = cdot_trial_query(namespace_id: namespace_id, instance_id: instance_id)

            options = { query: query, headers: headers }
            options[:timeout] = timeout if timeout

            response = ::Gitlab::HTTP.get(url, options)
            if response.code == 200
              return parse_secrets_manager_trial(response.parsed_response, cache_ttl: extract_cache_ttl(response))
            end

            raise ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error,
              "Unexpected CDot response: HTTP #{response.code}"
          rescue *::Gitlab::HTTP::HTTP_ERRORS => e
            raise ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error, e.message
          end

          # CDot's `Api::V1::Consumers::ResolveController` is feature-scoped
          # (the caller declares which feature is being authorized) and signals
          # the verdict via HTTP status, not a body field:
          #
          #   HTTP 200             -> not blocked
          #   HTTP 402 (PAYMENT)   -> blocked, body carries `block_reason`
          #   anything else        -> protocol/deployment error, raise
          #
          # Required query params: `feature_qualified_name`, `realm`,
          # `instance_version`, `user_id` (the requesting actor), and the
          # identifier (`root_namespace_id` on SaaS, `instance_id` +
          # `unique_instance_id` on self-managed online cloud).
          def fetch_secrets_manager_consumer_resolve(namespace_id:, instance_id:, user_id:, timeout: nil)
            url = "#{base_url}/api/v1/consumers/resolve"
            headers = cdot_identity_headers
            query = cdot_consumer_resolve_query(
              namespace_id: namespace_id, instance_id: instance_id, user_id: user_id
            )

            options = { query: query, headers: headers }
            options[:timeout] = timeout if timeout

            response = ::Gitlab::HTTP.get(url, options)

            case response.code
            when 200
              ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(
                blocked: false, cache_ttl: extract_cache_ttl(response)
              )
            when 402
              parse_secrets_manager_consumer_resolve_blocked(
                response.parsed_response, cache_ttl: extract_cache_ttl(response)
              )
            else
              raise ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse::Error,
                "Unexpected CDot response: HTTP #{response.code}"
            end
          rescue *::Gitlab::HTTP::HTTP_ERRORS => e
            raise ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse::Error, e.message
          end

          # POST to the same `/billing/usage/trials` endpoint as the GET, with
          # the env-routed identifier + realm in the body. CDot owns eligibility,
          # so we translate its HTTP status into a normalized result:
          #
          #   200 / 201 -> success
          #   409       -> already trialing (:trial_already_active)
          #   422       -> rejected as ineligible (:ineligible, message from body)
          #   404       -> namespace/instance unknown to CDot (:not_found)
          #   anything else -> protocol/deployment error, raise (mutation maps
          #                    this to a generic "unavailable" message)
          def post_secrets_manager_trial(namespace_id:, instance_id:)
            url = "#{base_url}/api/v1/billing/usage/trials"
            headers = cdot_identity_headers
            body = cdot_trial_query(namespace_id: namespace_id, instance_id: instance_id)
              .merge(trial_type: 'secrets_manager')

            response = ::Gitlab::HTTP.post(url, body: body.to_json, headers: headers)

            case response.code
            when 200, 201
              ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse.new(success: true)
            when 409
              ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse.new(
                success: false, error_code: :trial_already_active
              )
            when 422
              ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse.new(
                success: false,
                error_code: :ineligible,
                error_message: parse_start_trial_error_message(response.parsed_response)
              )
            when 404
              ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse.new(
                success: false, error_code: :not_found
              )
            else
              raise ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse::Error,
                "Unexpected CDot response: HTTP #{response.code}"
            end
          rescue *::Gitlab::HTTP::HTTP_ERRORS => e
            raise ::Gitlab::SubscriptionPortal::SecretsManagerStartTrialResponse::Error, e.message
          end

          # CDot's 422 body carries a human-readable reason under `errors`
          # (string or array). Returns nil when the body is unparseable so the
          # mutation falls back to a generic message.
          def parse_start_trial_error_message(payload)
            return unless payload.is_a?(Hash)

            errors = payload.with_indifferent_access[:errors]
            Array.wrap(errors).join(', ').presence
          end

          # CDot's GET /api/v1/billing/usage/trials returns raw trial facts
          # (trial history, current credit balance, paid opt-in, new-trial
          # eligibility) for ALL trial add-ons under `trial_info`. It does NOT
          # return a lifecycle `state` field, so we derive ours here from the
          # secrets_manager sub-block:
          #
          #   no SM block (CDot disabled trial provisioning) -> :ineligible
          #   no trials                  -> :trial_eligible if eligible, else :ineligible
          #   trials[0].expires_at >= now -> :trial
          #   trials[0].expires_at <  now -> :expired
          #
          # As of today only one secrets_manager trial per namespace is allowed,
          # so we read `trials[0]`; the array shape is preserved by CDot for
          # forward compatibility (multiple trial periods).
          #
          # Quota fields also live here (not on /consumers/resolve):
          #   current_balance              -> credits_remaining (coerced to Int)
          #   trials[0].initial_credit_amount -> credits_total      (coerced to Int)
          #   opt_in_paid                  -> on_demand_enabled
          def parse_secrets_manager_trial(payload, cache_ttl: nil)
            payload = coerce_cdot_payload!(payload, ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse::Error)
            sm = payload.dig(:trial_info, :secrets_manager)

            unless sm.is_a?(Hash)
              return ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(
                state: :ineligible, cache_ttl: cache_ttl
              )
            end

            current_trial = Array.wrap(sm[:trials]).first

            ::Gitlab::SubscriptionPortal::SecretsManagerTrialResponse.new(
              state: derive_secrets_manager_trial_state(sm, current_trial),
              trial_started_at: parse_time(current_trial&.dig(:starts_at)),
              trial_expires_at: parse_time(current_trial&.dig(:expires_at)),
              credits_remaining: parse_credit_amount(sm[:current_balance]),
              credits_total: parse_credit_amount(current_trial&.dig(:initial_credit_amount)),
              on_demand_enabled: sm[:opt_in_paid],
              cache_ttl: cache_ttl
            )
          end

          def derive_secrets_manager_trial_state(sm, current_trial)
            if current_trial.blank?
              sm[:eligible_to_start_new_trial] ? :trial_eligible : :ineligible
            else
              expires_at = parse_time(current_trial[:expires_at])
              expires_at && expires_at >= Time.current ? :trial : :expired
            end
          end

          # CDot returns credit amounts as stringified decimals (e.g. "500.0").
          # GraphQL exposes credits as `Int`, so we coerce here; fractional
          # credits are not user-meaningful for SM trial accounting.
          def parse_credit_amount(value)
            return if value.nil?

            value.to_i
          end

          # Only called for HTTP 402 responses. CDot's body carries the reason
          # as the singular `block_reason` field (e.g. "below_min_gitlab_version",
          # and eventually the SM-specific values). Unknown values fall through
          # to the PORO validator, which raises -- the resolver's
          # `rescue StandardError` then fails closed to `:ineligible`.
          def parse_secrets_manager_consumer_resolve_blocked(payload, cache_ttl: nil)
            payload = coerce_cdot_payload!(payload, ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse::Error)

            ::Gitlab::SubscriptionPortal::SecretsManagerConsumerResolveResponse.new(
              blocked: true,
              blocked_reason: payload[:block_reason]&.to_sym,
              cache_ttl: cache_ttl
            )
          end

          def coerce_cdot_payload!(payload, error_class)
            raise error_class, "Unexpected CDot payload: #{payload.class}" unless payload.is_a?(Hash)

            payload.with_indifferent_access
          end

          # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- CDot identity is env-determined: token, query identifier, cache axis, and validator all key off this
          def saas?
            ::Gitlab.com?
          end
          # rubocop:enable Gitlab/AvoidGitlabInstanceChecks

          # Auth identity is environment-driven, not arg-driven: on gitlab.com
          # we authenticate with the admin token; on self-managed online cloud
          # installs the license checksum is the only credential available.
          def cdot_identity_headers
            base = saas? ? admin_headers : license_checksum_headers
            base.merge('X-Gitlab-Version' => ::Gitlab::VERSION)
          end

          def cdot_realm
            saas? ? 'saas' : 'self-managed'
          end

          # On SaaS CDot keys trials by the top-level namespace and expects the
          # `root_namespace_id` param (not `namespace_id`); self-managed online
          # cloud installs are keyed by `instance_id`.
          def cdot_identifier_query(namespace_id:, instance_id:)
            saas? ? { root_namespace_id: namespace_id } : { instance_id: instance_id }
          end

          # `/billing/usage/trials` requires the realm alongside the identifier.
          def cdot_trial_query(namespace_id:, instance_id:)
            cdot_identifier_query(namespace_id: namespace_id, instance_id: instance_id)
              .merge(realm: cdot_realm)
          end

          # `/consumers/resolve` is feature-scoped, version-aware, and
          # actor-aware, so it needs more than just the identifier. The realm
          # and instance_version pair lets CDot apply min-version gating;
          # `user_id` is the requesting actor. Self-managed installs
          # additionally send `unique_instance_id` (the instance UUID).
          # `event_type` and `feature_qualified_name` use CDot's flow-type
          # vocabulary (the same one our usage-event emitters use) so CDot can
          # classify the consumer and resolve the workflow.
          def cdot_consumer_resolve_query(namespace_id:, instance_id:, user_id:)
            query = cdot_identifier_query(namespace_id: namespace_id, instance_id: instance_id).merge(
              realm: cdot_realm,
              event_type: 'secrets_read',
              feature_qualified_name: 'secrets_read',
              instance_version: ::Gitlab::VERSION,
              user_id: user_id
            )
            query[:unique_instance_id] = instance_id unless saas?

            query
          end

          def validate_secrets_manager_identifiers!(namespace_id, instance_id)
            if saas?
              return if namespace_id.present? && instance_id.blank?

              raise ArgumentError,
                'secrets_manager_* on gitlab.com requires namespace_id only ' \
                  "(got namespace_id=#{namespace_id.inspect}, instance_id=#{instance_id.inspect})"
            else
              return if instance_id.present? && namespace_id.blank?

              raise ArgumentError,
                'secrets_manager_* on self-managed requires instance_id only ' \
                  "(got namespace_id=#{namespace_id.inspect}, instance_id=#{instance_id.inspect})"
            end
          end

          # Key shape preserves the axis (`:namespace_id` vs `:instance_id`)
          # alongside the value so an integer namespace_id and a UUID
          # instance_id can never collide in the per-request cache, even if
          # they happened to be equal. The axis is env-driven, matching
          # cdot_identity_headers / cdot_identifier_query.
          def secrets_manager_cache_key(endpoint, namespace_id, instance_id)
            if saas?
              [:secrets_manager, endpoint, :namespace_id, namespace_id]
            else
              [:secrets_manager, endpoint, :instance_id, instance_id]
            end
          end

          def parse_time(value)
            return if value.blank?

            Time.zone.parse(value.to_s)
          rescue ArgumentError
            nil
          end

          def requests_enabled?
            ::Gitlab::Saas.feature_available?(:cdot_requests)
          end

          def error_message
            _('Our team has been notified. Please try again.')
          end

          def request_disabled_error
            {
              success: false,
              data: { errors: 'Subscription portal requests disabled for non-SaaS.' }
            }.with_indifferent_access
          end

          def track_exception(message)
            Gitlab::ErrorTracking.track_exception(SubscriptionPortalRESTException.new(message))
          end

          def base_url
            ::Gitlab::Routing.url_helpers.subscription_portal_url
          end

          def http_get(path, headers, query = {})
            process_http_call { Gitlab::HTTP.get("#{base_url}/#{path}", query: query, headers: headers) }
          end

          def http_post(path, headers, params = {})
            process_http_call do
              Gitlab::HTTP.post("#{base_url}/#{path}", body: params.to_json, headers: headers)
            end
          end

          def http_head(path, headers, query = {}, base_url_to_call: base_url)
            process_http_call do
              Gitlab::HTTP.head("#{base_url_to_call}/#{path}", query: query, headers: headers)
            end
          end

          def process_http_call
            response = yield
            parse_response(response).tap do |result|
              result[:cache_ttl] = extract_cache_ttl(response)
            end
          rescue *Gitlab::HTTP::HTTP_ERRORS => e
            track_exception(e.message)
            { success: false, data: { errors: error_message } }.with_indifferent_access
          end

          def extract_cache_ttl(response)
            cache_control = response.headers&.[]('cache-control')
            return unless cache_control

            match = cache_control.match(/max-age=(\d+)/)
            match[1].to_i if match
          end

          def usage_quota_base_url
            return base_url unless use_mock_usage_quota_endpoint?

            env_url = ENV['MOCK_CUSTOMER_DOT_PORTAL_SERVER_URL']
            return env_url if env_url.present?

            'http://localhost:4567'
          end

          def use_mock_usage_quota_endpoint?
            Rails.env.development? &&
              Feature.enabled?(:use_mock_dot_api_for_usage_quota, :instance)
          end
        end
      end
    end
  end
end
