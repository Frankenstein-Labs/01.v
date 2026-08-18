# frozen_string_literal: true

module Types
  module Members
    class PendingProjectMemberType < BaseObject
      graphql_name 'PendingProjectMember'
      description 'Represents a Pending Project Membership'

      authorize :admin_project_member

      implements PendingMemberInterface
    end
  end
end
