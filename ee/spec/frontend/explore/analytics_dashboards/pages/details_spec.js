import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import ExploreAnalyticsDashboardDetailsEE from 'ee/explore/analytics_dashboards/pages/details.vue';
import ExploreAnalyticsDashboardDetails from '~/explore/analytics_dashboards/pages/details.vue';

describe('ExploreAnalyticsDashboardDetailsEE', () => {
  let wrapper;

  const createComponent = ({ routeParams = { slug: '123' }, isSystemDashboard = false } = {}) => {
    wrapper = shallowMountExtended(ExploreAnalyticsDashboardDetailsEE, {
      mocks: { $route: { params: routeParams } },
      stubs: {
        // Render the CE component's #actions slot so the EE Edit button is mounted,
        // forwarding isSystemDashboard exactly as the CE component does.
        ExploreAnalyticsDashboardDetails: stubComponent(ExploreAnalyticsDashboardDetails, {
          template: `<div><slot name="actions" :is-system-dashboard="${isSystemDashboard}"></slot></div>`,
        }),
      },
    });
  };

  const findEditButton = () => wrapper.findComponentByTestId('dashboard-edit-button');

  beforeEach(() => {
    createComponent();
  });

  it('renders the CE dashboard details component', () => {
    expect(wrapper.findComponent(ExploreAnalyticsDashboardDetails).exists()).toBe(true);
  });

  describe('edit button', () => {
    it('renders an Edit button with the pencil icon', () => {
      expect(findEditButton().exists()).toBe(true);
      expect(findEditButton().props('icon')).toBe('pencil');
      expect(findEditButton().text()).toBe('Edit');
    });

    it('links to the edit page for the current dashboard', () => {
      expect(findEditButton().props('to')).toEqual({
        name: 'dashboard-edit',
        params: { slug: '123' },
      });
    });
  });

  describe('when viewing a system dashboard', () => {
    beforeEach(() => {
      createComponent({ isSystemDashboard: true });
    });

    it('does not render the Edit button', () => {
      expect(findEditButton().exists()).toBe(false);
    });
  });
});
