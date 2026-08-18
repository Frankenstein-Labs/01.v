import { BUCKETING_INTERVAL_ALL } from '~/analytics/shared/graphql/constants';
import { MERGE_REQUESTS_STATE_MERGED } from '~/analytics/dashboards/graphql/constants';
import { toYmd } from '~/analytics/shared/utils';
import {
  mockLastVulnerabilityCountData,
  mockMergeRequestsResponseData,
  mockContributorCountResponseData,
} from './mock_data';

export const doraMetricsParamsHelper = ({
  interval = BUCKETING_INTERVAL_ALL,
  start,
  end,
  fullPath = '',
}) => ({
  interval,
  fullPath,
  startDate: toYmd(start),
  endDate: toYmd(end),
  skipChangeFailureRate: false,
  skipDeploymentFrequency: false,
  skipLeadTimeForChanges: false,
  skipTimeToRestoreService: false,
});

export const flowMetricsParamsHelper = ({ start, end, fullPath = '', labelNames = [] }) => ({
  fullPath,
  startDate: toYmd(start),
  endDate: toYmd(end),
  labelNames,
  skipCycleTime: false,
  skipDeploymentCount: false,
  skipIssueCount: false,
  skipIssuesCompletedCount: false,
  skipLeadTime: false,
  skipTimeToMerge: false,
});

// For the vulnerabilities request we just query for the last date in the time period
export const vulnerabilityParamsHelper = ({ fullPath, end }) => ({
  fullPath,
  startDate: toYmd(end),
  endDate: toYmd(end),
  skipCritical: false,
  skipHigh: false,
});

export const mergeRequestsParamsHelper = ({ start, end, fullPath = '', labelNames = [] }) => ({
  fullPath,
  startDate: toYmd(start),
  endDate: toYmd(end),
  state: MERGE_REQUESTS_STATE_MERGED,
  labelNames,
});

export const contributorCountParamsHelper = ({ fullPath = '', start, end }) => ({
  fullPath,
  startDate: toYmd(start),
  endDate: toYmd(end),
});

export const mockGraphqlVulnerabilityResponse = (
  mockDataResponse = mockLastVulnerabilityCountData,
) =>
  jest.fn().mockResolvedValue({
    data: {
      project: null,
      group: {
        id: 'fake-vulnerability-request',
        vulnerabilitiesCountByDay: { nodes: [mockDataResponse] },
      },
    },
  });

export const mockGraphqlMergeRequestsResponse = (
  mockDataResponse = mockMergeRequestsResponseData,
) =>
  jest.fn().mockResolvedValue({
    data: {
      project: null,
      group: { id: 'fake-merge-requests-request', mergeRequests: mockDataResponse },
    },
  });

export const mockGraphqlContributorCountResponse = (
  mockDataResponse = mockContributorCountResponseData,
) =>
  jest.fn().mockResolvedValue({
    data: {
      project: null,
      group: { id: 'fake-contributor-count-request', contributors: mockDataResponse },
    },
  });

export const mockFilterLabelsResponse = (mockLabels = []) => ({
  namespace: mockLabels?.reduce(
    (acc, label, index) =>
      Object.assign(acc, {
        [`label_${index}`]: { nodes: [{ id: label, title: label, color: '#FFFFFF' }] },
      }),
    { id: 'id' },
  ),
});

export const expectTimePeriodRequests = ({ requestHandler, timePeriods, paramsFn }) => {
  let params = {};
  expect(requestHandler).toHaveBeenCalledTimes(timePeriods.length);

  timePeriods.forEach((timePeriod) => {
    params = paramsFn(timePeriod);
    expect(requestHandler).toHaveBeenCalledWith(params);
  });
};
