/**
 * Imports an analytics dashboard datasource
 *
 * A datasource is a file that exports a single default `fetch` function with the following signature:
 *
 * @param {Object} options - The options object
 * @param {string} options.title - The title of the project
 * @param {string} options.namespace - // the namespace full path
 * @param {Object} options.query - The query object for fetching data including any optional overrides that have been applied. Refer to `QueryOverrides` in `ee/app/validators/json_schemas/analytics_visualization.json`. This can also be changed by the visualization at runtime.
 * @param {string} options.visualizationType - The type of visualization to render (line chart, table, etc.). Refer to `AnalyticsVisualization.type` in `ee/app/validators/json_schemas/analytics_visualization.json`
 * @param {Object} options.visualizationOptions - Additional options for customizing the visualization Refer to `Options` in `ee/app/validators/json_schemas/analytics_visualization.json`
 * @param {Object} [options.filters={}] - Optional filters to apply to the query. The filter object contains:
 *
 *   - startDate {Date} - Start date for the filter
 *   - endDate {Date} - End date for the filter
 *   - dateRangeOption {string} - Selected date range option key
 *   - filterAnonUsers {boolean} - Whether to filter anonymous users
 *   - searchFilters {Object} - Parsed search filters
 *   - projectFullPath {string|null} - Project full path or null
 *
 * @param {Function} [options.onRequestDelayed=()=>{}] - Callback function when request is delayed. It can trigger a loading spinner in the panel
 * @param {Function} [options.setAlerts=()=>{}] - Callback function to set alerts
 * @param {Function} [options.setVisualizationOverrides=()=>{}] - Callback function to set visualization options before render but after the data fetch, allowing us to include fetched data in the visualization options
 *
 * @returns {Promise<Array|Object>} The formatted data for the specified visualization type
 *
 * @throws {Error} If the API request fails
 *
 * export default async function fetch(options);
 *
 */

import fossDataSources from '~/analytics/analytics_dashboards/data_sources';

export default {
  ...fossDataSources,
  cube_analytics: () => import('./cube_analytics'),
  value_stream: () => import('./value_stream'),
  usage_overview: () => import('./usage_overview'),
  usage_count: () => import('./usage_count'),
  dora_metrics: () => import('./dora_metrics'),
  dora_metrics_by_project: () => import('./dora_metrics_by_project'),
  ai_agent_platform_flow_metrics: () => import('./ai_agent_platform_flow_metrics'),
  ai_agent_platform_flows_usage_by_user: () => import('./ai_agent_platform_flows_usage_by_user'),
  ai_impact_over_time: () => import('./ai_impact_over_time'),
  contributions: () => import('./contributions'),
  namespace_metadata: () => import('./namespace_metadata'),
  code_suggestions_acceptance_by_language: () =>
    import('./code_suggestions_acceptance_by_language'),
  code_suggestions_acceptance_by_ide: () => import('./code_suggestions_acceptance_by_ide'),
  code_generation_volume_over_time: () => import('./code_generation_volume_over_time'),
  user_ai_usage_data: () => import('./user_ai_usage_data'),
  code_review_requests_by_role_over_time: () => import('./code_review_requests_by_role_over_time'),
  code_review_comments_sentiment_over_time: () =>
    import('./code_review_comments_sentiment_over_time'),
  duo_feature_usage: () => import('./duo_feature_usage'),
  finished_pipelines_using_dap_over_time: () => import('./finished_pipelines_using_dap_over_time'),
  duo_feature_user_retention_over_time: () => import('./duo_feature_user_retention_over_time'),
};
