# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module Permissions
      class Update < BaseMutation
        graphql_name 'SecretPermissionUpdate'

        include ResolvesProject
        include Gitlab::InternalEventsTracking
        include Helpers::ErrorMessagesHelpers
        include ::SecretsManagement::MutationErrorHandling
        include ::SecretsManagement::RequiresActiveNamespace
        include ::SecretsManagement::EnforcesWriteEntitlement

        enforces_write_entitlement_for :secret_permission, find_by: :project_path

        authorize :admin_project_secrets_manager

        argument :project_path, GraphQL::Types::ID,
          required: true,
          description: 'Project to which the permissions are added.'

        argument :principal, Types::SecretsManagement::Permissions::PrincipalInputType,
          required: true,
          description: 'User/MemberRole/Role/Group that is provided access.'

        argument :permissions, [::GraphQL::Types::String],
          required: true,
          description: "Permissions to be provided. ['create', 'update', 'read', 'delete']."

        argument :expired_at, GraphQL::Types::ISO8601Date, required: false,
          description: "Expiration date for Secret Permission (optional)."

        field :secret_permission, Types::SecretsManagement::Permissions::SecretPermissionType,
          null: true,
          description: 'Secret Permission that was created.'

        def resolve(project_path:, principal:, permissions:, expired_at: nil)
          project = authorized_find!(project_path: project_path)
          raise_if_namespace_inactive!(project)

          # Transform old permissions format to new actions format
          actions = permissions_to_actions(permissions)

          result = ::SecretsManagement::ProjectSecretsPermissions::UpdateService
            .new(project, current_user)
            .execute(
              principal_id: principal.id,
              principal_type: principal.type,
              actions: actions,
              expired_at: expired_at
            )

          if result.success?
            track_permission_update_event(project)
            {
              secret_permission: result.payload[:secrets_permission],
              errors: []
            }
          else
            {
              secret_permission: nil,
              errors: error_messages(result, [:secrets_permission])
            }
          end
        end

        private

        def find_object(project_path:)
          resolve_project(full_path: project_path)
        end

        # Convert old permissions format to new actions format
        # Merge 'create' and 'update' into 'write' action
        def permissions_to_actions(permissions)
          actions = []
          perms_set = permissions.to_set

          actions << 'read' if perms_set.include?('read')
          actions << 'write' if perms_set.include?('create') || perms_set.include?('update')
          actions << 'delete' if perms_set.include?('delete')

          actions
        end

        def track_permission_update_event(project)
          track_internal_event(
            'update_project_secrets_permission',
            user: current_user,
            namespace: project.namespace,
            project: project
          )
        end
      end
    end
  end
end
