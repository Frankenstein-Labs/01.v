# frozen_string_literal: true

module Resolvers
  module Cd
    class OrganizationEnvironmentsResolver < BaseResolver
      type ::Types::Cd::EnvironmentType.connection_type, null: true

      MAX_PAGE_SIZE = 100

      max_page_size MAX_PAGE_SIZE

      argument :tier, ::Types::Cd::EnvironmentTierEnum,
        required: false,
        description: 'Filter environments by tier.'

      argument :search, GraphQL::Types::String,
        required: false,
        description: 'Search environments by name or description.'

      def resolve(tier: nil, search: nil)
        return unless Feature.enabled?(:ai_native_deploy, current_user)
        return unless current_user&.can?(:read_cd_environment, object)

        environments = ::Cd::Environment.in_organization(object)
        environments = environments.with_tier(tier) if tier
        environments = environments.search(search) if search.present?
        environments
      end
    end
  end
end
