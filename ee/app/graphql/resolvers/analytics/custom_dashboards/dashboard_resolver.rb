# frozen_string_literal: true

module Resolvers
  module Analytics
    module CustomDashboards
      class DashboardResolver < BaseResolver
        type ::Types::Analytics::CustomDashboards::DashboardType, null: true

        argument :id,
          ::Types::GlobalIDType[::Analytics::CustomDashboards::Dashboard],
          required: true,
          description: 'Dashboard ID.'

        def resolve(id:)
          dashboard = GitlabSchema.object_from_id(id, expected_type: ::Analytics::CustomDashboards::Dashboard)

          ::Gitlab::Graphql::Lazy.with_value(dashboard) do |resolved_dashboard|
            next unless resolved_dashboard
            next unless Ability.allowed?(current_user, :read_custom_dashboard, resolved_dashboard)

            resolved_dashboard
          end
        end
      end
    end
  end
end
