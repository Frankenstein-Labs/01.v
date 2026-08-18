# frozen_string_literal: true

module Mutations
  module SecretsManagement
    module Helpers
      module PermissionPrincipalHelpers
        extend ActiveSupport::Concern

        def resolve_principal_id(principal)
          unless principal.type == ::SecretsManagement::BaseSecretsPermission::PRINCIPAL_TYPES[:group]
            return principal.id
          end

          # NOTE: Accepting id here is only temporary for backwards compatibility. Will remove it as soon as project
          # secrets permissions have been migrated to accept group_path.
          return principal.id unless principal.id.blank?

          resolved_group = find_group_by_path(principal.group_path)
          return resolved_group.id if resolved_group

          raise Gitlab::Graphql::Errors::ArgumentError,
            "Group '#{principal.group_path}' not found"
        end
      end
    end
  end
end
