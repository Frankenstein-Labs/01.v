# frozen_string_literal: true

module SecretsManagement
  module Graphql
    module Validators
      class PrincipalInputValidator < ::GraphQL::Schema::Validator
        def validate(_object, _context, data)
          if data[:type] == ::SecretsManagement::BaseSecretsPermission::PRINCIPAL_TYPES[:group]
            validate_principal_group_input(data)
          else
            validate_principal_input(data)
          end
        end

        private

        def validate_principal_group_input(data)
          # NOTE: Accepting id here is only temporary for backwards compatibility. Will remove it as soon as project
          # secrets permissions have been migrated to accept group_path.
          return unless data[:id].blank? && data[:group_path].blank?

          'Either id or group_path must be provided to identify the principal group'
        end

        def validate_principal_input(data)
          return unless data[:id].blank?

          'id must be provided to identify the principal'
        end
      end
    end
  end
end
