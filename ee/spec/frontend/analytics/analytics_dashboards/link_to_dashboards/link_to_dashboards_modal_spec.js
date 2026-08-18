import { GlModal, GlSearchBoxByType } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import LinkToDashboardModal from 'ee/analytics/analytics_dashboards/link_to_dashboards/link_to_dashboards_modal.vue';
import DashboardFrequentProjects from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_frequent_projects.vue';
import DashboardFrequentGroups from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_frequent_groups.vue';
import DashboardSearchResults from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_search_results.vue';

describe('LinkToDashboardModal', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(LinkToDashboardModal, {
      propsData: {
        dashboardName: 'duo_and_sdlc_trends',
        ...props,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByType);
  const findFrequentProjects = () => wrapper.findComponent(DashboardFrequentProjects);
  const findFrequentGroups = () => wrapper.findComponent(DashboardFrequentGroups);
  const findSearchResults = () => wrapper.findComponent(DashboardSearchResults);

  afterEach(() => {
    wrapper?.destroy();
  });

  describe('modal configuration', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlModal with correct ID and title', () => {
      expect(findModal().props()).toMatchObject({
        modalId: 'link-to-dashboard-modal',
        title: 'Select a group or project for this analytics dashboard',
      });
    });
  });

  describe('search box', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders search box', () => {
      expect(findSearchBox().exists()).toBe(true);
    });
  });

  describe('default view (no search)', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders frequent projects component', () => {
      expect(findFrequentProjects().exists()).toBe(true);
      expect(findFrequentProjects().props('dashboardName')).toBe('duo_and_sdlc_trends');
    });

    it('renders frequent groups component with correct props', () => {
      expect(findFrequentGroups().exists()).toBe(true);
      expect(findFrequentGroups().props('dashboardName')).toBe('duo_and_sdlc_trends');
      expect(findFrequentGroups().attributes('bordered')).toBeDefined();
      expect(findFrequentGroups().classes()).toContain('gl-mt-3');
    });

    it('does not render search results', () => {
      expect(findSearchResults().exists()).toBe(false);
    });
  });

  describe('search view', () => {
    beforeEach(async () => {
      createComponent();
      await findSearchBox().vm.$emit('input', 'test');
    });

    it('renders search results component', () => {
      expect(findSearchResults().exists()).toBe(true);
      expect(findSearchResults().props()).toMatchObject({
        searchTerm: 'test',
        dashboardName: 'duo_and_sdlc_trends',
      });
    });

    it('does not render frequent projects', () => {
      expect(findFrequentProjects().exists()).toBe(false);
    });

    it('does not render frequent groups', () => {
      expect(findFrequentGroups().exists()).toBe(false);
    });
  });

  describe('modal hidden event', () => {
    beforeEach(async () => {
      createComponent();
      await findSearchBox().vm.$emit('input', 'test search');
    });

    it('clears search and shows default items when modal is hidden', async () => {
      // Verify search results are shown
      expect(findSearchResults().exists()).toBe(true);
      expect(findFrequentProjects().exists()).toBe(false);

      await findModal().vm.$emit('hidden');

      // Verify default items are shown again (effect of clearing search)
      expect(findSearchResults().exists()).toBe(false);
      expect(findFrequentProjects().exists()).toBe(true);
      expect(findFrequentGroups().exists()).toBe(true);
    });
  });
});
