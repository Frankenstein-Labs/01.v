# frozen_string_literal: true

module Authz
  module UserRoleAssignable
    extend ActiveSupport::Concern

    class_methods do
      def create_or_update(user:, member_role:, **args)
        find_or_initialize_by(user: user).tap do |record|
          record.update(member_role: member_role, **args)
        end
      end
    end
  end
end
