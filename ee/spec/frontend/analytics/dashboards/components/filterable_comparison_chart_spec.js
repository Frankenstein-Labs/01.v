import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { GlSkeletonLoader } from '@gitlab/ui';
import FilterableComparisonChart from 'ee/analytics/dashboards/components/filterable_comparison_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { METRICS_WITHOUT_LABEL_FILTERING } from 'ee/analytics/dashboards/constants';
import ComparisonChartLabels from 'ee/analytics/dashboards/components/comparison_chart_labels.vue';
import ComparisonChart from 'ee/analytics/dashboards/components/comparison_chart.vue';
import filterLabelsQueryBuilder from '~/analytics/dashboards/graphql/filter_labels_query_builder';
import { mockFilterLabelsResponse } from '../helpers';

Vue.use(VueApollo);

describe('FilterableComparisonChart', () => {
  let wrapper;

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findComparisonChart = () => wrapper.findComponent(ComparisonChart);
  const findComparisonChartLabels = () => wrapper.findComponent(ComparisonChartLabels);

  const excludeMetrics = ['cycle_time'];
  const labels = ['test::one', 'test::two'];

  const groupWebUrl = 'group/web/url';
  const projectWebUrl = 'project/web/url';

  const groupNamespace = 'group-namespace';
  const projectNamespace = 'group-namespace/project';

  const createWrapper = async ({
    namespace = groupNamespace,
    isProject = false,
    webUrl = groupWebUrl,
    isLoading = false,
    filters = {},
    filterLabelsResolver = null,
  } = {}) => {
    const { labels: filterLabels = [] } = filters;
    const apolloProvider = createMockApollo([
      [
        filterLabelsQueryBuilder(filterLabels, isProject),
        filterLabelsResolver ||
          jest.fn().mockResolvedValue({ data: mockFilterLabelsResponse(filterLabels) }),
      ],
    ]);

    wrapper = shallowMountExtended(FilterableComparisonChart, {
      apolloProvider,
      propsData: {
        namespace,
        isProject,
        webUrl,
        isLoading,
        filters: {
          labels: filterLabels,
          excludeMetrics: [],
          ...filters,
        },
      },
    });

    await waitForPromises();
  };

  describe('default', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('does not render the skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('does not emit an error', () => {
      expect(wrapper.emitted('set-alerts')).toBeUndefined();
    });

    it('does not render the chart labels', () => {
      expect(findComparisonChartLabels().exists()).toBe(false);
    });

    it('renders the chart', () => {
      expect(findComparisonChart().props()).toEqual({
        excludeMetrics: [],
        filterLabels: [],
        isProject: false,
        requestPath: 'group-namespace',
      });
    });

    it('propagates `set-alerts` event from the chart', () => {
      const payload = { errors: ['test'] };
      findComparisonChart().vm.$emit('set-alerts', payload);
      expect(wrapper.emitted('set-alerts')[0]).toEqual([payload]);
    });
  });

  describe('with filters', () => {
    describe('error loading filters', () => {
      beforeEach(async () => {
        await createWrapper({
          filters: { labels },
          filterLabelsResolver: jest.fn().mockRejectedValue(),
        });
      });

      it('emits the `set-alerts` event', () => {
        expect(wrapper.emitted('set-alerts')[0]).toEqual([
          { errors: ['Failed to load labels matching the filter: test::one, test::two'] },
        ]);
      });

      it('does not render the chart labels', () => {
        expect(findComparisonChartLabels().exists()).toBe(false);
      });
    });

    describe('labels', () => {
      beforeEach(async () => {
        await createWrapper({ filters: { labels } });
      });

      it('does not render the skeleton loader', () => {
        expect(findSkeletonLoader().exists()).toBe(false);
      });

      it('renders the chart', () => {
        expect(findComparisonChart().props()).toEqual({
          excludeMetrics: METRICS_WITHOUT_LABEL_FILTERING,
          filterLabels: labels,
          isProject: false,
          requestPath: 'group-namespace',
        });
      });

      it('renders the chart labels', () => {
        expect(findComparisonChartLabels().props()).toEqual({
          webUrl: groupWebUrl,
          labels: [
            {
              color: '#FFFFFF',
              id: 'test::one',
              title: 'test::one',
            },
            {
              color: '#FFFFFF',
              id: 'test::two',
              title: 'test::two',
            },
          ],
        });
      });

      describe('with duplicate labels', () => {
        beforeEach(async () => {
          await createWrapper({ filters: { labels: [...labels, ...labels] } });
        });

        it('removes duplicates result', () => {
          expect(findComparisonChart().props('filterLabels')).toHaveLength(2);
        });
      });
    });

    describe('excludeMetrics', () => {
      beforeEach(() => {
        createWrapper({ filters: { excludeMetrics } });
      });

      it('does not render the chart labels', () => {
        expect(findComparisonChartLabels().exists()).toBe(false);
      });

      it('renders the chart', () => {
        expect(findComparisonChart().props()).toEqual({
          excludeMetrics: ['cycle_time'],
          filterLabels: [],
          isProject: false,
          requestPath: 'group-namespace',
        });
      });
    });

    describe('with excludeMetrics and labels', () => {
      beforeEach(async () => {
        await createWrapper({ filters: { excludeMetrics, labels } });
      });

      it('will exclude incompatible metrics', () => {
        expect(findComparisonChart().props()).toEqual(
          expect.objectContaining({
            filterLabels: labels,
            excludeMetrics: ['cycle_time', ...METRICS_WITHOUT_LABEL_FILTERING],
            isProject: false,
            requestPath: 'group-namespace',
          }),
        );
      });
    });
  });

  describe('while loading', () => {
    beforeEach(() => {
      createWrapper({ isLoading: true });
    });

    it('renders the skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render the chart', () => {
      expect(findComparisonChart().exists()).toBe(false);
    });

    it('does not render the chart labels', () => {
      expect(findComparisonChartLabels().exists()).toBe(false);
    });

    it('does not emit an error', () => {
      expect(wrapper.emitted('set-alerts')).toBeUndefined();
    });
  });

  describe('with a project', () => {
    beforeEach(async () => {
      await createWrapper({ webUrl: projectWebUrl, isProject: true, namespace: projectNamespace });
    });

    it('renders the chart for project', () => {
      expect(findComparisonChart().props()).toEqual({
        excludeMetrics: [],
        filterLabels: [],
        isProject: true,
        requestPath: 'group-namespace/project',
      });
    });
  });
});
