import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  SUPPORTED_CONTRIBUTOR_METRICS,
  SUPPORTED_DORA_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_MERGE_REQUEST_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
} from 'ee/analytics/dashboards/constants';
import { generateSkeletonTableData } from 'ee/analytics/dashboards/utils';
import ComparisonChart from 'ee/analytics/dashboards/components/comparison_chart.vue';
import ComparisonTable from 'ee/analytics/dashboards/components/comparison_table.vue';
import VulnerabilitiesQuery from '~/analytics/dashboards/graphql/vulnerabilities.query.graphql';
import MergeRequestsQuery from '~/analytics/dashboards/graphql/merge_requests.query.graphql';
import ContributorCountQuery from '~/analytics/dashboards/graphql/contributor_count.query.graphql';
import { VULNERABILITY_METRICS } from '~/analytics/shared/constants';
import FlowMetricsQuery from '~/analytics/shared/graphql/flow_metrics.query.graphql';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  mockDoraMetricsResponseData,
  mockFlowMetricsResponseData,
} from 'jest/analytics/shared/mock_data';
import {
  mockGraphqlDoraMetricsResponse,
  mockGraphqlFlowMetricsResponse,
} from 'jest/analytics/shared/helpers';
import {
  doraMetricsParamsHelper,
  flowMetricsParamsHelper,
  vulnerabilityParamsHelper,
  mergeRequestsParamsHelper,
  mockGraphqlVulnerabilityResponse,
  mockGraphqlMergeRequestsResponse,
  expectTimePeriodRequests,
  mockGraphqlContributorCountResponse,
  contributorCountParamsHelper,
} from '../helpers';
import {
  MOCK_TABLE_TIME_PERIODS,
  MOCK_CHART_TIME_PERIODS,
  mockComparativeTableData,
  mockLastVulnerabilityCountData,
  mockMergeRequestsResponseData,
  mockContributorCountResponseData,
} from '../mock_data';

const mockTypePolicy = {
  Query: { fields: { project: { merge: false }, group: { merge: false } } },
};
const mockProps = { requestPath: 'exec-group', isProject: false };
const mockProvide = { dataSourceClickhouse: true };
const mockGlAbilities = {
  readDora4Analytics: true,
  readCycleAnalytics: true,
  readSecurityResource: true,
};

const groupPath = 'exec-group';
const allTimePeriods = [...MOCK_TABLE_TIME_PERIODS, ...MOCK_CHART_TIME_PERIODS];

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/alert');

Vue.use(VueApollo);

describe('Comparison chart', () => {
  let wrapper;
  let mockApolloProvider;
  let vulnerabilityRequestHandler = null;
  let flowMetricsRequestHandler = null;
  let doraMetricsRequestHandler = null;
  let mergeRequestsRequestHandler = null;
  let contributorCountRequestHandler = null;

  const setGraphqlQueryHandlerResponses = ({
    vulnerabilityResponse = mockLastVulnerabilityCountData,
    doraMetricsResponse = mockDoraMetricsResponseData,
    flowMetricsResponse = mockFlowMetricsResponseData,
    mergeRequestsResponse = mockMergeRequestsResponseData,
    contributorCountResponse = mockContributorCountResponseData,
  } = {}) => {
    vulnerabilityRequestHandler = mockGraphqlVulnerabilityResponse(vulnerabilityResponse);
    flowMetricsRequestHandler = mockGraphqlFlowMetricsResponse(flowMetricsResponse);
    doraMetricsRequestHandler = mockGraphqlDoraMetricsResponse(doraMetricsResponse);
    mergeRequestsRequestHandler = mockGraphqlMergeRequestsResponse(mergeRequestsResponse);
    contributorCountRequestHandler = mockGraphqlContributorCountResponse(contributorCountResponse);
  };

  const createMockApolloProvider = ({
    flowMetricsRequest = flowMetricsRequestHandler,
    doraMetricsRequest = doraMetricsRequestHandler,
    vulnerabilityRequest = vulnerabilityRequestHandler,
    mergeRequestsRequest = mergeRequestsRequestHandler,
    contributorCountRequest = contributorCountRequestHandler,
  } = {}) => {
    return createMockApollo(
      [
        [FlowMetricsQuery, flowMetricsRequest],
        [DoraMetricsQuery, doraMetricsRequest],
        [VulnerabilitiesQuery, vulnerabilityRequest],
        [MergeRequestsQuery, mergeRequestsRequest],
        [ContributorCountQuery, contributorCountRequest],
      ],
      {},
      {
        typePolicies: mockTypePolicy,
      },
    );
  };

  const createWrapper = async ({
    props = {},
    apolloProvider = null,
    provide = {},
    glAbilities = {},
  } = {}) => {
    wrapper = shallowMountExtended(ComparisonChart, {
      apolloProvider,
      propsData: {
        ...mockProps,
        ...props,
      },
      provide: {
        glAbilities: {
          ...mockGlAbilities,
          ...glAbilities,
        },
        ...mockProvide,
        ...provide,
      },
    });

    await waitForPromises();
  };

  const findComparisonTable = () => wrapper.findComponent(ComparisonTable);

  const getTableData = () => findComparisonTable().props('tableData');
  const getTableMetricIds = () => getTableData().map(({ metric }) => metric.identifier);
  const getTableDataForMetric = (identifier) =>
    getTableData().filter(({ metric }) => metric.identifier === identifier)[0];

  const expectDoraMetricsRequests = (timePeriods, { fullPath = groupPath } = {}) =>
    expectTimePeriodRequests({
      timePeriods,
      requestHandler: doraMetricsRequestHandler,
      paramsFn: (timePeriod) => doraMetricsParamsHelper({ ...timePeriod, fullPath }),
    });

  const expectFlowMetricsRequests = (timePeriods, { fullPath = groupPath, labelNames = [] } = {}) =>
    expectTimePeriodRequests({
      timePeriods,
      requestHandler: flowMetricsRequestHandler,
      paramsFn: (timePeriod) => flowMetricsParamsHelper({ ...timePeriod, fullPath, labelNames }),
    });

  const expectVulnerabilityRequests = (timePeriods, { fullPath = groupPath } = {}) =>
    expectTimePeriodRequests({
      timePeriods,
      requestHandler: vulnerabilityRequestHandler,
      paramsFn: (timePeriod) => vulnerabilityParamsHelper({ ...timePeriod, fullPath }),
    });

  const expectMergeRequestsRequests = (
    timePeriods,
    { fullPath = groupPath, labelNames = null } = {},
  ) =>
    expectTimePeriodRequests({
      timePeriods,
      requestHandler: mergeRequestsRequestHandler,
      paramsFn: (timePeriod) => mergeRequestsParamsHelper({ ...timePeriod, fullPath, labelNames }),
    });

  const expectContributorCountRequests = (timePeriods, { fullPath = groupPath } = {}) =>
    expectTimePeriodRequests({
      timePeriods,
      requestHandler: contributorCountRequestHandler,
      paramsFn: (timePeriod) => contributorCountParamsHelper({ ...timePeriod, fullPath }),
    });

  afterEach(() => {
    mockApolloProvider = null;

    vulnerabilityRequestHandler.mockClear();
    flowMetricsRequestHandler.mockClear();
    doraMetricsRequestHandler.mockClear();
    mergeRequestsRequestHandler.mockClear();
    contributorCountRequestHandler.mockClear();
  });

  describe('loading table and chart data', () => {
    beforeEach(() => {
      setGraphqlQueryHandlerResponses();

      createWrapper({ apolloProvider: createMockApolloProvider() });
    });

    it('will pass skeleton data to the comparison table', () => {
      expect(getTableData()).toEqual(generateSkeletonTableData());
    });
  });

  describe('with table and chart data available', () => {
    beforeEach(async () => {
      setGraphqlQueryHandlerResponses();
      mockApolloProvider = createMockApolloProvider();

      await createWrapper({ apolloProvider: mockApolloProvider });
    });

    it('will request dora metrics for the table and sparklines', () => {
      expectDoraMetricsRequests(allTimePeriods);
    });

    it('will request flow metrics for the table and sparklines', () => {
      expectFlowMetricsRequests(allTimePeriods);
    });

    it('will request vulnerability metrics for the table and sparklines', () => {
      expectVulnerabilityRequests(allTimePeriods);
    });

    it('will request merge request data for the table and sparklines', () => {
      expectMergeRequestsRequests(allTimePeriods);
    });

    it('will request contributor count data for the table and sparklines', () => {
      expectContributorCountRequests(allTimePeriods);
    });

    it('renders each DORA metric when there is table data', () => {
      const metricNames = getTableData().map(({ metric }) => metric);
      expect(metricNames).toEqual(mockComparativeTableData.map(({ metric }) => metric));
    });

    it('selects the final data point in the vulnerability response for display', () => {
      const critical = getTableDataForMetric(VULNERABILITY_METRICS.CRITICAL);
      const high = getTableDataForMetric(VULNERABILITY_METRICS.HIGH);

      ['thisMonth', 'lastMonth', 'twoMonthsAgo'].forEach((timePeriodKey) => {
        expect(critical[timePeriodKey].value).toBe(mockLastVulnerabilityCountData.critical);
        expect(high[timePeriodKey].value).toBe(mockLastVulnerabilityCountData.high);
      });
    });

    it('renders a chart on each row', () => {
      expect(getTableData().filter(({ chart }) => !chart)).toEqual([]);
    });
  });

  describe('filterLabels set', () => {
    const filterLabels = ['test::one', 'test::two'];

    beforeEach(async () => {
      setGraphqlQueryHandlerResponses();
      mockApolloProvider = createMockApolloProvider();

      await createWrapper({
        props: { filterLabels },
        apolloProvider: mockApolloProvider,
      });
    });

    it('will filter flow metrics using filterLabels', () => {
      expectFlowMetricsRequests(allTimePeriods, { labelNames: filterLabels });
    });

    it('will filter merge request data using filterLabels', () => {
      expectMergeRequestsRequests(allTimePeriods, { labelNames: filterLabels });
    });

    it('will pass filterLabels to the table', () => {
      expect(findComparisonTable().props('filterLabels')).toEqual(filterLabels);
    });
  });

  describe('excludeMetrics set', () => {
    beforeEach(() => {
      setGraphqlQueryHandlerResponses();
      mockApolloProvider = createMockApolloProvider();
    });

    it('does not render DORA metrics that were in excludeMetrics', async () => {
      const excludeMetrics = SUPPORTED_DORA_METRICS;
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(getTableMetricIds()).not.toEqual(expect.arrayContaining(excludeMetrics));
    });

    it('does not request DORA metrics if they are all excluded', async () => {
      const excludeMetrics = SUPPORTED_DORA_METRICS;
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(doraMetricsRequestHandler).not.toHaveBeenCalled();
    });

    it('requests DORA metrics if at least one is included', async () => {
      const excludeMetrics = SUPPORTED_DORA_METRICS.slice(1);
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(doraMetricsRequestHandler).toHaveBeenCalled();
    });

    it('does not request flow metrics if they are all excluded', async () => {
      const excludeMetrics = SUPPORTED_FLOW_METRICS;
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(flowMetricsRequestHandler).not.toHaveBeenCalled();
    });

    it('requests flow metrics if at least one is included', async () => {
      const excludeMetrics = SUPPORTED_FLOW_METRICS.slice(1);
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(flowMetricsRequestHandler).toHaveBeenCalled();
    });

    it('does not request vulnerability metrics if they are all excluded', async () => {
      const excludeMetrics = SUPPORTED_VULNERABILITY_METRICS;
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(vulnerabilityRequestHandler).not.toHaveBeenCalled();
    });

    it('requests vulnerability metrics if at least one is included', async () => {
      const excludeMetrics = SUPPORTED_VULNERABILITY_METRICS.slice(1);
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(vulnerabilityRequestHandler).toHaveBeenCalled();
    });

    it('does not request MR metrics if throughput was excluded', async () => {
      const excludeMetrics = SUPPORTED_MERGE_REQUEST_METRICS;
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(mergeRequestsRequestHandler).not.toHaveBeenCalled();
    });

    it('does not request contributor metrics if count was excluded', async () => {
      const excludeMetrics = SUPPORTED_CONTRIBUTOR_METRICS;
      await createWrapper({
        props: { excludeMetrics },
        apolloProvider: mockApolloProvider,
      });

      expect(contributorCountRequestHandler).not.toHaveBeenCalled();
    });
  });

  describe('failed table requests', () => {
    beforeEach(async () => {
      setGraphqlQueryHandlerResponses();

      doraMetricsRequestHandler = jest.fn().mockRejectedValue({});
      mockApolloProvider = createMockApolloProvider();

      await createWrapper({ apolloProvider: mockApolloProvider });
    });

    it('will emit `set-alerts` with the failed metric names', () => {
      expect(Sentry.captureException).toHaveBeenCalled();
      expect(wrapper.emitted('set-alerts')).toHaveLength(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual({
        canRetry: true,
        alerts: [],
        warnings: expect.arrayContaining([
          'Some metric comparisons failed to load: Deployment frequency, Lead time for changes, Time to restore service, Change failure rate',
        ]),
      });
    });
  });

  describe('failed chart requests', () => {
    const mockResolvedDoraMetricsResponse = {
      data: { group: { id: 'fake-dora-metrics-request', dora: mockDoraMetricsResponseData } },
    };

    beforeEach(async () => {
      setGraphqlQueryHandlerResponses();

      // The first 4 requests are for the table data, fail after that for the charts
      doraMetricsRequestHandler = jest
        .fn()
        .mockResolvedValueOnce(mockResolvedDoraMetricsResponse)
        .mockResolvedValueOnce(mockResolvedDoraMetricsResponse)
        .mockResolvedValueOnce(mockResolvedDoraMetricsResponse)
        .mockResolvedValueOnce(mockResolvedDoraMetricsResponse)
        .mockRejectedValue({});

      mockApolloProvider = createMockApolloProvider();

      await createWrapper({ apolloProvider: mockApolloProvider });
    });

    it('will emit `set-alerts` with the failed metric names', () => {
      expect(Sentry.captureException).toHaveBeenCalled();
      expect(wrapper.emitted('set-alerts')).toHaveLength(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual({
        canRetry: true,
        alerts: [],
        warnings: expect.arrayContaining([
          'Some metric charts failed to load: Deployment frequency, Lead time for changes, Time to restore service, Change failure rate',
        ]),
      });
    });
  });

  describe('with a project namespace', () => {
    const fakeProjectPath = 'fake/project/path';

    beforeEach(async () => {
      setGraphqlQueryHandlerResponses();
      mockApolloProvider = createMockApolloProvider();

      await createWrapper({
        props: { isProject: true, requestPath: fakeProjectPath },
        apolloProvider: mockApolloProvider,
      });
    });

    it('will request project dora metrics for the table and sparklines', () => {
      expectDoraMetricsRequests(allTimePeriods, { fullPath: fakeProjectPath });
    });

    it('will request project flow metrics for the table and sparklines', () => {
      expectFlowMetricsRequests(allTimePeriods, { fullPath: fakeProjectPath });
    });

    it('will request project vulnerability metrics for the table and sparklines', () => {
      expectVulnerabilityRequests(allTimePeriods, { fullPath: fakeProjectPath });
    });

    it('will request project contributor count data for the table and sparklines', () => {
      expectContributorCountRequests(allTimePeriods, { fullPath: fakeProjectPath });
    });
  });

  describe('dataSourceClickhouse=false', () => {
    beforeEach(async () => {
      setGraphqlQueryHandlerResponses();
      mockApolloProvider = createMockApolloProvider();

      await createWrapper({
        apolloProvider: mockApolloProvider,
        provide: { dataSourceClickhouse: false },
      });
    });

    it('will not request contributor count data for the table and sparklines', () => {
      expect(contributorCountRequestHandler).not.toHaveBeenCalled();
    });
  });

  describe('restricted metrics', () => {
    beforeEach(() => {
      setGraphqlQueryHandlerResponses();
      mockApolloProvider = createMockApolloProvider();

      return createWrapper({
        props: { excludeMetrics: ['deployment_frequency'] },
        glAbilities: { readDora4Analytics: false },
        apolloProvider: mockApolloProvider,
      });
    });

    it('does not render the metrics in the chart', () => {
      expect(getTableMetricIds()).not.toEqual(expect.arrayContaining(SUPPORTED_DORA_METRICS));
    });

    it('does not send an API request for the metrics', () => {
      expect(doraMetricsRequestHandler).not.toHaveBeenCalled();
    });

    it('emits `set-alerts` warning with the restricted metrics', () => {
      expect(wrapper.emitted('set-alerts')).toHaveLength(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual({
        canRetry: false,
        warnings: [],
        alerts: expect.arrayContaining([
          'You have insufficient permissions to view: Lead time for changes, Time to restore service, Change failure rate',
        ]),
      });
    });
  });
});
