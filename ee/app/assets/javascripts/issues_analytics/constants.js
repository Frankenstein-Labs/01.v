import { BLUE_400, GREEN_400 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { s__ } from '~/locale';

export const DEFAULT_MONTHS_BACK = 12;

export const NAMESPACE_PROJECT_TYPE = 'project';

export const NO_DATA_EMPTY_STATE_TYPE = 'noData';
export const NO_DATA_WITH_FILTERS_EMPTY_STATE_TYPE = 'noDataWithFilters';

export const ISSUES_OPENED_COUNT_ALIAS = 'issuesOpenedCounts';
export const ISSUES_COMPLETED_COUNT_ALIAS = 'issuesClosedCounts';

export const TOTAL_ISSUES_ANALYTICS_CHART_SERIES_NAMES = {
  [ISSUES_OPENED_COUNT_ALIAS]: s__('IssuesAnalytics|Opened'),
  [ISSUES_COMPLETED_COUNT_ALIAS]: s__('IssuesAnalytics|Closed'),
};

export const ISSUES_ANALYTICS_METRIC_TYPES = {
  [ISSUES_OPENED_COUNT_ALIAS]: 'issueCount',
  [ISSUES_COMPLETED_COUNT_ALIAS]: 'issuesCompletedCount',
};

export const TOTAL_ISSUES_ANALYTICS_CHART_COLOR_PALETTE = [GREEN_400, BLUE_400];
