# frozen_string_literal: true

module Types
  module Analytics
    module CustomDashboards
      class DashboardConfigInputType < Types::BaseInputObject
        graphql_name 'CustomDashboardConfigInput'
        description 'Configuration input for a custom analytics dashboard.'

        class GridHeightEnum < Types::BaseEnum
          graphql_name 'CustomDashboardGridHeight'
          description 'Grid height display mode for the dashboard.'

          value 'DEFAULT', value: 'default', description: 'Default grid height.'
          value 'COMPACT', value: 'compact', description: 'Compact grid height.'
        end

        class DashboardStatusEnum < Types::BaseEnum
          graphql_name 'CustomDashboardStatus'
          description 'Maturity status of the dashboard.'

          value 'BETA',       value: 'beta',       description: 'Dashboard is in beta.'
          value 'EXPERIMENT', value: 'experiment', description: 'Dashboard is experimental.'
        end

        class DateRangeOptionEnum < Types::BaseEnum
          graphql_name 'CustomDashboardDateRangeOption'
          description 'Preset date range options available for dashboard filters.'

          value 'TODAY',    value: 'today',  description: 'Current day.'
          value 'CUSTOM',   value: 'custom', description: 'Custom date range.'
          value 'DAYS_7',   value: '7d',     description: 'Last 7 days.'
          value 'DAYS_30',  value: '30d',    description: 'Last 30 days.'
          value 'DAYS_60',  value: '60d',    description: 'Last 60 days.'
          value 'DAYS_90',  value: '90d',    description: 'Last 90 days.'
          value 'DAYS_180', value: '180d',   description: 'Last 180 days.'
          value 'DAYS_365', value: '365d',   description: 'Last 365 days.'
        end

        class FilteredSearchTokenEnum < Types::BaseEnum
          graphql_name 'CustomDashboardFilteredSearchToken'
          description 'Token types available for filtered search.'

          value 'ASSIGNEE',      value: 'assignee',      description: 'Filter by assignee.'
          value 'AUTHOR',        value: 'author',        description: 'Filter by author.'
          value 'LABEL',         value: 'label',         description: 'Filter by label.'
          value 'MILESTONE',     value: 'milestone',     description: 'Filter by milestone.'
          value 'TARGET_BRANCH', value: 'target_branch', description: 'Filter by target branch.'
          value 'SOURCE_BRANCH', value: 'source_branch', description: 'Filter by source branch.'
        end

        class FilteredSearchOperatorEnum < Types::BaseEnum
          graphql_name 'CustomDashboardFilteredSearchOperator'
          description 'Comparison operators for filtered search tokens.'

          value 'IS',        value: 'is',        description: 'Matches the given value.'
          value 'IS_NOT',    value: 'is_not',    description: 'Does not match the given value.'
          value 'IS_NOT_OR', value: 'is_not_or', description: 'Does not match any of the given values.'
        end

        class GridAttributesInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardGridAttributesInput'
          description 'Position and size of a panel within the dashboard grid.'

          argument :height,     Integer, required: true,  description: 'Number of grid rows the panel spans.'
          argument :max_height, Integer, required: false, description: 'Maximum height the panel can be resized to.'
          argument :max_width,  Integer, required: false, description: 'Maximum width the panel can be resized to.'
          argument :min_height, Integer, required: false, description: 'Minimum height the panel can be resized to.'
          argument :min_width,  Integer, required: false, description: 'Minimum width the panel can be resized to.'
          argument :width,      Integer, required: true,  description: 'Number of grid columns the panel spans.'
          argument :x_pos,      Integer, required: false, description: 'Horizontal grid position of the panel.'
          argument :y_pos,      Integer, required: false, description: 'Vertical grid position of the panel.'
        end

        class PanelOptionsInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardPanelOptionsInput'
          description 'Display options for a dashboard panel.'

          argument :decimal_places, Integer, required: false,
            description: 'Number of decimal places to display for numeric values.'
        end

        class QueryFiltersInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardQueryFiltersInput'
          description 'Filters applied to the underlying visualization query.'

          argument :exclude_metrics, [String], required: false, description: 'Metrics to exclude from the query.'
          argument :include,         [String], required: false, description: 'Additional include filters.'
          argument :include_metrics, [String], required: false, description: 'Metrics to include in the query.'
          argument :labels,          [String], required: false, description: 'Labels to filter by.'
          argument :project_topics,  [String], required: false, description: 'Project topics to filter by.'
        end

        class QueryOverridesInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardQueryOverridesInput'
          description 'Overrides applied to the visualization query at the panel level.'

          argument :filters,   QueryFiltersInputType, required: false, description: 'Query filter overrides.'
          argument :namespace, String,                required: false, description: 'Namespace override for the query.'
          # rubocop:todo Graphql/JSONType -- timeDimensions has no defined shape in the schema yet
          argument :time_dimensions, GraphQL::Types::JSON, required: false,
            description: 'Time dimension overrides for the query.'
          # rubocop:enable Graphql/JSONType
        end

        class TooltipInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardTooltipInput'
          description 'Tooltip displayed on a dashboard panel.'

          argument :description, String, required: true,
            description: 'Tooltip text. Must include %{linkStart} and %{linkEnd} if descriptionLink is set.'
          argument :description_link, String, required: false,
            description: 'URI linked from within the tooltip description.'
        end

        class PanelInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardPanelInput'
          description 'Single panel within a custom dashboard.'

          argument :grid_attributes, GridAttributesInputType, required: true,
            description: 'Grid position and size of the panel.'
          argument :options,         PanelOptionsInputType,   required: false,
            description: 'Display options for the panel.'
          argument :query_overrides, QueryOverridesInputType, required: false,
            description: 'Query overrides applied to the visualization.'
          argument :title,           String,                  required: true,
            description: 'Display title of the panel.'
          argument :tooltip,         TooltipInputType,        required: false,
            description: 'Tooltip for the panel.'
          argument :visualization,   String,                  required: false,
            description: 'ID of an existing visualization to render.'
          # rubocop:todo Graphql/JSONType -- input is validated against schema file: ee/app/validators/json_schemas/analytics_visualization.json
          argument :visualization_config, GraphQL::Types::JSON, required: false,
            description: 'Inline visualization config object to render.'
          # rubocop:enable Graphql/JSONType

          validates exactly_one_of: [:visualization, :visualization_config]
        end

        class DashboardFilterInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardFilterInput'
          description 'Toggleable dashboard-level filter.'

          argument :enabled, Boolean, required: false, description: 'Whether the filter is enabled.'
        end

        class FilteredSearchFilterOptionInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardFilteredSearchFilterOptionInput'
          description 'Configuration for a single filtered search token.'

          argument :max_suggestions, Float,                      required: false,
            description: 'Maximum number of suggestions to display.'
          argument :operator,        FilteredSearchOperatorEnum, required: false,
            description: 'Comparison operator for the token.'
          argument :token,           FilteredSearchTokenEnum,    required: true,
            description: 'Token type for the filter option.'
          argument :unique,          Boolean,                    required: false,
            description: 'Whether only one value can be selected for the token.'
        end

        class FilteredSearchFilterInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardFilteredSearchFilterInput'
          description 'Filtered search filter configuration for the dashboard.'

          argument :enabled, Boolean,                               required: false,
            description: 'Whether filtered search is enabled.'
          argument :options, [FilteredSearchFilterOptionInputType], required: false,
            description: 'Token options available in the filtered search.'
        end

        class DateRangeFilterInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardDateRangeFilterInput'
          description 'Date range filter configuration for the dashboard.'

          argument :default_option,       DateRangeOptionEnum,   required: false,
            description: 'Default selected date range option.'
          argument :enabled,              Boolean,               required: false,
            description: 'Whether the date range filter is enabled.'
          argument :number_of_days_limit, Float,                 required: false,
            description: 'Maximum number of days allowed in a custom range.'
          argument :options,              [DateRangeOptionEnum], required: false,
            description: 'Preset date range options to display.'
        end

        class DashboardFiltersInputType < Types::BaseInputObject
          graphql_name 'CustomDashboardFiltersInput'
          description 'Filter controls available on the dashboard.'

          argument :date_range,              DateRangeFilterInputType,      required: false,
            description: 'Date range filter configuration.'
          argument :exclude_anonymous_users, DashboardFilterInputType,      required: false,
            description: 'Filter to exclude anonymous users from metrics.'
          argument :filtered_search,         FilteredSearchFilterInputType, required: false,
            description: 'Filtered search configuration.'
          argument :projects,                DashboardFilterInputType,      required: false,
            description: 'Project filter configuration.'
        end

        argument :description, String,                    required: false,
          description: 'Description of the dashboard.'
        argument :filters,     DashboardFiltersInputType, required: false,
          description: 'Filter controls available on the dashboard.'
        argument :grid_height, GridHeightEnum,            required: false,
          description: 'Grid height display mode.'
        argument :panels,      [PanelInputType],          required: true,
          description: 'Panels to display on the dashboard.'
        argument :status,      DashboardStatusEnum,       required: false,
          description: 'Maturity status of the dashboard.'
        argument :title,       String,                    required: true,
          description: 'Display title of the dashboard.'

        def prepare
          config = to_h
            .deep_transform_keys { |k| k.to_s.camelize(:lower) }
            .merge('version' => '2')

          # A panel supplies its visualization either as a string reference
          # (`visualization`) or an inline config object (`visualizationConfig`).
          # The persisted config carries both shapes under a single
          # `visualization` key, so fold the inline config into it here.
          Array(config['panels']).each do |panel|
            next unless panel.is_a?(Hash)

            inline_config = panel.delete('visualizationConfig')
            panel['visualization'] = inline_config if inline_config
          end

          config
        end
      end
    end
  end
end
