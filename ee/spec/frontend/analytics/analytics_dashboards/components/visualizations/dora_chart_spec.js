import { GlLoadingIcon } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DoraChart from 'ee/analytics/analytics_dashboards/components/visualizations/dora_chart.vue';
import FilterableComparisonChart from 'ee/analytics/dashboards/components/filterable_comparison_chart.vue';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';
import GetGroupOrProjectQuery from '~/analytics/dashboards/graphql/get_group_or_project.query.graphql';
import { mockGroup } from 'ee_jest/analytics/dashboards/mock_data';

Vue.use(VueApollo);

describe('DoraChart Visualization', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let mockGroupOrProjectRequestHandler;

  const namespace = 'some/fake/path';

  const excludeMetrics = ['metric_one', 'metric_two'];
  const filterLabels = ['label_a'];

  const defaultData = {
    namespace,
    filters: {
      excludeMetrics,
      labels: filterLabels,
    },
  };

  const findChart = () => wrapper.findComponent(FilterableComparisonChart);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(DoraChart, {
      apolloProvider: createMockApollo([
        [GetGroupOrProjectQuery, mockGroupOrProjectRequestHandler],
      ]),
      propsData: {
        data: defaultData,
        options: {},
        ...props,
      },
      stubs: { GroupOrProjectProvider },
    });
  };

  afterEach(() => {
    mockGroupOrProjectRequestHandler = null;
  });

  describe('when loading', () => {
    beforeEach(() => {
      mockGroupOrProjectRequestHandler = jest.fn().mockImplementation(() => new Promise(() => {}));

      createWrapper();
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the comparison chart component', () => {
      expect(findChart().exists()).toBe(false);
    });
  });

  describe('when mounted', () => {
    beforeEach(() => {
      mockGroupOrProjectRequestHandler = jest
        .fn()
        .mockReturnValueOnce({ data: { group: mockGroup, project: null } });

      createWrapper();
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('resolves the namespace', () => {
      expect(mockGroupOrProjectRequestHandler).toHaveBeenCalledWith({ fullPath: namespace });
    });

    it('renders the comparison chart component', () => {
      expect(findChart().props()).toMatchObject({
        namespace,
        filters: {
          excludeMetrics,
          labels: filterLabels,
        },
        webUrl: 'gdk.test/groups/group-10',
      });
    });

    it('echos `set-alerts` event from the comparison chart', () => {
      const payload = { errors: ['one', 'two'] };
      findChart().vm.$emit('set-alerts', payload);

      expect(wrapper.emitted('set-alerts')).toHaveLength(1);
      expect(wrapper.emitted('set-alerts')[0][0]).toEqual(payload);
    });
  });
});
