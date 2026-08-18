# frozen_string_literal: true

module Resolvers
  module Cd
    class OrganizationAvailableDeployDriversResolver < BaseResolver
      type [GraphQL::Types::String], null: true

      def resolve
        return unless Feature.enabled?(:ai_native_deploy, current_user)
        return unless current_user&.can?(:read_cd_environment, object)

        ::Cd::DeployDrivers::Registry.driver_refs
      end
    end
  end
end
