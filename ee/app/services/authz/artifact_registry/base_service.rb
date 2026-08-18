# frozen_string_literal: true

module Authz
  module ArtifactRegistry
    class BaseService
      TOKEN_AUDIENCE = %w[gitlab-iam-data-access].freeze

      private

      attr_reader :current_user, :organization

      def callers_own_organization?
        current_user.organization_id == organization.id
      end

      def same_organization?(assignee)
        current_user.organization_id == assignee.organization_id
      end

      def token
        ::Authn::TokenExchange::TokenIssuer.new(
          audience: TOKEN_AUDIENCE,
          user: current_user
        ).token
      end

      # A single-item request needs no position, so return its bare message.
      # With several, prefix each with its position and resource so the caller
      # can tell which items to fix. Subclasses define request_items (the
      # submitted collection) and position_error_format (the verb wording).
      def validation_error(errors)
        return errors.first[:message] if request_items.size == 1

        errors.map do |error|
          format(position_error_format, error.slice(:number, :resource_id, :message))
        end.join("\n")
      end

      # Translates a client failure reason into a user-facing message. The
      # client stays transport-only and reports a reason; the wording lives
      # here. These three reasons read the same for every operation; the rest
      # are verb-specific and live in the subclasses.
      def iam_error_message(reason)
        case reason
        when :unauthenticated
          s_('ArtifactRegistry|Could not authenticate with the Artifact Registry service.')
        when :unavailable
          s_('ArtifactRegistry|The Artifact Registry service is unavailable.')
        when :timeout
          s_('ArtifactRegistry|The Artifact Registry service did not respond in time.')
        else
          fallback_error_message(reason)
        end
      end

      def client
        raise NotImplementedError, "#{self.class} must implement #client"
      end

      def error(message)
        ServiceResponse.error(message: message)
      end
    end
  end
end
