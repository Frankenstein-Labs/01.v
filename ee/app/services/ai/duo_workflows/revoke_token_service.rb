# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class RevokeTokenService
      def initialize(token:, current_user:)
        @token = token
        @current_user = current_user
      end

      def execute
        doorkeeper_token = OauthAccessToken.by_token(@token)

        # Invalid tokens do not cause an error response as per https://datatracker.ietf.org/doc/html/rfc7009
        return ServiceResponse.success(payload: {}, message: "Token revoked") unless doorkeeper_token.present?

        # Ensure token belongs to the authenticated user
        unless valid_token_ownership?(doorkeeper_token)
          return ServiceResponse.error(message: "Invalid token ownership", reason: :invalid_token_ownership)
        end

        # This service should only revoke ai_workflows scoped tokens
        unless doorkeeper_token.acceptable?("ai_workflows")
          return ServiceResponse.error(message: "Insufficient token scope", reason: :insufficient_token_scope)
        end

        revoked = doorkeeper_token.revoke

        return ServiceResponse.success(payload: {}, message: "Token revoked") if revoked

        ServiceResponse.error(message: "Could not revoke token", reason: :failed_to_revoke)
      end

      private

      def valid_token_ownership?(doorkeeper_token)
        if doorkeeper_token.user&.composite_identity_enforced? && doorkeeper_token.scope_user
          return doorkeeper_token.scope_user == @current_user
        end

        doorkeeper_token.resource_owner == @current_user
      end
    end
  end
end
