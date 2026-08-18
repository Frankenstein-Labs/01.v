import { observable, resetObservable } from '~/lib/utils/observable';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createRouter from '~/explore/analytics_dashboards/router';
import App from '~/explore/analytics_dashboards/pages/app.vue';

const BREADCRUMB_STATE_KEY = 'explore_analytics_dashboards_breadcrumb';

describe('EE ExploreAnalyticsDashboards', () => {
  const basePath = '/explore/analytics_dashboards';

  let breadcrumbState;
  let router;

  beforeEach(() => {
    breadcrumbState = observable(BREADCRUMB_STATE_KEY, { name: '', slug: '' });
    router = createRouter(basePath, breadcrumbState);
  });

  // observable() ignores its defaults once the key exists, so the name would
  // otherwise persist into the next test.
  afterEach(() => {
    resetObservable(BREADCRUMB_STATE_KEY);
  });

  const createWrapper = () => {
    shallowMountExtended(App, {
      router,
      propsData: { currentUserId: 'gid://gitlab/User/1' },
    });
  };

  describe('document title', () => {
    const baseTitle = 'Analytics dashboards · GitLab';

    // Captured in data() on mount, so it has to be in place before createWrapper.
    beforeEach(() => {
      document.title = baseTitle;
    });

    afterEach(() => {
      document.title = '';
    });

    it('prepends the edit and dashboard segments on the edit route', async () => {
      breadcrumbState.name = 'My dashboard';
      await router.push('/3/edit');

      createWrapper();

      expect(document.title).toBe(`Edit · My dashboard · ${baseTitle}`);
    });
  });
});
