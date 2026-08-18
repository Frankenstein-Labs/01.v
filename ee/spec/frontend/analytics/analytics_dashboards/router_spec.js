import createRouter from 'ee/analytics/analytics_dashboards/router';
import DashboardsList from 'ee/analytics/analytics_dashboards/components/dashboards_list.vue';
import AnalyticsDashboard from 'ee/analytics/analytics_dashboards/components/analytics_dashboard.vue';

describe('Dashboards list router', () => {
  const base = '/dashboard';
  const breadcrumbState = {
    updateName: jest.fn(),
    name: '',
  };

  let router = null;
  afterEach(() => {
    router = null;
    breadcrumbState.name = '';
  });

  it('returns a router object', () => {
    router = createRouter(base, breadcrumbState);

    // vue-router v3 and v4 store base at different locations
    expect(router.history?.base ?? router.options.history?.base).toBe(base);
  });

  describe('router', () => {
    beforeEach(() => {
      router = createRouter(base, breadcrumbState);
    });

    it.each`
      path                   | component             | name
      ${'/'}                 | ${DashboardsList}     | ${'Analytics dashboards'}
      ${'/test-dashboard-1'} | ${AnalyticsDashboard} | ${'Test dashboard 1'}
      ${'/test-dashboard-2'} | ${AnalyticsDashboard} | ${'Test dashboard 2'}
    `('sets component as $component.name for path "$path"', async ({ path, component, name }) => {
      breadcrumbState.name = name;

      try {
        await router.push(path);
      } catch {
        // intentionally blank
        //
        // * in Vue.js 3 we need to refresh even '/' route
        // because we dynamically add routes and exception will not be raised
        //
        // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
      }

      const [root] = router.currentRoute.matched;

      expect(router.currentRoute.meta.getName()).toBe(name);
      expect(root.components.default).toBe(component);
    });

    it('sets the root meta attribute to true for the root route', async () => {
      try {
        await router.push('/');
      } catch {
        // intentionally blank
        //
        // * in Vue.js 3 we need to refresh even '/' route
        // because we dynamically add routes and exception will not be raised
        //
        // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
      }

      expect(router.currentRoute.meta.root).toBe(true);
    });

    it('redirects the legacy AI impact dashboard route', async () => {
      await router.push('/ai_impact');
      expect(router.currentRoute.path).toBe('/duo_and_sdlc_trends');
    });
  });
});
