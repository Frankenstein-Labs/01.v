# frozen_string_literal: true

module Types
  module SecretsManagement
    class ProjectSecretsManagerType < BaseObject
      graphql_name 'ProjectSecretsManager'
      description 'Representation of a project secrets manager.'

      authorize_granular_token permissions: :read_secrets_manager,
        boundary: :project, boundary_type: :project

      authorize :read_project_secrets_manager_status

      expose_permissions Types::PermissionTypes::SecretsManagement::ProjectSecretsManager

      field :project,
        Types::ProjectType,
        null: false,
        description: 'Project the secrets manager belong to.'

      # Resolved from `effective_status`, which reports `DEPROVISIONING`
      # whenever a deprovision maintenance task is pending for the
      # project, even if the underlying `status` column on the SM row
      # would otherwise say otherwise. This keeps the reported status
      # honest in the upcoming trigger-based deprovision flow
      # (gitlab-org/gitlab#600290) where the SM row may be deleted
      # before OpenBao cleanup completes.
      field :status,
        Types::SecretsManagement::ProjectSecretsManagerStatusEnum,
        method: :effective_status,
        description: 'Status of the project secrets manager.'
    end
  end
end
