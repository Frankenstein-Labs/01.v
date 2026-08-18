import { GlSkeletonLoader, GlSprintf } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';
import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import TestCoverageSummary from 'ee/analytics/repository_analytics/components/test_coverage_summary.vue';
import getGroupTestCoverage from 'ee/analytics/repository_analytics/graphql/queries/get_group_test_coverage.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { nDaysBefore, formatDate } from '~/lib/utils/datetime_utility';

Vue.use(VueApollo);

describe('Test coverage table component', () => {
  let wrapper;

  const findAllSingleStats = () => wrapper.findAllComponents(GlSingleStat);
  const findProjectsWithTests = () => findAllSingleStats().at(0);
  const findAverageCoverage = () => findAllSingleStats().at(1);
  const findTotalCoverages = () => findAllSingleStats().at(2);
  const findGroupCoverageChart = () => wrapper.findComponentByTestId('group-coverage-chart');
  const findChartLoadingState = () => wrapper.findByTestId('group-coverage-chart-loading');
  const findChartEmptyState = () => wrapper.findByTestId('group-coverage-chart-empty');
  const findCoverageHeader = () => wrapper.findByTestId('test-coverage-header');
  const findLastUpdated = () => wrapper.findByTestId('test-coverage-last-updated');
  const findLoadingState = () => wrapper.findComponent(GlSkeletonLoader);

  const coverageActivity = ({
    date = '2020-01-10',
    averageCoverage = 77.9,
    projectCount = 5,
    coverageCount = 5,
  } = {}) => ({
    __typename: 'CodeCoverageActivity',
    date,
    averageCoverage,
    projectCount,
    coverageCount,
  });

  const coverageResponse = (nodes) => ({
    data: {
      group: {
        __typename: 'Group',
        id: 'gid://gitlab/Group/1',
        codeCoverageActivities: {
          __typename: 'CodeCoverageActivityConnection',
          nodes,
        },
      },
    },
  });

  const createComponent = ({ nodes = [] } = {}) => {
    const coverageHandler = jest.fn().mockResolvedValue(coverageResponse(nodes));

    wrapper = extendedWrapper(
      shallowMount(TestCoverageSummary, {
        apolloProvider: createMockApollo([[getGroupTestCoverage, coverageHandler]]),
        stubs: {
          GlSingleStat,
          GlSprintf,
        },
      }),
    );
  };

  it('renders test coverage header', () => {
    createComponent();

    expect(findCoverageHeader().exists()).toBe(true);
  });

  describe('last updated date', () => {
    it.each([
      [null, 'Last updated'],
      [0, 'Last updated today'],
      [1, 'Last updated 1 day ago'],
      [730, 'Last updated Jul 7, 2018'],
    ])(
      'when last updated date is %p days ago, renders heading %p',
      async (daysAgo, expectedText) => {
        const date =
          daysAgo === null
            ? null
            : formatDate(nDaysBefore(new Date(), daysAgo, { utc: true }), 'yyyy-mm-dd');

        createComponent({ nodes: [coverageActivity({ date, averageCoverage: 79.6 })] });
        await waitForPromises();

        expect(findLastUpdated().text()).toBe(expectedText);
      },
    );
  });

  describe('when group code coverage is empty', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders empty metrics', () => {
      expect(findProjectsWithTests().text()).toContain('-');
      expect(findAverageCoverage().text()).toContain('-');
      expect(findTotalCoverages().text()).toContain('-');
    });

    it('renders empty chart state', () => {
      expect(findChartEmptyState().exists()).toBe(true);
      expect(findGroupCoverageChart().exists()).toBe(false);
    });
  });

  describe('when query is loading', () => {
    it('renders loading state', () => {
      // Deliberately not awaited: the query is still in flight.
      createComponent();

      expect(findLoadingState().exists()).toBe(true);
      expect(findChartLoadingState().exists()).toBe(true);
    });
  });

  describe('when group code coverage is available', () => {
    it('renders coverage metrics', async () => {
      const projectCount = 5;
      const averageCoverage = 74.35;
      const coverageCount = 5;

      createComponent({
        nodes: [coverageActivity({ projectCount, averageCoverage, coverageCount })],
      });
      await waitForPromises();

      expect(findProjectsWithTests().props('value')).toBe(`${projectCount}`);
      expect(findAverageCoverage().props('value')).toBe(`${averageCoverage}`);
      expect(findAverageCoverage().props('unit')).toBe('%');
      expect(findTotalCoverages().props('value')).toBe(`${coverageCount}`);
    });

    describe('with a series of coverage activities', () => {
      beforeEach(async () => {
        createComponent({
          nodes: [
            coverageActivity({ date: '2020-01-10', averageCoverage: 77.9 }),
            coverageActivity({ date: '2020-01-11', averageCoverage: 78.7 }),
            coverageActivity({ date: '2020-01-12', averageCoverage: 79.6 }),
          ],
        });
        await waitForPromises();
      });

      it('renders area chart with correct data', () => {
        expect(findGroupCoverageChart().exists()).toBe(true);
        expect(findGroupCoverageChart().props('data')).toMatchSnapshot();
      });

      it('formats the area chart labels correctly', () => {
        expect(
          findGroupCoverageChart().props('option').xAxis.axisLabel.formatter('2020-01-10'),
        ).toBe('Jan 10');
        expect(findGroupCoverageChart().props('option').yAxis.axisLabel.formatter(80)).toBe('80%');
      });
    });
  });
});
