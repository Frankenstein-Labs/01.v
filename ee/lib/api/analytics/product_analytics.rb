# frozen_string_literal: true

module API
  module Analytics
    class ProductAnalytics < ::API::Base
      before do
        authenticate!
      end

      feature_category :product_analytics
      urgency :low

      helpers do
        def project
          @project ||= find_project!(params[:project_id])
        end

        def render_response(response)
          if response.success?
            status :ok
            response.payload
          else
            render_api_error!(response.message, response.reason)
          end
        end

        def cube_data_query(load_data)
          params = declared_params(include_missing: false).merge(path: load_data ? 'load' : 'dry-run')

          response = ::ProductAnalytics::CubeDataQueryService.new(
            container: project, current_user: current_user, params: params
          ).execute

          render_response(response)
        end

        params :cube_query_params do
          requires :project_id, type: Integer, desc: 'ID of the project to query'
          requires :query,
            type: Hash,
            desc: "A valid Cube query. See reference documentation: https://cube.dev/docs/query-format"
          optional :queryType,
            type: String,
            default: 'multi',
            desc: 'The query type. Currently only "multi" is supported.'
          optional :include_token,
            type: Boolean,
            default: false,
            desc: 'Whether to include the access token in the response. (Only required for funnel generation.)'
        end
      end

      resource :projects, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
        desc 'Create a Cube query request' do
          detail 'Creates a query request to the Cube API for product analytics and generates an access token. ' \
            'Requires the `product_analytics_features` flag to be enabled.'
          tags %w[analytics internal_operations]
        end
        params do
          use :cube_query_params
        end
        route_setting :authorization, permissions: :read_product_analytics,
          boundary_type: :project, boundary_param: :project_id
        post ':project_id/product_analytics/request/load' do
          cube_data_query(true)
        end

        desc 'Create a Cube query request' do
          detail 'Creates a query request to the Cube API and generates an access token.'
          tags %w[analytics internal_operations]
        end
        params do
          use :cube_query_params
        end
        route_setting :authorization, permissions: :read_product_analytics,
          boundary_type: :project, boundary_param: :project_id
        post ':project_id/product_analytics/request/dry-run' do
          cube_data_query(false)
        end

        desc 'Get metadata for analytics.' do
          detail 'Retrieves metadata for analytics from the cube installation'
          tags %w[analytics internal_operations]
        end
        params do
          requires :project_id, type: Integer, desc: 'ID of the project to get meta data'
        end
        route_setting :authorization, permissions: :read_product_analytics,
          boundary_type: :project, boundary_param: :project_id
        post ':project_id/product_analytics/request/meta' do
          params = declared_params(include_missing: false).merge(path: 'meta')

          response = ::ProductAnalytics::CubeDataQueryService.new(
            container: project, current_user: current_user, params: params
          ).execute
          render_response(response)
        end
      end
    end
  end
end
