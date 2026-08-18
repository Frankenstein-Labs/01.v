import { shallowMount } from '@vue/test-utils';
import ContributionsIssuesChart from 'ee/analytics/analytics_dashboards/components/visualizations/contributions/contributions_issues_chart.vue';
import IssuesChart from 'ee/analytics/contribution_analytics/components/issues_chart.vue';
import { MOCK_ISSUES } from 'ee_jest/analytics/contribution_analytics/mock_data';

describe('ContributionsIssuesChart', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(ContributionsIssuesChart, {
      propsData: {
        data: [...MOCK_ISSUES],
        options: props.options,
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders the IssuesChart component', () => {
    expect(wrapper.findComponent(IssuesChart).exists()).toBe(true);
  });

  it('passes the data prop correctly to IssuesChart', () => {
    expect(wrapper.findComponent(IssuesChart).props('issues')).toEqual(MOCK_ISSUES);
  });
});
