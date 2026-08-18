# frozen_string_literal: true

module Types
  module SecretsManagement
    class GroupSecretsPermissionType < BaseObject
      graphql_name 'GroupSecretsPermission'
      description 'Representation of a group secrets permission.'

      include SecretsPermissionInterface

      authorize :read_secrets_manager

      field :group, Types::GroupType,
        null: false,
        method: :resource,
        description: 'Group the secret permission belong to.'
    end
  end
end
