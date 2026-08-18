import { shallowMount } from '@vue/test-utils';
import AnalyticsDashboardsApp from 'ee/analytics/analytics_dashboards/dashboards_app.vue';
import createRouter from 'ee/analytics/analytics_dashboards/router';

describe('AnalyticsDashboardsApp', () => {
  let wrapper;

  const findRouterView = () => wrapper.findComponent({ ref: 'router-view' });

  const createWrapper = () => {
    wrapper = shallowMount(AnalyticsDashboardsApp, {
      router: createRouter(),
    });
  };

  describe('when mounted', () => {
    it('should render', () => {
      createWrapper();
      expect(findRouterView().exists()).toBe(true);
    });
  });
});
