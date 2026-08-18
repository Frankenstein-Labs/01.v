import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { UNITS } from '~/analytics/shared/constants';
import { extractQueryResponseFromNamespace, scaledValueForDisplay } from '~/analytics/shared/utils';
import {
  extractGraphqlDoraData,
  extractGraphqlFlowData,
  extractGraphqlVulnerabilitiesData,
  extractGraphqlMergeRequestsData,
  extractGraphqlContributorCountData,
  extractAggregatedPipelineMetricsData,
} from 'ee/analytics/dashboards/api';
import {
  mockDoraMetricsResponseData,
  mockFlowMetricsResponseData,
} from 'jest/analytics/shared/mock_data';
import {
  mockLastVulnerabilityCountData,
  mockMergeRequestsResponseData,
  mockContributorCountResponseData,
  mockAggregatedPipelineMetricsResponseData,
} from './mock_data';

describe('Analytics Dashboards api', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('extractGraphqlVulnerabilitiesData', () => {
    const vulnerabilityResponse = {
      vulnerability_critical: { identifier: 'vulnerability_critical', value: 7, tooltip: null },
      vulnerability_high: { identifier: 'vulnerability_high', value: 6, tooltip: null },
    };

    const missingVulnerabilityResponse = {
      vulnerability_critical: {
        identifier: 'vulnerability_critical',
        value: '-',
        tooltip: 'No data',
      },
      vulnerability_high: { identifier: 'vulnerability_high', value: '-', tooltip: 'No data' },
    };

    it('returns each vulnerability metric', () => {
      const keys = Object.keys(extractGraphqlVulnerabilitiesData([mockLastVulnerabilityCountData]));
      expect(keys).toEqual(['vulnerability_critical', 'vulnerability_high']);
    });

    it('prepares each vulnerability metric for display', () => {
      expect(extractGraphqlVulnerabilitiesData([mockLastVulnerabilityCountData])).toEqual(
        vulnerabilityResponse,
      );
    });

    it('returns `-` when the vulnerability metric is `0`, null or missing', () => {
      [{}, { ...mockLastVulnerabilityCountData, critical: null, high: 0 }].forEach((badData) => {
        expect(extractGraphqlVulnerabilitiesData([badData])).toEqual(missingVulnerabilityResponse);
      });
    });
  });

  describe('extractGraphqlDoraData', () => {
    const doraResponse = {
      change_failure_rate: { identifier: 'change_failure_rate', value: '5.7' },
      deployment_frequency: { identifier: 'deployment_frequency', value: 23.75 },
      lead_time_for_changes: { identifier: 'lead_time_for_changes', value: '0.2721' },
      time_to_restore_service: { identifier: 'time_to_restore_service', value: '0.8343' },
    };

    it('returns each flow metric', () => {
      const keys = Object.keys(extractGraphqlDoraData(mockDoraMetricsResponseData.metrics));
      expect(keys).toEqual([
        'deployment_frequency',
        'lead_time_for_changes',
        'time_to_restore_service',
        'change_failure_rate',
      ]);
    });

    it('prepares each dora metric for display', () => {
      expect(extractGraphqlDoraData(mockDoraMetricsResponseData.metrics)).toEqual(doraResponse);
    });

    it('replaces null values with 0.0', () => {
      expect(extractGraphqlDoraData([{ change_failure_rate: null }])).toEqual({
        change_failure_rate: { identifier: 'change_failure_rate', value: '0.0' },
      });
    });

    it('returns an empty object given an empty array', () => {
      expect(extractGraphqlDoraData([])).toEqual({});
    });
  });

  describe('extractGraphqlFlowData', () => {
    const flowMetricsResponse = {
      cycle_time: { identifier: 'cycle_time', value: '-', tooltip: 'No data' },
      deploys: { identifier: 'deploys', value: 751, tooltip: null },
      issues: { identifier: 'issues', value: 10, tooltip: null },
      issues_completed: { identifier: 'issues_completed', value: 109, tooltip: null },
      lead_time: { identifier: 'lead_time', value: 10, tooltip: null },
      median_time_to_merge: { identifier: 'median_time_to_merge', value: '0.3', tooltip: null },
    };

    it('returns each flow metric', () => {
      const keys = Object.keys(extractGraphqlFlowData(mockFlowMetricsResponseData));
      expect(keys).toEqual([
        'lead_time',
        'cycle_time',
        'issues',
        'issues_completed',
        'deploys',
        'median_time_to_merge',
      ]);
    });

    it('replaces null values with `-`', () => {
      expect(extractGraphqlFlowData(mockFlowMetricsResponseData)).toEqual(flowMetricsResponse);
    });
  });

  describe('extractGraphqlMergeRequestsData', () => {
    it('returns each merge request metric', () => {
      const keys = Object.keys(extractGraphqlMergeRequestsData(mockMergeRequestsResponseData));
      expect(keys).toEqual(['merge_request_throughput']);
    });

    it('replaces null values with `-`', () => {
      expect(extractGraphqlMergeRequestsData({ merge_request_throughput: null })).toEqual({
        merge_request_throughput: {
          identifier: 'merge_request_throughput',
          value: '-',
          tooltip: 'No data',
        },
      });
    });
  });

  describe('scaledValueForDisplay', () => {
    it.each`
      value    | units            | result
      ${86400} | ${UNITS.DAYS}    | ${'1.0000'}
      ${0.5}   | ${UNITS.PERCENT} | ${'50.0'}
      ${0.75}  | ${UNITS.PER_DAY} | ${0.75}
      ${1500}  | ${UNITS.COUNT}   | ${1500}
    `('formats the $value as $result when units set to $units', ({ value, units, result }) => {
      expect(scaledValueForDisplay(value, units)).toBe(result);
    });

    it.each`
      precision | result
      ${1}      | ${'0.3'}
      ${3}      | ${'0.271'}
    `(
      'returns the value with $precision decimals as $result when units set to $units',
      ({ precision, result }) => {
        expect(scaledValueForDisplay(23456, UNITS.DAYS, precision)).toBe(result);
      },
    );
  });

  describe('extractGraphqlContributorCountData', () => {
    it('returns each contributors count metric', () => {
      const keys = Object.keys(
        extractGraphqlContributorCountData(mockContributorCountResponseData),
      );

      expect(keys).toEqual(['contributor_count']);
    });

    it('replaces null values with 0', () => {
      expect(extractGraphqlContributorCountData({ contributors: null })).toEqual({
        contributor_count: { identifier: 'contributor_count', value: 0 },
      });
    });
  });

  describe('extractQueryResponseFromNamespace', () => {
    const resultKey = 'over';
    const response = 9000;

    it('returns the project response when there is data present', () => {
      expect(
        extractQueryResponseFromNamespace({
          resultKey,
          result: { data: { project: { [resultKey]: response } } },
        }),
      ).toEqual(response);
    });

    it('returns the group response when there is data present', () => {
      expect(
        extractQueryResponseFromNamespace({
          resultKey,
          result: { data: { group: { [resultKey]: response } } },
        }),
      ).toEqual(response);
    });

    it('returns an empty object when the data is blank', () => {
      expect(
        extractQueryResponseFromNamespace({
          resultKey,
          result: { data: { group: { [resultKey]: null } } },
        }),
      ).toEqual({});
    });

    it('returns an empty object when there is no data present', () => {
      expect(
        extractQueryResponseFromNamespace({
          resultKey,
          result: { data: {} },
        }),
      ).toEqual({});
    });
  });

  describe('extractAggregatedPipelineMetricsData', () => {
    let resp;

    beforeEach(() => {
      resp = extractAggregatedPipelineMetricsData(mockAggregatedPipelineMetricsResponseData);
    });

    it('returns the relevant pipeline metrics', () => {
      expect(Object.keys(resp)).toEqual([
        'pipeline_count',
        'pipeline_success_rate',
        'pipeline_failed_rate',
        'pipeline_other_rate',
        'pipeline_duration_median',
      ]);
    });

    it('correctly formats each metric', () => {
      expect(resp).toEqual({
        pipeline_count: {
          identifier: 'pipeline_count',
          value: 100,
        },
        pipeline_duration_median: {
          identifier: 'pipeline_duration_median',
          value: 660,
        },
        pipeline_failed_rate: {
          identifier: 'pipeline_failed_rate',
          tooltip: '35/100',
          value: 35,
        },
        pipeline_success_rate: {
          identifier: 'pipeline_success_rate',
          tooltip: '50/100',
          value: 50,
        },
        pipeline_other_rate: {
          identifier: 'pipeline_other_rate',
          tooltip: '15/100',
          value: 15,
        },
      });
    });
  });
});
