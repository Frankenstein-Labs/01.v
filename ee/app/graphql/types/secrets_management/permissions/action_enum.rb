# frozen_string_literal: true

module Types
  module SecretsManagement
    module Permissions
      class ActionEnum < BaseEnum
        graphql_name 'SecretsManagementAction'
        description 'Actions that can be performed on secrets'

        value 'READ', description: 'Read secrets.',
          value: ::SecretsManagement::BaseSecretsPermission::ACTIONS[:read]
        value 'READ_VALUE', description: 'Read secret values.',
          value: ::SecretsManagement::BaseSecretsPermission::ACTIONS[:read_value]
        value 'WRITE', description: 'Create and update secrets.',
          value: ::SecretsManagement::BaseSecretsPermission::ACTIONS[:write]
        value 'DELETE', description: 'Delete secrets.',
          value: ::SecretsManagement::BaseSecretsPermission::ACTIONS[:delete]
      end
    end
  end
end
