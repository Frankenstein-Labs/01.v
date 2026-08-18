# frozen_string_literal: true

module Types
  module SecretsManagement
    class GroupSecretsManagerType < BaseObject
      graphql_name 'GroupSecretsManager'
      description 'Representation of a group secrets manager.'

      authorize_granular_token permissions: :read_secrets_manager,
        boundary: :group, boundary_type: :group

      authorize :read_group_secrets_manager_status

      expose_permissions Types::PermissionTypes::SecretsManagement::GroupSecretsManager

      field :group,
        Types::GroupType,
        null: false,
        description: 'Group the secrets manager belongs to.'

      # Resolved from `effective_status`, which reports `DEPROVISIONING`
      # whenever a deprovision maintenance task is pending for the
      # group, even if the underlying `status` column on the SM row
      # would otherwise say otherwise. This keeps the reported status
      # honest in the upcoming trigger-based deprovision flow
      # (gitlab-org/gitlab#600290) where the SM row may be deleted
      # before OpenBao cleanup completes.
      field :status,
        Types::SecretsManagement::GroupSecretsManagerStatusEnum,
        method: :effective_status,
        description: 'Status of the group secrets manager.'
    end
  end
end
