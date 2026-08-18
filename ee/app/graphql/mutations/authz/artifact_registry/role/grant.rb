# frozen_string_literal: true

module Mutations
  module Authz
    module ArtifactRegistry
      module Role
        class Grant < BaseMutation
          graphql_name 'ArtifactRegistryRoleGrant'
          description 'Grants an Artifact Registry role to a user on a resource.'

          argument :assignee_id, ::Types::GlobalIDType[::User],
            required: true,
            description: 'Global ID of the user to grant the role to.'

          argument :resource_id, GraphQL::Types::String,
            required: true,
            description: 'UUID of the Artifact Registry resource (repository or namespace) the role applies to.'

          argument :role, ::Types::Authz::ArtifactRegistry::RoleEnum,
            required: true,
            description: 'Artifact Registry role to grant.'

          def resolve(assignee_id:, resource_id:, role:)
            raise_resource_not_available_error! unless current_user
            raise_resource_not_available_error! unless feature_enabled?

            assignee = GitlabSchema.object_from_id(assignee_id, expected_type: ::User).sync

            result = ::Authz::ArtifactRegistry::GrantRoleAssignmentsService.new(
              current_user: current_user,
              organization: context[:current_organization],
              assignments: [{ assignee: assignee, resource_id: resource_id, role: role }]
            ).execute

            { errors: result.errors }
          end

          private

          def feature_enabled?
            Feature.enabled?(:artifact_registry_role_assignment, current_user)
          end
        end
      end
    end
  end
end
