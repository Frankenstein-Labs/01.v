# frozen_string_literal: true

module Authz
  module ArtifactRegistry
    # Revokes a set of Artifact Registry role assignments in a single
    # all-or-nothing delete to the IAM Relationships API.
    #
    # A revocation names an assignee and a resource, no role: IAM stores one
    # ASSIGNMENT per (subject, object), so the pair identifies the assignment
    # and revoking removes whatever role the assignee holds there. Deleting an
    # assignment that does not exist succeeds for a subject IAM has already
    # seen, but IAM fails the whole batch with NOT_FOUND when any subject was
    # never granted anything. Both the single and bulk revoke mutations use
    # this service; the single revoke passes a one-element array.
    class RevokeRoleAssignmentsService < BaseService
      def initialize(current_user:, organization:, revocations:)
        @current_user = current_user
        @organization = organization
        # IAM only accepts canonical lowercase ids, so normalize case here
        # rather than rejecting an uppercase id.
        @revocations = revocations.map do |revocation|
          revocation.merge(resource_id: revocation[:resource_id]&.downcase)
        end
      end

      def execute
        return error(s_('ArtifactRegistry|You must be signed in to revoke a role.')) unless current_user
        return error(s_('ArtifactRegistry|Organization could not be determined.')) unless organization
        # The organization comes from the request context and can be influenced by
        # request headers, so confirm it is the caller's own before scoping the
        # IAM delete to it.
        unless callers_own_organization?
          return error(s_('ArtifactRegistry|You cannot revoke roles in another organization.'))
        end

        return error(s_('ArtifactRegistry|At least one revocation is required.')) if revocations.empty?

        # Validate every revocation and report each invalid one rather than
        # stopping at the first, so a caller fixing a bulk request sees all the
        # problems in one round-trip.
        errors = revocations.each_with_index.filter_map do |revocation, index|
          message = revocation_error(revocation)
          next unless message

          { number: index + 1, resource_id: revocation[:resource_id], message: message }
        end
        return error(validation_error(errors)) if errors.any?

        # Deleting the same key twice is harmless, so duplicates are collapsed
        # rather than rejected the way the grant path must. Deduplicating also
        # keeps revoked_role_count an honest count of distinct assignments.
        keys = revocations.map { |revocation| build_key(revocation) }.uniq

        client.revoke_roles(keys, organization_uuid: organization.uuid, token: token)

        ServiceResponse.success(payload: { revoked_role_count: keys.size })
      rescue ::Authn::IamService::UpdateRelationshipsClient::RequestError => e
        error(iam_error_message(e.reason))
      end

      private

      attr_reader :revocations

      alias_method :request_items, :revocations

      # Returns an error message if the revocation is invalid, otherwise nil.
      def revocation_error(revocation)
        assignee, resource_id = revocation.values_at(:assignee, :resource_id)

        # Treat a cross-organization assignee the same as a missing one so the
        # error does not reveal whether the user exists in another organization.
        return s_('ArtifactRegistry|Assignee could not be found.') unless assignee && same_organization?(assignee)
        return s_('ArtifactRegistry|Resource ID must be a valid UUIDv7.') unless ::Gitlab::UUID.v7?(resource_id)

        nil
      end

      # Builds the IAM delete key for a revocation already validated by
      # revocation_error.
      def build_key(revocation)
        {
          assignee_id: revocation[:assignee].id,
          resource_id: revocation[:resource_id]
        }
      end

      def position_error_format
        s_('ArtifactRegistry|Revocation %{number} on resource %{resource_id}: %{message}')
      end

      def client
        ::Authn::IamService::UpdateRelationshipsClient.new
      end

      def fallback_error_message(reason)
        case reason
        when :not_found
          # IAM fails the whole batch with NOT_FOUND when a subject was never
          # granted anything. Same generic message as a missing assignee, so it
          # discloses nothing about who IAM knows.
          s_('ArtifactRegistry|Assignee could not be found.')
        when :permission_denied
          s_('ArtifactRegistry|You are not authorized to revoke this role on this resource.')
        when :invalid_request
          s_('ArtifactRegistry|The role revocation request was invalid.')
        else
          s_('ArtifactRegistry|The role revocation could not be completed.')
        end
      end
    end
  end
end
