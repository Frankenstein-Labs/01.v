# frozen_string_literal: true

module Types
  module Members
    class PendingGroupMemberType < BaseObject
      graphql_name 'PendingGroupMember'
      description 'Represents a Pending Group Membership'

      authorize :admin_group_member

      implements PendingMemberInterface
    end
  end
end
