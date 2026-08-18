# frozen_string_literal: true

module Authz
  module ArtifactRegistry
    # Reads Artifact Registry role assignments from the IAM Relationships API
    # (lookup.v1.LookupService#LookupRelationships).
    #
    # Validates the caller and the query inputs, then reads through IAM. IAM
    # enforces authorization itself: with no objects the caller must own the
    # organization; with objects the caller needs an admin grant on each object
    # or one of its listed ancestors. This service performs no authorization of
    # its own, the same posture as GrantRoleAssignmentsService on the write path.
    class LookupRoleAssignmentsService < BaseService
      # IAM clamps page_size to its own cap; we clamp here too so a caller gets a
      # predictable bound rather than silent server-side truncation.
      MAX_PAGE_SIZE = 999

      # This endpoint reads role assignments. The relationships store is a
      # general tuple table that will hold other kinds (parent, seal, visibility)
      # as they land, so every read is scoped to the assignment kind rather than
      # returning whatever is stored. A general relationship read, if it is ever
      # needed, would be a separate API, not a kind filter added here. See the
      # discussion on !247150.
      ASSIGNMENT_KIND = :KIND_ASSIGNMENT

      def initialize(current_user:, organization:, objects: [], roles: [], page_size: nil, page_after: nil)
        @current_user = current_user
        @organization = organization
        # IAM only accepts canonical lowercase ids, so normalize case here
        # rather than rejecting an uppercase id.
        @objects = objects.map do |object|
          object.merge(
            resource_id: object[:resource_id]&.downcase,
            ancestor_ids: Array(object[:ancestor_ids]).map { |ancestor_id| ancestor_id&.downcase }
          )
        end
        @roles = roles
        @page_size = page_size
        @page_after = page_after
      end

      def execute
        return error(s_('ArtifactRegistry|You must be signed in to read role assignments.')) unless current_user
        return error(s_('ArtifactRegistry|Organization could not be determined.')) unless organization
        # The read is always scoped to the caller's own organization by the
        # token IAM receives; the request carries no organization of its own.
        # This guard rejects a request whose context organization is not the
        # caller's own, and answers with the same generic not-found message as
        # an unknown resource so it never discloses that another organization
        # exists.
        return error(not_found_message) unless callers_own_organization?

        validation_message = inputs_error
        return error(validation_message) if validation_message

        response = client.lookup(
          objects: object_inputs,
          kinds: [ASSIGNMENT_KIND],
          role_ids: role_id_filters,
          page_size: clamped_page_size,
          page_token: page_after,
          token: token
        )

        ServiceResponse.success(payload: {
          role_assignments: response.relationships.to_a,
          next_page_token: response.next_page_token
        })
      rescue ::Authn::IamService::LookupRelationshipsClient::RequestError => e
        error(iam_error_message(e.reason))
      end

      private

      attr_reader :objects, :roles, :page_size, :page_after

      # Returns the first invalid input as a message, or nil when all inputs are
      # valid. Objects and role filters are each checked.
      def inputs_error
        object_error || role_error
      end

      def object_error
        objects.each do |object|
          unless ::Gitlab::UUID.v7?(object[:resource_id])
            return s_('ArtifactRegistry|Resource ID must be a valid UUIDv7.')
          end

          Array(object[:ancestor_ids]).each do |ancestor_id|
            return s_('ArtifactRegistry|Ancestor ID must be a valid UUIDv7.') unless ::Gitlab::UUID.v7?(ancestor_id)
          end
        end

        nil
      end

      def role_error
        unknown = resolved_roles.select { |_role, id| id.nil? }.keys
        return if unknown.empty?

        format(s_('ArtifactRegistry|Unknown Artifact Registry roles: %{roles}.'), roles: unknown.join(', '))
      end

      # Resolves each requested role name to its id once, so validation and the
      # filter share a single pass. A nil id means the name is unknown.
      def resolved_roles
        @resolved_roles ||= roles.index_with { |role| Roles.uuid_for(role) }
      end

      # Shapes each object for the client as an id plus its listed ancestors, the
      # form the IAM Object message expects.
      def object_inputs
        objects.map do |object|
          { id: object[:resource_id], ancestor_ids: Array(object[:ancestor_ids]) }
        end
      end

      def role_id_filters
        resolved_roles.values.compact
      end

      # nil lets IAM apply its own default; a positive request is capped at
      # MAX_PAGE_SIZE; a non-positive request falls back to the default.
      def clamped_page_size
        return unless page_size
        return if page_size <= 0

        [page_size, MAX_PAGE_SIZE].min
      end

      def client
        ::Authn::IamService::LookupRelationshipsClient.new
      end

      def fallback_error_message(reason)
        case reason
        when :not_found
          not_found_message
        when :permission_denied
          s_('ArtifactRegistry|You are not authorized to read these role assignments.')
        when :invalid_request
          s_('ArtifactRegistry|The role assignment lookup request was invalid.')
        else
          s_('ArtifactRegistry|The role assignment lookup could not be completed.')
        end
      end

      # A generic message shared by the cross-organization guard and the IAM
      # not-found reason, so neither discloses whether a resource or org exists.
      def not_found_message
        s_('ArtifactRegistry|The requested resources could not be found.')
      end
    end
  end
end
