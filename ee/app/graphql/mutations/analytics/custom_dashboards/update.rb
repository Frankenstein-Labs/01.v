# frozen_string_literal: true

module Mutations
  module Analytics
    module CustomDashboards
      class Update < BaseMutation
        graphql_name 'UpdateCustomDashboard'
        description "Updates a custom dashboard."

        include Gitlab::Graphql::Authorize::AuthorizeResource

        authorize :update_custom_dashboard
        authorize_granular_token permissions: :update_custom_dashboard, boundary: :instance, boundary_type: :instance

        argument :id,
          ::Types::GlobalIDType[::Analytics::CustomDashboards::Dashboard],
          required: true,
          description: "Global ID of the dashboard to update."

        argument :name, GraphQL::Types::String,
          required: false,
          description: "Dashboard name."

        argument :description, GraphQL::Types::String,
          required: false,
          description: "Dashboard description."

        argument :config, Types::Analytics::CustomDashboards::DashboardConfigInputType,
          required: false,
          description: 'Dashboard layout/config.'

        field :dashboard, ::Types::Analytics::CustomDashboards::DashboardType,
          null: true,
          description: "Updated dashboard."

        field :errors, [GraphQL::Types::String],
          null: false,
          description: "Errors encountered during update."

        def resolve(id:, **attributes)
          dashboard = authorized_find!(id: id)

          params = attributes.compact

          response = ::Analytics::CustomDashboards::UpdateService
            .new(current_user: current_user, dashboard: dashboard, params: params)
            .execute

          if response.success?
            { dashboard: response.payload[:dashboard], errors: [] }
          else
            { dashboard: nil, errors: Array(response.message) }
          end
        end

        private

        def find_object(id:)
          GitlabSchema.object_from_id(id, expected_type: ::Analytics::CustomDashboards::Dashboard)
        end
      end
    end
  end
end
