import { GlIcon, GlTruncateText } from '@gitlab/ui';
import { visitUrl } from '~/lib/utils/url_utility';
import DashboardListItem from 'ee/analytics/analytics_dashboards/components/list/dashboard_list_item.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE,
  mockInvalidDashboardErrors,
} from '../../mock_data';

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

const { nodes } = TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data.project.customizableDashboards;

const USER_DEFINED_DASHBOARD = nodes.find((dashboard) => dashboard.userDefined);
const BUILT_IN_DASHBOARD = nodes.find((dashboard) => !dashboard.userDefined);

const REDIRECTED_DASHBOARD = {
  title: 'title',
  description: 'description',
  slug: '/slug',
  redirect: true,
};

const BETA_DASHBOARD = {
  title: 'title',
  description: 'description',
  slug: '/slug',
  status: 'beta',
  userDefined: false, // Built-in dashboard
};

const INVALID_DASHBOARD = {
  title: 'title',
  description: 'description',
  slug: '/slug',
  errors: mockInvalidDashboardErrors,
};

describe('DashboardsListItem', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findBuiltInBadge = () => wrapper.findByTestId('dashboard-by-gitlab');
  const findListItem = () => wrapper.findByTestId('dashboard-list-item');
  const findRedirectLink = () => wrapper.findByTestId('dashboard-redirect-link');
  const findRouterLink = () => wrapper.findByTestId('dashboard-router-link');
  const findDescriptionTruncate = () => wrapper.findComponent(GlTruncateText);
  const findStatusBadge = () => wrapper.findComponentByTestId('dashboard-status-badge');
  const findErrorsBadge = () => wrapper.findComponentByTestId('dashboard-errors-badge');

  const $router = {
    push: jest.fn(),
  };

  const createWrapper = (props, mountFn = shallowMountExtended) => {
    wrapper = mountFn(DashboardListItem, {
      propsData: {
        ...props,
      },
      stubs: {
        RouterLink: true,
      },
      mocks: {
        $router,
      },
    });
  };

  describe('by default', () => {
    beforeEach(() => {
      createWrapper({ dashboard: USER_DEFINED_DASHBOARD });
    });

    it('renders the dashboard title', () => {
      expect(findRouterLink().text()).toContain(USER_DEFINED_DASHBOARD.title);
    });

    it('renders the dashboard description', () => {
      expect(findDescriptionTruncate().text()).toContain(USER_DEFINED_DASHBOARD.description);
    });

    it('renders the dashboard icon', () => {
      expect(findIcon().props()).toMatchObject({
        name: 'dashboard',
        size: 16,
      });
    });

    it('does not render the built in label', () => {
      expect(findBuiltInBadge().exists()).toBe(false);
    });

    it('does not render a status badge', () => {
      expect(findStatusBadge().exists()).toBe(false);
    });

    it('does not render errors badge', () => {
      expect(findErrorsBadge().exists()).toBe(false);
    });

    it('routes to the dashboard when a list item is clicked', async () => {
      await findListItem().trigger('click');

      expect($router.push).toHaveBeenCalledWith(USER_DEFINED_DASHBOARD.slug);
    });
  });

  describe('with a built in dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: BUILT_IN_DASHBOARD });
    });

    it('renders the dashboard badge', () => {
      expect(findBuiltInBadge().text()).toBe('Created by GitLab');
    });
  });

  describe('with a redirected dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: REDIRECTED_DASHBOARD });
    });

    it('renders the dashboard title', () => {
      expect(findRedirectLink().text()).toContain(REDIRECTED_DASHBOARD.title);
    });

    it('redirects to the dashboard when the list item is clicked', async () => {
      await findListItem().trigger('click');

      expect(visitUrl).toHaveBeenCalledWith(expect.stringContaining(REDIRECTED_DASHBOARD.slug));
    });
  });

  describe('with a beta built-in dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: BETA_DASHBOARD });
    });

    it('renders the `Beta` badge', () => {
      expect(findStatusBadge().props('type')).toBe('beta');
    });
  });

  describe('with a beta custom dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: { ...BETA_DASHBOARD, userDefined: true } });
    });

    it('does not render the `Beta` badge for custom dashboards', () => {
      expect(findStatusBadge().exists()).toBe(false);
    });
  });

  describe('with an experiment built-in dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: { ...BETA_DASHBOARD, status: 'experiment' } });
    });

    it('renders the `Experiment` badge', () => {
      expect(findStatusBadge().props('type')).toBe('experiment');
    });
  });

  describe('with an experiment custom dashboard', () => {
    beforeEach(() => {
      createWrapper({
        dashboard: { ...BETA_DASHBOARD, userDefined: true, status: 'experiment' },
      });
    });

    it('does not render the `Experiment` badge for custom dashboards', () => {
      expect(findStatusBadge().exists()).toBe(false);
    });
  });

  describe('with an invalid dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboard: INVALID_DASHBOARD });
    });

    it('renders the errors badge', () => {
      expect(findErrorsBadge().props()).toMatchObject({
        icon: 'error',
        iconSize: 'sm',
        variant: 'danger',
      });
      expect(findErrorsBadge().text()).toBe('Contains errors');
    });
  });
});
