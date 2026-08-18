# frozen_string_literal: true

module Authn
  module TokenExchange
    # Issues short-lived JWTs that GitLab Rails hands to clients for use with
    # modular services (e.g. Artifact Registry). Reuses the instance's
    # `CloudConnector::Keys` keypair as the signing key only; the token shape
    # itself is purpose-built for the GATE-direction token-exchange flow.
    #
    # Will eventually be superseded by GATE L2's `iam-sts` (see ADR-016 / ADR-019).
    class TokenIssuer
      SIGNING_ALGORITHM = 'RS256'

      DEFAULT_TTL_SECONDS = 5.minutes.to_i

      # Bumped only on breaking (non-additive) changes.
      SCHEMA_VERSION = 1

      # .com-only at launch, so always ORGANIZATION; SM/federated origins TBD.
      ORIGIN_ORGANIZATION = 'organization'
      IDENTITY_KIND_USER = 'user'

      # Every token is also scoped to iam-data-access so a modular service (e.g. AR) can forward it
      # when calling the Relationships/Lookup API. Verified by membership on each service.
      DATA_ACCESS_AUDIENCE = 'gitlab-iam-data-access'

      # Values for the binary gitlab.organization_role claim (see #organization_role).
      OWNER_ROLE = 'owner'
      MEMBER_ROLE = 'member'

      def initialize(audience:, user:, ttl: DEFAULT_TTL_SECONDS)
        @audience = Array(audience)
        @user = user
        @ttl = ttl
      end

      def token
        jwk = ::CloudConnector::CachingKeyLoader.private_jwk
        header = { typ: 'JWT', kid: jwk.kid }
        JWT.encode(payload, jwk.signing_key, SIGNING_ALGORITHM, header)
      end

      private

      def payload
        now = Time.current.to_i
        {
          jti: SecureRandom.uuid,
          iss: Doorkeeper::OpenidConnect.configuration.issuer,
          aud: (@audience + [DATA_ACCESS_AUDIENCE]).uniq,
          sub: @user.to_global_id.to_s,
          iat: now,
          nbf: now,
          exp: now + @ttl,
          ver: SCHEMA_VERSION,
          gitlab: {
            origin: ORIGIN_ORGANIZATION,
            origin_id: organization_uuid,
            local_id: @user.id,
            identity_kind: IDENTITY_KIND_USER,
            organization_role: organization_role
          }
        }
      end

      # rubocop:disable Gitlab/AvoidUserOrganization -- the token is scoped to the user's own organization
      def organization_uuid
        @user.organization.uuid
      end
      # rubocop:enable Gitlab/AvoidUserOrganization

      # Binary `owner` / `member` claim for the bootstrapping case described in
      # AUTH-015 (interim GATE identity mapping): before any role assignments
      # exist in the Relationships datastore, the modular service needs to
      # know whether the caller is an organization owner to authorize the
      # first activation call. Once activation runs, role lookup moves to the
      # Relationships API and this claim is no longer consulted.
      def organization_role
        @user.owns_organization?(@user.organization_id) ? OWNER_ROLE : MEMBER_ROLE
      end
    end
  end
end
