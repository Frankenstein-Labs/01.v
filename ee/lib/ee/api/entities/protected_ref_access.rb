# frozen_string_literal: true

module EE
  module API
    module Entities
      module ProtectedRefAccess
        extend ActiveSupport::Concern

        prepended do
          expose :user_id, documentation: { type: 'Integer', format: 'int64', example: 1 }
          expose :group_id, documentation: { type: 'Integer', format: 'int64', example: 1 }

          with_options if: ->(access, _opts) {
            access.respond_to?(:member_role) &&
              access.custom_roles_for_protected_branches_enabled?
          } do
            expose :member_role_id,
              documentation: { type: 'Integer', format: 'int64', example: 42 }

            expose :member_role_name,
              documentation: { type: 'String', example: 'Lead Developer' } do |access|
                access.member_role&.name
              end
          end
        end
      end
    end
  end
end
