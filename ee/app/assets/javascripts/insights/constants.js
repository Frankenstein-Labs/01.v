import { s__, __ } from '~/locale';

export const CHART_TYPES = {
  BAR: 'bar',
  LINE: 'line',
  STACKED_BAR: 'stacked-bar',
  // Only used to convert to bar
  PIE: 'pie',
};

export const EMPTY_STATE_TITLE = __('Invalid Insights config file detected');
export const EMPTY_STATE_DESCRIPTION = __(
  'Please check the configuration file to ensure that it is available and the YAML is valid',
);
export const EMPTY_STATE_SVG_PATH = '/assets/illustrations/empty-state/empty-dashboard-md.svg';

export const INSIGHTS_CONFIGURATION_TEXT = s__(
  'Insights|Configure a custom report for insights into your group processes such as amount of issues, bugs, and merge requests per month. %{linkStart}How do I configure an insights report?%{linkEnd}',
);

export const INSIGHTS_PAGE_FILTERED_OUT = s__(
  'Insights|This project is filtered out in the insights.yml file (see the projects.only config for more information).',
);

export const INSIGHTS_DATA_SOURCE_DORA = 'dora';

export const INSIGHTS_NO_DATA_TOOLTIP = __('No data available');
export const INSIGHTS_REPORT_DROPDOWN_EMPTY_TEXT = __('Select report');

export const ISSUABLE_TYPES = {
  ISSUE: 'issue',
  MERGE_REQUEST: 'merge_request',
};

export const INSIGHTS_CHART_ITEM_TRACKING_CLICK_ACTION = 'insights_chart_item_clicked';

export const INSIGHTS_CHART_ITEM_SETTINGS = {
  [ISSUABLE_TYPES.ISSUE]: {
    groupPathSuffix: '-/issues_analytics',
    projectPathSuffix: '-/analytics/issues_analytics',
    trackingClickAction: 'insights_issue_chart_item_clicked',
  },
  [ISSUABLE_TYPES.MERGE_REQUEST]: {
    groupPathSuffix: '-/analytics/productivity_analytics',
    projectPathSuffix: '-/analytics/merge_request_analytics',
    trackingClickAction: 'insights_merge_request_chart_item_clicked',
  },
};

export const INSIGHTS_CHARTS_SUPPORT_DRILLDOWN = [
  ISSUABLE_TYPES.ISSUE,
  ISSUABLE_TYPES.MERGE_REQUEST,
];
