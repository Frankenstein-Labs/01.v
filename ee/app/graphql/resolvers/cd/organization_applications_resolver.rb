# frozen_string_literal: true

module Resolvers
  module Cd
    class OrganizationApplicationsResolver < BaseResolver
      include LooksAhead

      type ::Types::Cd::ApplicationType.connection_type, null: true

      argument :search, GraphQL::Types::String,
        required: false,
        description: 'Search applications by name or description.'

      argument :statuses, [::Types::Cd::ApplicationStatusEnum],
        required: false,
        description: 'Filter applications by status. An application can match more than one status.'

      def resolve_with_lookahead(search: nil, statuses: nil, **)
        return unless Feature.enabled?(:ai_native_deploy, current_user)
        return unless current_user&.can?(:read_cd_application, object)

        applications = ::Cd::Application.in_organization(object)
        applications = applications.search(search) if search.present?
        applications = applications.with_statuses(statuses, organization: object) if statuses.present?

        apply_lookahead(applications)
      end

      private

      def preloads
        {
          services: [:services],
          version_sets: [:version_sets],
          rollouts: [:rollouts],
          application_flow_definitions: [:application_flow_definitions],
          links: [:application_links]
        }
      end
    end
  end
end
