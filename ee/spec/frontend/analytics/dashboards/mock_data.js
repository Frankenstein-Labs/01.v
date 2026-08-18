import { isUndefined } from 'lodash-es';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { nMonthsBefore } from '~/lib/utils/datetime_utility';
import { TREND_STYLE_DESC } from 'ee/analytics/dashboards/constants';

const METRIC_IDENTIFIERS = [
  'lead_time_for_changes',
  'time_to_restore_service',
  'change_failure_rate',
  'deployment_frequency',
  'lead_time',
  'cycle_time',
  'issues',
  'issues_completed',
  'deploys',
  'contributor_count',
  'vulnerability_critical',
  'vulnerability_high',
  'merge_request_throughput',
  'median_time_to_merge',
];

const hasValue = (obj, key) => !isUndefined(obj[key]) && obj[key] !== null;

const mockMetrics = (mockValues = {}) =>
  METRIC_IDENTIFIERS.filter((identifier) => hasValue(mockValues, identifier)).reduce(
    (data, identifier) => ({
      ...data,
      [identifier]: {
        identifier,
        value: mockValues[identifier],
      },
    }),
    {},
  );

const THIS_MONTH = {
  key: 'thisMonth',
  label: 'Month to date',
  start: new Date('2020-07-01T00:00:00.000Z'),
  end: new Date('2020-07-06T00:00:00.000Z'),
  thClass: 'gl-w-1/5',
};

const LAST_MONTH = {
  key: 'lastMonth',
  label: 'June',
  start: new Date('2020-06-01T00:00:00.000Z'),
  end: new Date('2020-06-30T23:59:59.000Z'),
  thClass: 'gl-w-1/5',
};

const TWO_MONTHS_AGO = {
  key: 'twoMonthsAgo',
  label: 'May',
  start: new Date('2020-05-01T00:00:00.000Z'),
  end: new Date('2020-05-31T23:59:59.000Z'),
  thClass: 'gl-w-1/5',
};

const THREE_MONTHS_AGO = {
  key: 'threeMonthsAgo',
  label: 'April',
  start: new Date('2020-04-01T00:00:00.000Z'),
  end: new Date('2020-04-30T23:59:59.000Z'),
};

export const MOCK_TABLE_TIME_PERIODS = [THIS_MONTH, LAST_MONTH, TWO_MONTHS_AGO, THREE_MONTHS_AGO];

// Generate the chart time periods, starting with the oldest first:
// 5 months ago -> 4 months ago -> etc.
export const MOCK_CHART_TIME_PERIODS = [5, 4, 3, 2, 1, 0].map((monthsAgo, index) => ({
  end: monthsAgo === 0 ? THIS_MONTH.end : nMonthsBefore(THIS_MONTH.end, monthsAgo),
  start: nMonthsBefore(THIS_MONTH.end, monthsAgo + 1),
  key: `chart-period-${index}`,
}));

export const MOCK_DASHBOARD_TABLE_FIELDS = [
  {
    key: 'metric',
    label: 'Metric',
    thClass: 'gl-w-1/4',
  },
  ...MOCK_TABLE_TIME_PERIODS.slice(0, -1).reverse(),
  {
    key: 'chart',
    label: 'Past 6 Months',
    start: new Date('2020-01-06T00:00:00.000Z'),
    end: new Date('2020-07-06T00:00:00.000Z'),
    thClass: 'gl-w-3/20',
    tdClass: '!gl-py-2',
  },
];

export const mockMonthToDate = mockMetrics({
  lead_time_for_changes: 0.5,
  time_to_restore_service: 0.05,
  change_failure_rate: 0.005,
  deployment_frequency: 0,
  lead_time: 2,
  cycle_time: 4,
  issues: 6,
  issues_completed: 10080,
  deploys: 8,
  contributor_count: 5,
  vulnerability_critical: 3,
  vulnerability_high: 0,
  merge_request_throughput: 5,
  median_time_to_merge: 0,
});

export const mockMonthToDateTimePeriod = { ...THIS_MONTH, ...mockMonthToDate };

export const mockPreviousMonth = mockMetrics({
  lead_time_for_changes: 3.6,
  time_to_restore_service: 20,
  change_failure_rate: 4,
  deployment_frequency: 2,
  lead_time: 4,
  cycle_time: '-',
  issues: 12,
  issues_completed: 9000,
  deploys: 16,
  contributor_count: 10,
  vulnerability_critical: 0,
  vulnerability_high: 3,
  merge_request_throughput: 2,
  median_time_to_merge: 2,
});
export const mockPreviousMonthTimePeriod = { ...LAST_MONTH, ...mockPreviousMonth };

export const mockTwoMonthsAgo = mockMetrics({
  lead_time_for_changes: 9.2,
  time_to_restore_service: 32,
  change_failure_rate: 8,
  deployment_frequency: 4,
  lead_time: 2,
  cycle_time: '-',
  issues: 6,
  issues_completed: 6000,
  deploys: 8,
  contributor_count: 5,
  vulnerability_critical: 2,
  vulnerability_high: 0,
  merge_request_throughput: 0,
});
export const mockTwoMonthsAgoTimePeriod = { ...TWO_MONTHS_AGO, ...mockTwoMonthsAgo };

export const mockThreeMonthsAgo = mockMetrics({
  lead_time_for_changes: 20.1,
  time_to_restore_service: 32,
  change_failure_rate: 8,
  deployment_frequency: 2,
  lead_time: 4,
  cycle_time: 8,
  issues: 12,
  issues_completed: 8000,
  deploys: 16,
  contributor_count: 10,
  vulnerability_critical: 0,
  vulnerability_high: 0,
  merge_request_throughput: 15,
  median_time_to_merge: 15,
});
export const mockThreeMonthsAgoTimePeriod = { ...THREE_MONTHS_AGO, ...mockThreeMonthsAgo };

export const mockChartsTimePeriods = MOCK_CHART_TIME_PERIODS.map((timePeriod, i) => ({
  ...timePeriod,
  ...mockMetrics({
    lead_time_for_changes: '-',
    time_to_restore_service: 0,
    change_failure_rate: 0,
    deployment_frequency: i,
    lead_time: i + 1,
    cycle_time: i * 2,
    issues: 100 - i * 2,
    issues_completed: 200 - i * 2,
    deploys: i * i,
    contributor_count: i * 3,
    vulnerability_critical: i % 4,
    vulnerability_high: i % 2,
    merge_request_throughput: i,
    median_time_to_merge: 0,
  }),
}));

export const mockSubsetChartsTimePeriods = MOCK_CHART_TIME_PERIODS.slice(4).map(
  (timePeriod, i) => ({
    ...timePeriod,
    ...mockMetrics({ lead_time_for_changes: i + 1, time_to_restore_service: 100 - i }),
  }),
);

export const mockComparativeTableData = [
  {
    metric: {
      value: 'Deployment frequency',
      identifier: 'deployment_frequency',
    },
    thisMonth: {
      value: '0.0/d',
      change: 0,
    },
    lastMonth: {
      value: '2.0/d',
      change: -0.5,
    },
    twoMonthsAgo: {
      value: '4.0/d',
      change: 1,
    },
  },
  {
    metric: {
      value: 'Lead time for changes',
      identifier: 'lead_time_for_changes',
    },
    trendStyle: TREND_STYLE_DESC,
    thisMonth: {
      value: '0.5 d',
      change: -0.8611111111111112,
    },
    lastMonth: {
      value: '3.6 d',
      change: -0.6086956521739131,
    },
    twoMonthsAgo: {
      value: '9.2 d',
      change: -0.5422885572139304,
    },
  },
  {
    metric: {
      value: 'Time to restore service',
      identifier: 'time_to_restore_service',
    },
    trendStyle: TREND_STYLE_DESC,
    thisMonth: {
      value: '0.05 d',
      change: -0.9974999999999999,
    },
    lastMonth: {
      value: '20.0 d',
      change: -0.375,
    },
    twoMonthsAgo: {
      value: '32.0 d',
      change: 0,
    },
  },
  {
    metric: {
      value: 'Change failure rate',
      identifier: 'change_failure_rate',
    },
    trendStyle: TREND_STYLE_DESC,
    thisMonth: {
      value: '0.005%',
      change: -0.99875,
    },
    lastMonth: {
      value: '4.0%',
      change: -0.5,
    },
    twoMonthsAgo: {
      value: '8.0%',
      change: 0,
    },
  },
  {
    metric: {
      value: 'Lead time',
      identifier: 'lead_time',
    },
    trendStyle: TREND_STYLE_DESC,
    lastMonth: {
      change: 1,
      value: '4.0 d',
    },
    thisMonth: {
      change: -0.5,
      value: '2.0 d',
    },
    twoMonthsAgo: {
      change: -0.5,
      value: '2.0 d',
    },
  },
  {
    metric: {
      value: 'Cycle time',
      identifier: 'cycle_time',
    },
    trendStyle: TREND_STYLE_DESC,
    lastMonth: {
      change: 0,
      value: '-',
    },
    thisMonth: {
      change: 0,
      value: '4.0 d',
    },
    twoMonthsAgo: {
      change: 0,
      value: '-',
    },
  },
  {
    metric: {
      value: 'Issues created',
      identifier: 'issues',
    },
    lastMonth: {
      change: 1,
      value: 12,
    },
    thisMonth: {
      change: -0.5,
      value: 6,
    },
    twoMonthsAgo: {
      change: -0.5,
      value: 6,
    },
  },
  {
    metric: {
      value: 'Issues closed',
      identifier: 'issues_completed',
    },
    valueLimit: {
      max: 10001,
      mask: '10000+',
      description:
        'This is a lower-bound approximation. Your group has too many issues and MRs to calculate in real time.',
    },
    lastMonth: {
      change: 0.5,
      value: 9000,
    },
    thisMonth: {
      change: 0.12,
      value: '10000+',
      valueLimitMessage:
        'This is a lower-bound approximation. Your group has too many issues and MRs to calculate in real time.',
    },
    twoMonthsAgo: {
      change: -0.25,
      value: 6000,
    },
  },
  {
    metric: {
      value: 'Deploys',
      identifier: 'deploys',
    },
    lastMonth: {
      change: 1,
      value: 16,
    },
    thisMonth: {
      change: -0.5,
      value: 8,
    },
    twoMonthsAgo: {
      change: -0.5,
      value: 8,
    },
  },
  {
    metric: {
      identifier: 'merge_request_throughput',
      value: 'Merge request throughput',
    },
    lastMonth: {
      change: 0,
      value: 2,
    },
    thisMonth: {
      change: 1.5,
      value: 5,
    },
    twoMonthsAgo: {
      change: 0,
      value: 0,
    },
  },
  {
    metric: {
      identifier: 'median_time_to_merge',
      value: 'Median time to merge',
    },
    lastMonth: {
      change: 0,
      value: '2.0 d',
    },
    thisMonth: {
      change: 0,
      value: '0.0 d',
    },
    twoMonthsAgo: {
      change: 0,
      value: '-',
    },
  },
  {
    metric: {
      identifier: 'contributor_count',
      value: 'Contributor count',
    },
    lastMonth: {
      change: 1,
      value: 10,
    },
    thisMonth: {
      change: -0.5,
      value: 5,
    },
    twoMonthsAgo: {
      change: -0.5,
      value: 5,
    },
  },
  {
    metric: {
      identifier: 'vulnerability_critical',
      value: 'Critical vulnerabilities over time',
    },
    trendStyle: TREND_STYLE_DESC,
    lastMonth: {
      change: null,
      value: 0,
    },
    thisMonth: {
      change: null,
      value: 3,
    },
    twoMonthsAgo: {
      change: null,
      value: 2,
    },
  },
  {
    metric: {
      identifier: 'vulnerability_high',
      value: 'High vulnerabilities over time',
    },
    trendStyle: TREND_STYLE_DESC,
    lastMonth: {
      change: null,
      value: 3,
    },
    thisMonth: {
      change: null,
      value: 0,
    },
    twoMonthsAgo: {
      change: null,
      value: 0,
    },
  },
];

export const mockGeneratedMetricComparisons = () =>
  mockComparativeTableData.reduce(
    (acc, { metric, lastMonth, thisMonth, twoMonthsAgo }) =>
      Object.assign(acc, { [metric.identifier]: { lastMonth, thisMonth, twoMonthsAgo } }),
    {},
  );

const mockChartDataValues = (values) => values.map((v) => [expect.anything(), v]);

const mockChartDataWithSameValue = (count, value) =>
  mockChartDataValues([...Array(count).keys()].map(() => value));

export const mockSubsetChartData = {
  lead_time_for_changes: {
    chart: {
      data: mockChartDataValues([1, 2]),
      tooltipLabel: 'days',
    },
  },
  time_to_restore_service: {
    chart: {
      data: mockChartDataValues([100, 99]),
      tooltipLabel: 'days',
    },
  },
};

export const mockChartData = {
  lead_time_for_changes: {
    chart: {
      tooltipLabel: 'days',
      data: mockChartDataWithSameValue(6, null),
    },
  },
  time_to_restore_service: {
    chart: {
      tooltipLabel: 'days',
      data: mockChartDataWithSameValue(6, 0),
    },
  },
  change_failure_rate: {
    chart: {
      tooltipLabel: '%',
      data: mockChartDataWithSameValue(6, 0),
    },
  },
  deployment_frequency: {
    chart: {
      tooltipLabel: '/day',
      data: mockChartDataValues([0, 1, 2, 3, 4, 5]),
    },
  },
  lead_time: {
    chart: {
      tooltipLabel: 'days',
      data: mockChartDataValues([1, 2, 3, 4, 5, 6]),
    },
  },
  cycle_time: {
    chart: {
      tooltipLabel: 'days',
      data: mockChartDataValues([0, 2, 4, 6, 8, 10]),
    },
  },
  issues: {
    chart: {
      data: mockChartDataValues([100, 98, 96, 94, 92, 90]),
    },
  },
  issues_completed: {
    chart: {
      data: mockChartDataValues([200, 198, 196, 194, 192, 190]),
    },
  },
  deploys: {
    chart: {
      data: mockChartDataValues([0, 1, 4, 9, 16, 25]),
    },
  },
  contributor_count: {
    chart: {
      data: mockChartDataValues([0, 3, 6, 9, 12, 15]),
    },
  },
  vulnerability_critical: {
    chart: {
      data: mockChartDataValues([0, 1, 2, 3, 0, 1]),
    },
  },
  vulnerability_high: {
    chart: {
      data: mockChartDataValues([0, 1, 0, 1, 0, 1]),
    },
  },
  merge_request_throughput: {
    chart: {
      data: mockChartDataValues([0, 1, 2, 3, 4, 5]),
    },
  },
  median_time_to_merge: {
    chart: {
      tooltipLabel: 'days',
      data: mockChartDataWithSameValue(6, 0),
    },
  },
};

export const mockLastVulnerabilityCountData = {
  date: '2020-05-20',
  critical: 7,
  high: 6,
  medium: 5,
  low: 4,
};

export const mockMergeRequestsResponseData = {
  merge_request_throughput: 10,
  __typename: 'MergeRequestConnection',
};

export const mockContributorCountResponseData = {
  identifier: 'CONTRIBUTORS',
  count: 4,
  recordedAt: '2024-01-11T19:11:05Z',
  __typename: 'ValueStreamDashboardCount',
};

export const mockAggregatedPipelineMetricsResponseData = {
  pipelineCount: 100,
  pipelineSuccessCount: 50,
  pipelineFailedCount: 35,
  pipelineOtherCount: 15,
  durationStatistics: {
    pipelineDurationMedian: 39600,
    __typename: 'CiDurationStatistics',
  },
  __typename: 'PipelineAnalyticsPeriod',
};

export const MOCK_LABELS = [
  { id: 1, title: 'one', color: '#FFFFFF' },
  { id: 2, title: 'two', color: '#000000' },
  { id: 3, title: 'three', color: '#0F0F0F' },
];

export const filterLabelsGroupQuery = `query ($fullPath: ID!) {
  namespace: group(fullPath: $fullPath) {
    id
    label_0: labels(
      title: "zero"
      includeAncestorGroups: true
      includeDescendantGroups: true
    ) {
      nodes {
        id
        title
        color
      }
    }
    label_1: labels(
      title: "one"
      includeAncestorGroups: true
      includeDescendantGroups: true
    ) {
      nodes {
        id
        title
        color
      }
    }
  }
}`;

export const filterLabelsProjectQuery = `query ($fullPath: ID!) {
  namespace: project(fullPath: $fullPath) {
    id
    label_0: labels(title: "zero", includeAncestorGroups: true) {
      nodes {
        id
        title
        color
      }
    }
    label_1: labels(title: "one", includeAncestorGroups: true) {
      nodes {
        id
        title
        color
      }
    }
  }
}`;

export const mockGroup = {
  id: 'gid://gitlab/Group/10',
  name: 'Group 10',
  fullName: 'Group 10',
  webUrl: 'gdk.test/groups/group-10',
  avatarUrl: 'avatar.png',
  visibility: 'Public',
  __typename: TYPENAME_GROUP,
};

export const mockProject = {
  id: 'gid://gitlab/Project/20',
  name: 'Project 20',
  fullName: 'Group 10 / Project 20',
  webUrl: 'gdk.test/group-10/project-20',
  avatarUrl: 'avatar.png',
  visibility: 'Private',
  __typename: TYPENAME_PROJECT,
};
