# frozen_string_literal: true

module Authz
  module ArtifactRegistry
    # Grants a set of Artifact Registry role assignments in a single
    # all-or-nothing write to the IAM Relationships API.
    #
    # Validates each assignment (same organization, valid resource UUID, known
    # role) and writes them all in one all-or-nothing IAM call. If any
    # assignment is invalid, nothing is written. Both the single and bulk grant
    # mutations use this service; the single grant passes a one-element array.
    class GrantRoleAssignmentsService < BaseService
      def initialize(current_user:, organization:, assignments:)
        @current_user = current_user
        @organization = organization
        # IAM only accepts canonical lowercase ids, so normalize case here
        # rather than rejecting an uppercase id.
        @assignments = assignments.map do |assignment|
          assignment.merge(resource_id: assignment[:resource_id]&.downcase)
        end
      end

      def execute
        return error(s_('ArtifactRegistry|You must be signed in to grant a role.')) unless current_user
        return error(s_('ArtifactRegistry|Organization could not be determined.')) unless organization
        # The organization comes from the request context and can be influenced by
        # request headers, so confirm it is the caller's own before scoping the
        # IAM write to it.
        unless callers_own_organization?
          return error(s_('ArtifactRegistry|You cannot grant roles in another organization.'))
        end

        return error(s_('ArtifactRegistry|At least one assignment is required.')) if assignments.empty?

        # Validate every assignment and report each invalid one rather than
        # stopping at the first, so a caller fixing a bulk request sees all the
        # problems in one round-trip.
        errors = assignments.each_with_index.filter_map do |assignment, index|
          message = assignment_error(assignment)
          next unless message

          { number: index + 1, resource_id: assignment[:resource_id], message: message }
        end
        return error(validation_error(errors)) if errors.any?

        inputs = assignments.map { |assignment| build_input(assignment) }

        duplicates = duplicate_assignments
        return error(duplicate_error(duplicates)) if duplicates.any?

        client.grant_roles(inputs, organization_uuid: organization.uuid, token: token)

        ServiceResponse.success(payload: { granted_role_count: inputs.size })
      rescue ::Authn::IamService::UpdateRelationshipsClient::RequestError => e
        error(iam_error_message(e.reason))
      end

      private

      attr_reader :assignments

      alias_method :request_items, :assignments

      # Returns an error message if the assignment is invalid, otherwise nil.
      def assignment_error(assignment)
        assignee, resource_id, role = assignment.values_at(:assignee, :resource_id, :role)

        # Treat a cross-organization assignee the same as a missing one so the
        # error does not reveal whether the user exists in another organization.
        return s_('ArtifactRegistry|Assignee could not be found.') unless assignee && same_organization?(assignee)

        return s_('ArtifactRegistry|Resource ID must be a valid UUIDv7.') unless ::Gitlab::UUID.v7?(resource_id)

        role_id = Roles.uuid_for(role)
        return format(s_('ArtifactRegistry|Unknown Artifact Registry role: %{role}.'), role: role) unless role_id

        nil
      end

      # Builds the IAM assignment input for an assignment already validated by
      # assignment_error.
      def build_input(assignment)
        assignee, resource_id, role = assignment.values_at(:assignee, :resource_id, :role)

        {
          assignee_id: assignee.id,
          resource_id: resource_id,
          role_id: Roles.uuid_for(role)
        }
      end

      def position_error_format
        s_('ArtifactRegistry|Assignment %{number} on resource %{resource_id}: %{message}')
      end

      # IAM stores one ASSIGNMENT per (subject, object), so a single request
      # cannot grant a user more than one role on the same resource. Catch that
      # here with a clear error rather than letting IAM reject the whole batch.
      # Runs after build_input, so every assignee is present.
      def duplicate_assignments
        assignments
          .group_by { |assignment| [assignment[:assignee].id, assignment[:resource_id]] }
          .values
          .select { |group| group.size > 1 }
      end

      def duplicate_error(duplicates)
        details = duplicates.map do |group|
          roles = group.map { |assignment| assignment[:role].to_s.upcase }.join(', ')
          "#{group.first[:assignee].to_global_id} on resource #{group.first[:resource_id]} (#{roles})"
        end.join("\n")

        message = s_('ArtifactRegistry|A user can hold only one Artifact Registry role per resource. ' \
          'The following are listed more than once.')

        "#{message}\n#{details}"
      end

      def client
        ::Authn::IamService::UpdateRelationshipsClient.new
      end

      def fallback_error_message(reason)
        case reason
        when :permission_denied
          s_('ArtifactRegistry|You are not authorized to grant this role on this resource.')
        when :invalid_request
          s_('ArtifactRegistry|The role assignment request was invalid.')
        else
          s_('ArtifactRegistry|The role assignment could not be completed.')
        end
      end
    end
  end
end
