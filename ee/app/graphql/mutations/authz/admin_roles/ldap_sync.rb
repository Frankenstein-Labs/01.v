# frozen_string_literal: true

module Mutations
  module Authz
    module AdminRoles
      class LdapSync < ::Mutations::BaseMutation
        graphql_name 'AdminRolesLdapSync'

        authorize_granular_token permissions: :create_ldap_admin_role_link, boundary: :instance,
          boundary_type: :instance

        field :errors, [GraphQL::Types::String], description: 'Errors encountered during operation.'
        field :success, GraphQL::Types::Boolean, description: 'Whether the sync was successfully enqueued.'

        def ready?(**args)
          raise_resource_not_available_error! unless current_user.can?(:create_ldap_admin_role_link)

          super
        end

        def resolve
          ::Authz::Ldap::AdminRolesSyncService.enqueue_sync

          {
            success: true,
            errors: []
          }
        end
      end
    end
  end
end
