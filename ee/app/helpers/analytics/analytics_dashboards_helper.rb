# frozen_string_literal: true

module Analytics
  module AnalyticsDashboardsHelper
    def analytics_dashboards_list_app_data(namespace)
      is_project = project?(namespace)
      is_group = group?(namespace)
      can_read_customizable_dashboards = can?(current_user, :read_customizable_dashboards, namespace)

      {
        is_project: is_project.to_s,
        is_group: is_group.to_s,
        collector_host: can_read_customizable_dashboards ? collector_host(namespace) : nil,
        dashboard_empty_state_illustration_path: image_path('illustrations/empty-state/empty-dashboard-md.svg'),
        namespace_name: namespace.name,
        namespace_full_path: namespace.full_path,
        features: is_project ? enabled_analytics_features(namespace).to_json : [].to_json,
        router_base: router_base(namespace),
        overview_counts_aggregation_enabled: overview_counts_aggregation_enabled?(namespace).to_s,
        has_scoped_labels_feature: has_scoped_labels_feature?(namespace).to_s,
        data_source_clickhouse: ::Gitlab::ClickHouse.enabled_for_analytics?(namespace).to_s
      }
    end

    private

    def project?(namespace)
      namespace.is_a?(Project)
    end

    def group?(namespace)
      namespace.is_a?(Group)
    end

    def collector_host(project)
      if project?(project)
        ::ProductAnalytics::Settings.for_project(project).product_analytics_data_collector_host
      else
        ::Gitlab::CurrentSettings.product_analytics_data_collector_host
      end
    end

    def tracking_key(project)
      project.project_setting.product_analytics_instrumentation_key
    end

    def enabled_analytics_features(project)
      [].tap do |features|
        features << :product_analytics if product_analytics_enabled?(project)
      end
    end

    def product_analytics_enabled?(project)
      ::ProductAnalytics::Settings.for_project(project).enabled? &&
        ::Feature.enabled?(:product_analytics_features, project) &&
        project.licensed_feature_available?(:product_analytics) &&
        can?(current_user, :read_customizable_dashboards, project)
    end

    def overview_counts_aggregation_enabled?(namespace)
      root_namespace = namespace.root_ancestor
      return true if root_namespace.value_stream_dashboard_aggregation&.enabled

      false
    end

    def router_base(namespace)
      return project_analytics_dashboards_path(namespace) if project?(namespace)

      group_analytics_dashboards_path(namespace)
    end

    def has_scoped_labels_feature?(namespace)
      namespace.licensed_feature_available?(:scoped_labels)
    end
  end
end
