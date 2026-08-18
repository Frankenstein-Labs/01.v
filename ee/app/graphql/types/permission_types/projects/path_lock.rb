# frozen_string_literal: true

module Types
  module PermissionTypes
    module Projects
      class PathLock < BasePermissionType
        graphql_name 'PathLockPermissions'

        ability_field :destroy_path_lock
      end
    end
  end
end
