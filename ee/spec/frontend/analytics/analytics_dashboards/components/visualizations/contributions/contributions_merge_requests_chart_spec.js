import { shallowMount } from '@vue/test-utils';
import ContributionsMergeRequestsChart from 'ee/analytics/analytics_dashboards/components/visualizations/contributions/contributions_merge_requests_chart.vue';
import MergeRequestsChart from 'ee/analytics/contribution_analytics/components/merge_requests_chart.vue';
import { MOCK_MERGE_REQUESTS } from 'ee_jest/analytics/contribution_analytics/mock_data';

describe('ContributionsMergeRequestsChart', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(ContributionsMergeRequestsChart, {
      propsData: {
        data: [...MOCK_MERGE_REQUESTS],
        options: props.options,
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders the MergeRequestsChart component', () => {
    expect(wrapper.findComponent(MergeRequestsChart).exists()).toBe(true);
  });

  it('passes the data prop correctly to MergeRequestsChart', () => {
    expect(wrapper.findComponent(MergeRequestsChart).props('mergeRequests')).toEqual(
      MOCK_MERGE_REQUESTS,
    );
  });
});
