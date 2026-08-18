import { shallowMount } from '@vue/test-utils';
import ContributionsPushesChart from 'ee/analytics/analytics_dashboards/components/visualizations/contributions/contributions_pushes_chart.vue';
import PushesChart from 'ee/analytics/contribution_analytics/components/pushes_chart.vue';
import { MOCK_PUSHES } from 'ee_jest/analytics/contribution_analytics/mock_data';

describe('ContributionsPushesChart', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(ContributionsPushesChart, {
      propsData: {
        data: [...MOCK_PUSHES],
        options: props.options,
      },
    });
  };
  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders the PushesChart component', () => {
    expect(wrapper.findComponent(PushesChart).exists()).toBe(true);
  });

  it('passes the data prop correctly to PushesChart', () => {
    expect(wrapper.findComponent(PushesChart).props('pushes')).toEqual(MOCK_PUSHES);
  });
});
