# frozen_string_literal: true

module Projects
  module Analytics
    class DashboardsController < Projects::ApplicationController
      include ProductAnalyticsTracking

      feature_category :product_analytics

      before_action :dashboards_enabled!, only: [:index]
      before_action :authorize_read_customizable_dashboards!
      before_action :authorize_read_project_level_analytics_dashboard!
      before_action do
        [:read_dora4_analytics, :read_cycle_analytics, :read_security_resource].each do |ability|
          push_frontend_ability(ability: ability, resource: project, user: current_user)
        end

        [:dora4_analytics, :security_dashboard].each do |license|
          push_licensed_feature(license, project)
        end
      end

      before_action :track_usage, only: [:index], if: :viewing_single_dashboard?

      def index; end

      private

      def dashboards_enabled!
        render_404 unless project.licensed_feature_available?(:project_level_analytics_dashboard) &&
          !project.personal?
      end

      def viewing_single_dashboard?
        params[:vueroute].present?
      end

      def track_usage
        Gitlab::InternalEvents.track_event(
          'analytics_dashboard_viewed',
          project: project,
          user: current_user
        )
      end
    end
  end
end
