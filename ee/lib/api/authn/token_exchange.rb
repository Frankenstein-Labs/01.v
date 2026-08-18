# frozen_string_literal: true

module API
  module Authn
    # PoC token-exchange endpoint for modular services. Marked experimental --
    # the surface is expected to be superseded by GATE L2 later
    # (ADR-016 / ADR-019).
    class TokenExchange < ::API::Base
      include APIGuard

      feature_category :system_access

      # Audiences this endpoint may mint tokens for. Modular services join
      # by adding their `jwt_aud` here.
      SUPPORTED_AUDIENCES = %w[gitlab-artifact-registry].freeze

      MAX_EXPIRES_IN_SECONDS = 12.hours.to_i

      before do
        authenticate!
        not_found! unless Feature.enabled?(:gate_token_exchange_endpoint, current_user, type: :gitlab_com_derisk)
      end

      namespace 'token_exchange' do
        desc 'Issue a short-lived JWT for a single modular-service audience' do
          detail 'Issues a short-lived RS256 JWT scoped to one modular-service audience ' \
            '(such as the Artifact Registry). Claims include the requesting user id (sub), ' \
            'organization id, and deployment realm (saas / self-managed). Presented to the ' \
            'corresponding backend and verified against the instance JWKS.'
          success code: 201
          failure [
            { code: 400, message: 'Bad Request' },
            { code: 401, message: 'Unauthorized' },
            { code: 404, message: 'Not Found' }
          ]
          tags %w[token_exchange]
        end
        route_setting :lifecycle, :experiment
        # Internal-only endpoint -- not exposed via the granular PAT system.
        # All existing PATs (legacy or granular) can call this endpoint without
        # needing to opt into a per-endpoint permission.
        # skip_job_token_policies: this endpoint does not act on a project
        # resource (no read_*/admin_* policy from ci_job_token_policies.json fits).
        # The job token is only the auth credential; the token we mint is
        # scoped via `audience`.
        route_setting :authorization,
          skip_granular_token_authorization: :modular_service_token_exchange,
          skip_job_token_policies: true
        # AR auth interface agreement R1: must accept CI job tokens.
        # The endpoint is not project-scoped, so any job token authenticates as
        # the per-build bot user (current_user becomes the bot User).
        #
        # Deploy tokens are deliberately NOT enabled here: DeployToken is not a
        # User, so our User-shaped payload (sub, gitlab_organization_id) doesn't
        # apply. R1 lists deploy tokens but R3 ("the principal's GitLab ID") has
        # no defined shape for non-User callers. Tracked as a follow-up.
        route_setting :authentication, job_token_allowed: true
        params do
          requires :audience, type: String,
            values: SUPPORTED_AUDIENCES,
            desc: 'Target service audience (e.g. gitlab-artifact-registry)'
          optional :expires_in, type: Integer,
            values: 1..MAX_EXPIRES_IN_SECONDS,
            desc: 'Requested token lifetime in seconds. ' \
              "Defaults to #{::Authn::TokenExchange::TokenIssuer::DEFAULT_TTL_SECONDS}; " \
              "cap is #{MAX_EXPIRES_IN_SECONDS}. Pending appsec review of client-controlled TTL."
        end
        post do
          check_rate_limit!(:token_exchange, scope: current_user)

          ttl = declared_params[:expires_in] || ::Authn::TokenExchange::TokenIssuer::DEFAULT_TTL_SECONDS

          token = ::Authn::TokenExchange::TokenIssuer.new(
            audience: [declared_params[:audience]],
            user: current_user,
            ttl: ttl
          ).token

          # TODO (production): emit a `Gitlab::InternalEvents.track_event` for usage analytics
          # (event name e.g. `token_exchange_issued`, additional_properties carrying the
          # audience). Requires an event YAML in config/events/.

          present({ token: token }, with: Grape::Presenters::Presenter)
        end
      end
    end
  end
end
