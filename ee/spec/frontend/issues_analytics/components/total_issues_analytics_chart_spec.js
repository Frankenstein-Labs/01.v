import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import TotalIssuesAnalyticsChart from 'ee/issues_analytics/components/total_issues_analytics_chart.vue';
import IssuesAnalyticsEmptyState from 'ee/issues_analytics/components/issues_analytics_empty_state.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import issuesAnalyticsCountsQueryBuilder from 'ee/issues_analytics/graphql/issues_analytics_counts_query_builder';
import {
  ISSUES_COMPLETED_COUNT_ALIAS,
  ISSUES_OPENED_COUNT_ALIAS,
  TOTAL_ISSUES_ANALYTICS_CHART_COLOR_PALETTE,
} from 'ee/issues_analytics/constants';
import {
  mockIssuesAnalyticsCountsChartData,
  mockIssuesAnalyticsCountsEndDate,
  mockIssuesAnalyticsCountsStartDate,
  mockFilters,
  getMockIssuesOpenedCountsResponse,
  getMockIssuesClosedCountsResponse,
} from '../mock_data';
import { mockGraphqlIssuesAnalyticsCountsResponse } from '../helpers';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('TotalIssuesAnalyticsChart', () => {
  let wrapper;
  let mockApollo;

  const fullPath = 'toolbox';
  const mockGroupBy = [
    'Nov',
    'Dec',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
  ];
  const queryError = jest.fn().mockRejectedValueOnce(new Error('Something went wrong'));
  const mockDataNullResponse = mockGraphqlIssuesAnalyticsCountsResponse({ mockDataResponse: null });
  const issuesOpenedCountsSuccess = mockGraphqlIssuesAnalyticsCountsResponse({
    mockDataResponse: getMockIssuesOpenedCountsResponse(),
  });

  const issuesClosedCountsSuccess = mockGraphqlIssuesAnalyticsCountsResponse({
    mockDataResponse: getMockIssuesClosedCountsResponse(),
  });
  const issuesOpenedCountsEmpty = mockGraphqlIssuesAnalyticsCountsResponse({
    mockDataResponse: getMockIssuesOpenedCountsResponse({ isEmpty: true }),
  });

  const issuesClosedCountsEmpty = mockGraphqlIssuesAnalyticsCountsResponse({
    mockDataResponse: getMockIssuesClosedCountsResponse({ isEmpty: true }),
  });
  const mockTypePolicy = {
    Group: { fields: { flowMetrics: { merge: true } } },
  };

  const createComponent = async ({
    props = {},
    startDate = mockIssuesAnalyticsCountsStartDate,
    endDate = mockIssuesAnalyticsCountsEndDate,
    filters = {},
    type = 'group',
    issuesOpenedResolver,
    issuesClosedResolver,
  } = {}) => {
    const issuesOpenedCountsQuery = issuesAnalyticsCountsQueryBuilder({
      queryAlias: ISSUES_OPENED_COUNT_ALIAS,
      startDate,
      endDate,
    });

    const issuesClosedCountsQuery = issuesAnalyticsCountsQueryBuilder({
      queryAlias: ISSUES_COMPLETED_COUNT_ALIAS,
      startDate,
      endDate,
    });

    mockApollo = createMockApollo(
      [
        [issuesOpenedCountsQuery, issuesOpenedResolver || issuesOpenedCountsSuccess],
        [issuesClosedCountsQuery, issuesClosedResolver || issuesClosedCountsSuccess],
      ],
      {},
      {
        typePolicies: mockTypePolicy,
      },
    );

    wrapper = shallowMountExtended(TotalIssuesAnalyticsChart, {
      apolloProvider: mockApollo,
      propsData: {
        startDate,
        endDate,
        filters,
        ...props,
      },
      provide: {
        fullPath,
        type,
      },
    });

    await waitForPromises();
  };

  const findTotalIssuesAnalyticsChart = () => wrapper.findComponent(GlStackedColumnChart);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findEmptyState = () => wrapper.findComponent(IssuesAnalyticsEmptyState);

  afterEach(() => {
    mockApollo = null;
  });

  describe('default', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('should render chart', () => {
      expect(findTotalIssuesAnalyticsChart().props()).toMatchObject({
        bars: mockIssuesAnalyticsCountsChartData,
        presentation: 'tiled',
        groupBy: mockGroupBy,
        xAxisType: 'category',
        xAxisTitle: 'Last 12 months (Nov 2022 – Nov 2023)',
        yAxisTitle: 'Issues Opened vs Closed',
        customPalette: TOTAL_ISSUES_ANALYTICS_CHART_COLOR_PALETTE,
      });
    });

    it('should display chart header', () => {
      expect(wrapper.findByText('Overview').exists()).toBe(true);
    });

    it(`should fetch issues opened counts`, () => {
      expect(issuesOpenedCountsSuccess).toHaveBeenCalledTimes(1);
      expect(issuesOpenedCountsSuccess).toHaveBeenCalledWith({
        fullPath,
      });
    });

    it(`should fetch issues closed counts`, () => {
      expect(issuesClosedCountsSuccess).toHaveBeenCalledTimes(1);
      expect(issuesClosedCountsSuccess).toHaveBeenCalledWith({
        fullPath,
      });
    });

    it.each`
      startDate                               | expectedXAxisTitle
      ${new Date('2023-09-01T00:00:00.000Z')} | ${'Last 2 months (Sep 2023 – Nov 2023)'}
      ${new Date('2023-10-01T00:00:00.000Z')} | ${'Last month (Oct 2023 – Nov 2023)'}
      ${new Date('2023-11-01T00:00:00.000Z')} | ${'This month (Nov 2023)'}
    `(
      `should display the correct x-axis title when startDate=$startDate and endDate=${mockIssuesAnalyticsCountsEndDate}`,
      async ({ startDate, expectedXAxisTitle }) => {
        await createComponent({ startDate });

        expect(findTotalIssuesAnalyticsChart().props('xAxisTitle')).toBe(expectedXAxisTitle);
      },
    );
  });

  describe('when fetching data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should display loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('when filters have been applied', () => {
    const weight = '2';
    const formattedWeight = Math.round(weight);
    const iterationId = '36605';
    const originalFilters = {
      monthsBack: '3',
      weight,
      not: { weight, iterationId },
      ...mockFilters,
    };
    const expectedFilters = {
      weight: formattedWeight,
      not: { weight: formattedWeight, iterationId },
      ...mockFilters,
    };

    beforeEach(async () => {
      await createComponent({ filters: originalFilters });
    });

    it(`should fetch issues opened counts with filters`, () => {
      expect(issuesOpenedCountsSuccess).toHaveBeenCalledTimes(1);
      expect(issuesOpenedCountsSuccess).toHaveBeenCalledWith({
        fullPath,
        ...expectedFilters,
      });
    });

    it(`should fetch issues closed counts with filters`, () => {
      expect(issuesClosedCountsSuccess).toHaveBeenCalledTimes(1);
      expect(issuesClosedCountsSuccess).toHaveBeenCalledWith({
        fullPath,
        ...expectedFilters,
      });
    });

    describe('produced no results', () => {
      beforeEach(async () => {
        await createComponent({
          filters: mockFilters,
          issuesOpenedResolver: issuesOpenedCountsEmpty,
          issuesClosedResolver: issuesClosedCountsEmpty,
        });
      });

      it('should display correct empty state', () => {
        expect(findEmptyState().props('emptyStateType')).toBe('noDataWithFilters');
      });

      it('should not display chart', () => {
        expect(findTotalIssuesAnalyticsChart().exists()).toBe(false);
      });

      it('should not emit "hide-filtered-search-bar" event', () => {
        expect(wrapper.emitted('hide-filtered-search-bar')).toBeUndefined();
      });
    });
  });

  describe('when fetching data fails', () => {
    describe.each`
      issuesOpenedQueryHasError | issuesClosedQueryHasError | expectedSentryCallsCount
      ${true}                   | ${true}                   | ${2}
      ${true}                   | ${false}                  | ${1}
      ${false}                  | ${true}                   | ${1}
    `(
      'issuesOpenedQueryHasError=$issuesOpenedQueryHasError and issuesClosedQueryHasError=$issuesClosedQueryHasError',
      ({ issuesOpenedQueryHasError, issuesClosedQueryHasError, expectedSentryCallsCount }) => {
        beforeEach(async () => {
          await createComponent({
            issuesOpenedResolver: issuesOpenedQueryHasError ? queryError : undefined,
            issuesClosedResolver: issuesClosedQueryHasError ? queryError : undefined,
          });
        });

        it('should display alert component', () => {
          expect(findAlert().exists()).toBe(true);
          expect(findAlert().text()).toBe('Failed to load chart. Please try again.');
        });

        it('should log error to Sentry', () => {
          expect(Sentry.captureException).toHaveBeenCalledTimes(expectedSentryCallsCount);
        });

        it('should not display chart', () => {
          expect(findTotalIssuesAnalyticsChart().exists()).toBe(false);
        });

        it('should not emit "hide-filtered-search-bar" event', () => {
          expect(wrapper.emitted('hide-filtered-search-bar')).toBeUndefined();
        });
      },
    );
  });

  describe('when there is no data to present', () => {
    it.each`
      description                    | issuesOpenedNoDataResponse | issuesClosedNoDataResponse
      ${'responses are null'}        | ${mockDataNullResponse}    | ${mockDataNullResponse}
      ${'response counts are all 0'} | ${issuesOpenedCountsEmpty} | ${issuesClosedCountsEmpty}
    `(
      'should display empty state and emit "hide-filtered-search-bar" event when $description',
      async ({ issuesOpenedNoDataResponse, issuesClosedNoDataResponse }) => {
        await createComponent({
          issuesOpenedResolver: issuesOpenedNoDataResponse,
          issuesClosedResolver: issuesClosedNoDataResponse,
        });

        expect(findEmptyState().props('emptyStateType')).toBe('noData');
        expect(wrapper.emitted('hide-filtered-search-bar')).toHaveLength(1);
      },
    );
  });
});
