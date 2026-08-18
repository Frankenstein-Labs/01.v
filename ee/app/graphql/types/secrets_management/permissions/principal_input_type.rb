# frozen_string_literal: true

module Types
  module SecretsManagement
    module Permissions
      class PrincipalInputType < BaseInputObject
        graphql_name 'PrincipalInput'
        description 'Representation of who is provided access to. For eg: User/Role/MemberRole/Group.'

        argument :id, GraphQL::Types::Int,
          required: false,
          description: 'ID of the principal. Required unless group_path is provided for Group type.'

        argument :group_path, GraphQL::Types::ID,
          required: false,
          description: 'Full path of the group principal. Only used when type is GROUP.'

        argument :type, Types::SecretsManagement::Permissions::PrincipalTypeEnum,
          required: true,
          description: 'Type of the principal.'

        validates ::SecretsManagement::Graphql::Validators::PrincipalInputValidator => {}
      end
    end
  end
end
