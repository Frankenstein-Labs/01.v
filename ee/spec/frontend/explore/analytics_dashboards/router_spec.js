import createRouter from '~/explore/analytics_dashboards/router';
import DashboardEdit from 'ee/explore/analytics_dashboards/pages/edit.vue';

// Vue Router 3 returns { route } from resolve(), Vue Router 4 returns the route directly.
const resolveRoute = (router, path) => {
  const resolved = router.resolve(path);
  return resolved.route ?? resolved;
};

describe('EE analytics dashboards router', () => {
  const basePath = '/explore/analytics_dashboards';
  const breadcrumbState = { name: 'Some dashboard', slug: '3' };

  let router;

  beforeEach(() => {
    router = createRouter(basePath, breadcrumbState);
  });

  describe('dashboard-edit route', () => {
    it('is registered when the router is constructed', () => {
      const names = router.options.routes.map(({ name }) => name);

      expect(names).toContain('dashboard-edit');
    });

    it('matches a custom dashboard ID', () => {
      const route = resolveRoute(router, '/3/edit');

      expect(route.name).toBe('dashboard-edit');
      expect(route.params.slug).toBe('3');
      expect(route.matched[0].components.default).toBe(DashboardEdit);
    });

    it('returns the breadcrumb name from breadcrumbState', () => {
      const route = resolveRoute(router, '/3/edit');

      expect(route.meta.getName()).toBe('Edit');
    });

    it('returns the parent breadcrumbs from breadcrumbState', () => {
      const route = resolveRoute(router, '/3/edit');

      expect(route.meta.getParents()).toEqual([{ text: 'Some dashboard', to: '/3' }]);
    });
  });
});
