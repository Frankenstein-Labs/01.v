# frozen_string_literal: true

module Types
  module Members
    class CustomizableAdminPermissionsEnum < BaseEnum
      graphql_name 'MemberRoleAdminPermission'
      description 'Member role admin permission'

      MemberRole.all_customizable_admin_permissions.each_pair do |key, attrs|
        value key.upcase, value: key, description: attrs[:description]
      end
    end
  end
end
