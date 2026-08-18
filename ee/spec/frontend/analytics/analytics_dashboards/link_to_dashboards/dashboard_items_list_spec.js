import { GlDisclosureDropdownGroup, GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DashboardItemsList from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_items_list.vue';
import FrequentItem from '~/super_sidebar/components/global_search/components/frequent_item.vue';
import FrequentItemSkeleton from '~/super_sidebar/components/global_search/components/frequent_item_skeleton.vue';
import { TRACKING_ACTION_CLICK_DASHBOARD_ITEM } from 'ee/analytics/analytics_dashboards/link_to_dashboards/tracking';

describe('DashboardItemsList', () => {
  let wrapper;

  const mockItems = [
    {
      id: 'gid://gitlab/Project/1',
      name: 'Project 1',
      namespace: 'namespace/project-1',
      avatarUrl: '/avatar1.png',
      fullPath: 'namespace/project-1',
    },
    {
      id: 'gid://gitlab/Project/2',
      name: 'Project 2',
      namespace: 'namespace/project-2',
      avatarUrl: '/avatar2.png',
      fullPath: 'namespace/project-2',
    },
  ];

  const defaultProps = {
    loading: false,
    emptyStateText: 'No items found',
    groupName: 'Test Group',
    items: mockItems,
    isGroup: false,
    dashboardName: 'duo_and_sdlc_trends',
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(DashboardItemsList, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findDisclosureDropdownGroup = () => wrapper.findComponent(GlDisclosureDropdownGroup);
  const findDisclosureDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findFrequentItems = () => wrapper.findAllComponents(FrequentItem);
  const findFrequentItemSkeleton = () => wrapper.findComponent(FrequentItemSkeleton);
  const findEmptyState = () => wrapper.findByText(defaultProps.emptyStateText);

  afterEach(() => {
    wrapper?.destroy();
  });

  describe('rendering', () => {
    it('renders GlDisclosureDropdownGroup', () => {
      createComponent();

      expect(findDisclosureDropdownGroup().exists()).toBe(true);
    });

    it('renders loading skeleton when loading is true', () => {
      createComponent({ props: { loading: true } });

      expect(findFrequentItemSkeleton().exists()).toBe(true);
      expect(findFrequentItems()).toHaveLength(0);
    });

    it('renders empty state when not loading and items are empty', () => {
      createComponent({ props: { items: [] } });

      expect(findEmptyState().exists()).toBe(true);
      expect(findFrequentItems()).toHaveLength(0);
    });

    it('does not render empty state when loading', () => {
      createComponent({ props: { loading: true, items: [] } });

      expect(findEmptyState().exists()).toBe(false);
    });

    it('renders items when not loading and items exist', () => {
      createComponent();

      expect(findDisclosureDropdownItems()).toHaveLength(2);
      expect(findFrequentItems()).toHaveLength(2);
    });
  });

  describe('formatted items', () => {
    beforeEach(() => {
      createComponent();
    });

    it('generates correct dashboard href for projects', () => {
      const firstItem = findDisclosureDropdownItems().at(0);

      expect(firstItem.props('item').href).toBe(
        '/namespace/project-1/-/analytics/dashboards/duo_and_sdlc_trends',
      );
    });

    it('generates correct dashboard href for groups', () => {
      createComponent({ props: { isGroup: true } });
      const firstItem = findDisclosureDropdownItems().at(0);

      expect(firstItem.props('item').href).toBe(
        '/groups/namespace/project-1/-/analytics/dashboards/duo_and_sdlc_trends',
      );
    });

    it('includes tracking attributes for projects', () => {
      const firstItem = findDisclosureDropdownItems().at(0);
      const { extraAttrs } = firstItem.props('item');

      expect(extraAttrs['data-track-action']).toBe(TRACKING_ACTION_CLICK_DASHBOARD_ITEM);
      expect(extraAttrs['data-track-label']).toBe('project');
      expect(extraAttrs['data-track-property']).toBe('duo_and_sdlc_trends');
    });

    it('includes tracking attributes for groups', () => {
      createComponent({ props: { isGroup: true } });
      const firstItem = findDisclosureDropdownItems().at(0);
      const { extraAttrs } = firstItem.props('item');

      expect(extraAttrs['data-track-action']).toBe(TRACKING_ACTION_CLICK_DASHBOARD_ITEM);
      expect(extraAttrs['data-track-label']).toBe('group');
      expect(extraAttrs['data-track-property']).toBe('duo_and_sdlc_trends');
    });

    it('passes correct props to FrequentItem', () => {
      const firstFrequentItem = findFrequentItems().at(0);

      expect(firstFrequentItem.props('item')).toEqual({
        id: 'gid://gitlab/Project/1',
        title: 'Project 1',
        subtitle: 'namespace/project-1',
        avatar: '/avatar1.png',
      });
    });
  });

  it('passes attributes to GlDisclosureDropdownGroup', () => {
    wrapper = shallowMountExtended(DashboardItemsList, {
      propsData: defaultProps,
      attrs: {
        bordered: true,
        class: 'custom-class',
      },
    });

    expect(findDisclosureDropdownGroup().attributes()).toMatchObject({
      bordered: 'true',
      class: 'custom-class',
    });
  });
});
