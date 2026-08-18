// Registers EE-only visualizations on top of the FOSS registry.
// FOSS is the source of truth — its entries are spread in first.
import ceVisualizations from '~/analytics/analytics_dashboards/components/visualizations';

export default {
  ...ceVisualizations,
  ColumnChart: () => import('./column_chart.vue'),
  StackedColumnChart: () => import('./stacked_column_chart.vue'),
  BarChart: () => import('./bar_chart.vue'),
  DORAChart: () => import('./dora_chart.vue'),
  UsageOverview: () => import('./usage_overview.vue'),
  DoraPerformersScore: () => import('./dora_performers_score.vue'),
  DoraProjectsComparison: () => import('./dora_projects_comparison.vue'),
  AiImpactTable: () => import('./ai_impact_table.vue'),
  ContributionsPushesChart: () => import('./contributions/contributions_pushes_chart.vue'),
  ContributionsMergeRequestsChart: () =>
    import('./contributions/contributions_merge_requests_chart.vue'),
  ContributionsIssuesChart: () => import('./contributions/contributions_issues_chart.vue'),
  ContributionsByUserTable: () => import('./contributions/contributions_by_user_table.vue'),
  NamespaceMetadata: () => import('./namespace_metadata.vue'),
};
