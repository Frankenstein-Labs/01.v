import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { GlSkeletonLoader, GlIcon } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import DoraPerformersScoreChart from 'ee/analytics/dashboards/dora_performers_score/components/dora_performers_score_chart.vue';
import FilterProjectTopicsBadges from 'ee/analytics/dashboards/dora_performers_score/components/filter_project_topics_badges.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import groupDoraPerformanceScoreCountsQuery from 'ee/analytics/dashboards/dora_performers_score/graphql/group_dora_performance_score_counts.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { DORA_PERFORMERS_SCORE_CHART_COLOR_PALETTE } from 'ee/analytics/dashboards/dora_performers_score/constants';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { mockGraphqlDoraPerformanceScoreCountsResponse } from '../helpers';
import {
  mockDoraPerformersScoreChartData,
  mockEmptyDoraPerformersScoreResponseData,
} from '../mock_data';

Vue.use(VueApollo);

describe('DoraPerformersScoreChart', () => {
  const fullPath = 'toolbox';
  const mockData = { namespace: fullPath };
  const mockProjectsCount = 70;
  const doraPerformanceScoreCountsSuccess = mockGraphqlDoraPerformanceScoreCountsResponse({
    totalProjectsCount: mockProjectsCount,
  });
  const noProjectsWithDoraData = mockGraphqlDoraPerformanceScoreCountsResponse({
    totalProjectsCount: mockProjectsCount,
    noDoraDataProjectsCount: mockProjectsCount,
    mockDataResponse: mockEmptyDoraPerformersScoreResponseData,
  });
  const higherNoDoraDataProjectsCount = mockGraphqlDoraPerformanceScoreCountsResponse({
    totalProjectsCount: mockProjectsCount,
    noDoraDataProjectsCount: mockProjectsCount + 1,
    mockDataResponse: mockEmptyDoraPerformersScoreResponseData,
  });
  const mockGroupBy = [
    'Deployment frequency (Velocity)',
    'Lead time for changes (Velocity)',
    'Time to restore service (Quality)',
    'Change failure rate (Quality)',
  ];
  const panelTitleWithProjectsCount = (projectsCount = mockProjectsCount) =>
    `Total projects (${projectsCount}) with DORA metrics`;

  let wrapper;
  let mockApollo;

  const createWrapper = async ({
    props = {},
    doraPerformanceScoreCountsHandler = doraPerformanceScoreCountsSuccess,
  } = {}) => {
    mockApollo = createMockApollo([
      [groupDoraPerformanceScoreCountsQuery, doraPerformanceScoreCountsHandler],
    ]);

    wrapper = shallowMountExtended(DoraPerformersScoreChart, {
      apolloProvider: mockApollo,
      propsData: {
        data: mockData,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });

    await waitForPromises();
  };

  const findDoraPerformersScoreChart = () => wrapper.findComponent(GlStackedColumnChart);
  const findDoraPerformersScoreChartTitle = () =>
    wrapper.findByTestId('dora-performers-score-chart-title');
  const findChartSkeletonLoader = () => wrapper.findComponent(ChartSkeletonLoader);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findPanelTitleHelpIcon = () => wrapper.findComponent(GlIcon);
  const findExcludedProjectsTooltip = () =>
    getBinding(findPanelTitleHelpIcon().element, 'gl-tooltip');

  afterEach(() => {
    mockApollo = null;
  });

  describe('default', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders panel title with total project count', () => {
      expect(findDoraPerformersScoreChartTitle().text()).toBe(panelTitleWithProjectsCount());
    });

    it('does not render panel title tooltip', () => {
      expect(findPanelTitleHelpIcon().exists()).toBe(false);
    });

    it('renders the chart', () => {
      expect(findDoraPerformersScoreChart().props()).toMatchObject({
        bars: mockDoraPerformersScoreChartData,
        customPalette: DORA_PERFORMERS_SCORE_CHART_COLOR_PALETTE,
        groupBy: mockGroupBy,
        presentation: 'tiled',
        xAxisType: 'category',
        xAxisTitle: '',
        yAxisTitle: '',
        includeLegendAvgMax: false,
      });
    });
  });

  describe('when projects with no DORA data have been excluded', () => {
    describe.each`
      totalProjectsCount | noDoraDataProjectsCount | projectsCountWithDoraData | tooltipText
      ${20}              | ${10}                   | ${10}                     | ${'Excluding 10 projects with no DORA metrics'}
      ${5}               | ${1}                    | ${4}                      | ${'Excluding 1 project with no DORA metrics'}
    `(
      'renders tooltip in panel title with correct number of excluded projects',
      ({ totalProjectsCount, noDoraDataProjectsCount, projectsCountWithDoraData, tooltipText }) => {
        beforeEach(async () => {
          await createWrapper({
            doraPerformanceScoreCountsHandler: mockGraphqlDoraPerformanceScoreCountsResponse({
              totalProjectsCount,
              noDoraDataProjectsCount,
            }),
          });
        });

        it('renders panel title with correct total projects count with DORA data', () => {
          expect(findDoraPerformersScoreChartTitle().text()).toBe(
            panelTitleWithProjectsCount(projectsCountWithDoraData),
          );
        });

        it('renders tooltip in panel title with correct number of excluded projects', () => {
          expect(findExcludedProjectsTooltip().value).toBe(tooltipText);
        });
      },
    );
  });

  describe('when fetching data', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders chart skeleton loader', () => {
      expect(findChartSkeletonLoader().exists()).toBe(true);
    });

    it('renders skeleton loader instead of panel title', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findDoraPerformersScoreChartTitle().exists()).toBe(false);
    });
  });

  describe.each`
    emptyState                                          | response
    ${'noDoraDataProjectsCount === totalProjectsCount'} | ${noProjectsWithDoraData}
    ${'noDoraDataProjectsCount > totalProjectsCount'}   | ${higherNoDoraDataProjectsCount}
  `('when $emptyState', ({ response }) => {
    beforeEach(async () => {
      await createWrapper({ doraPerformanceScoreCountsHandler: response });
    });

    it('renders empty state message', () => {
      const noDataMessage = `No data available for Group: ${fullPath}`;
      expect(wrapper.findByText(noDataMessage).exists()).toBe(true);
    });

    it('renders panel title with `0` projects with DORA data', () => {
      expect(findDoraPerformersScoreChartTitle().text()).toBe(panelTitleWithProjectsCount(0));
    });

    it('does not render panel title tooltip', () => {
      expect(findPanelTitleHelpIcon().exists()).toBe(false);
    });

    it('does not render chart', () => {
      expect(findDoraPerformersScoreChart().exists()).toBe(false);
    });
  });

  describe('fails to fetch data', () => {
    beforeEach(async () => {
      const doraPerformanceScoreCountsHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('Something went wrong'));
      await createWrapper({ doraPerformanceScoreCountsHandler });
    });

    it('emits an error event', () => {
      const emitted = wrapper.emitted('error');
      expect(emitted).toHaveLength(1);
      expect(emitted[0]).toEqual([`Failed to load DORA performance scores for Group: ${fullPath}`]);
    });
  });

  describe('project topics filter', () => {
    const findFilterBadges = () => wrapper.findComponent(FilterProjectTopicsBadges);

    it('renders the filter badges when provided', async () => {
      const topics = ['one', 'two'];
      await createWrapper({
        props: { data: { ...mockData, filters: { projectTopics: topics } } },
      });
      expect(findFilterBadges().exists()).toBe(true);
      expect(findFilterBadges().props('topics')).toEqual(topics);
    });

    it('does not render the filter badges when none provided', async () => {
      await createWrapper();
      expect(findFilterBadges().exists()).toBe(false);
    });

    it('filters out invalid project topics', async () => {
      const topics = ['one', 'two\n'];
      await createWrapper({
        props: { data: { ...mockData, filters: { projectTopics: topics } } },
      });
      expect(findFilterBadges().exists()).toBe(true);
      expect(findFilterBadges().props('topics')).toEqual(['one']);
    });
  });
});
