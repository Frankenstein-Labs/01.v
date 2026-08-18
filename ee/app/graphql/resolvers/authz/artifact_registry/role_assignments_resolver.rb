# frozen_string_literal: true

module Resolvers
  module Authz
    module ArtifactRegistry
      # Reads Artifact Registry role assignments through
      # LookupRoleAssignmentsService and surfaces IAM's keyset pagination as a
      # Relay connection, carrying its opaque page_token as the cursor.
      class RoleAssignmentsResolver < BaseResolver
        include ::Gitlab::Graphql::Authorize::AuthorizeResource

        type ::Types::Authz::ArtifactRegistry::RoleAssignmentType.connection_type, null: true

        # The page fetched from IAM must be the page the connection renders:
        # the connection cuts nodes at the field's max_page_size while the end
        # cursor comes from IAM, so fetching more than we render would silently
        # drop the difference. This bounds both sides to the same number.
        MAX_PAGE_SIZE = 100

        argument :resource_ids, [GraphQL::Types::String],
          required: false,
          default_value: [],
          description: 'UUIDs of the Artifact Registry resources to read role assignments for. ' \
            'Empty reads the whole organization, which only the organization owner may do.'

        argument :roles, [::Types::Authz::ArtifactRegistry::RoleEnum],
          required: false,
          default_value: [],
          description: 'Only return assignments for these roles.'

        # first/after drive IAM's page_size/page_token. Keyset paging is
        # forward-only, so the field mounts the forward-only connection
        # extension and last/before do not exist on the schema.
        def resolve(resource_ids:, roles:, first: nil, after: nil)
          raise_resource_not_available_error! unless current_user
          raise_resource_not_available_error! unless feature_enabled?

          result = ::Authz::ArtifactRegistry::LookupRoleAssignmentsService.new(
            current_user: current_user,
            organization: context[:current_organization],
            objects: resource_ids.map { |id| { resource_id: id, ancestor_ids: [] } },
            roles: roles,
            page_size: [first, MAX_PAGE_SIZE].compact.min,
            page_after: after
          ).execute

          raise_resource_not_available_error!(result.message) unless result.success?

          ::Gitlab::Graphql::ExternallyPaginatedArray.new(
            after,
            result.payload[:next_page_token],
            *result.payload[:role_assignments]
          )
        end

        private

        def feature_enabled?
          Feature.enabled?(:artifact_registry_role_assignment, current_user)
        end
      end
    end
  end
end
