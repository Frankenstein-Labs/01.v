import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RecentlyViewedItems from '~/homepage/components/recently_viewed_items.vue';
import TooltipOnTruncate from '~/vue_shared/components/tooltip_on_truncate/tooltip_on_truncate.vue';
import RecentlyViewedItemsQuery from 'ee_else_ce/homepage/graphql/queries/recently_viewed_items.query.graphql';

Vue.use(VueApollo);

describe('RecentlyViewedItems EE', () => {
  let wrapper;

  const mockRecentlyViewedResponse = {
    data: {
      currentUser: {
        id: 123,
        recentlyViewedItems: [
          {
            viewedAt: '2025-06-19T15:30:00Z',
            item: {
              __typename: 'WorkItem',
              id: 'work-item-epic-1',
              title: 'Q3 Development Roadmap',
              webUrl: '/groups/company/-/epics/999',
              workItemType: {
                id: 'gid://gitlab/WorkItems::Type/5',
                name: 'Epic',
                iconName: 'work-item-epic',
              },
            },
          },
          {
            viewedAt: '2025-06-18T10:00:00Z',
            itemType: 'WikiPage',
            item: {
              __typename: 'WikiPage',
              id: 'wiki-1',
              title: 'Architecture Overview',
              webUrl: '/project/-/wikis/architecture-overview',
            },
          },
        ],
      },
    },
  };

  const recentlyViewedQuerySuccessHandler = jest.fn().mockResolvedValue(mockRecentlyViewedResponse);

  const createComponent = ({ recentlyViewedHandler = recentlyViewedQuerySuccessHandler } = {}) => {
    const mockApollo = createMockApollo([[RecentlyViewedItemsQuery, recentlyViewedHandler]]);

    wrapper = shallowMountExtended(RecentlyViewedItems, {
      apolloProvider: mockApollo,
    });
  };

  const findItemLinks = () => wrapper.findAll('a[href^="/"]');
  const findItemIcons = () => wrapper.findAllComponents(GlIcon);
  const findItemsList = () => wrapper.find('ul');
  const findListItems = () => findItemsList().findAll('li');
  const findItemsByIconName = (iconName) =>
    findListItems().wrappers.filter((w) => w.findComponent(GlIcon).props('name') === iconName);
  const findTooltipComponents = () => wrapper.findAllComponents(TooltipOnTruncate);

  describe('GraphQL query', () => {
    it('makes the correct GraphQL query', () => {
      createComponent();

      expect(recentlyViewedQuerySuccessHandler).toHaveBeenCalled();
    });

    it('updates component data when query resolves', async () => {
      createComponent();
      await waitForPromises();

      expect(findItemLinks()).toHaveLength(2);
    });
  });

  describe('items rendering', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders the correct number of items', () => {
      expect(findItemLinks()).toHaveLength(2);
    });

    it('adds correct icon to epics', () => {
      const epicItems = findItemsByIconName('work-item-epic');

      expect(epicItems).toHaveLength(1);
      expect(epicItems.at(0).text()).toBe('Q3 Development Roadmap');
    });

    it('adds correct icon to wiki pages', () => {
      const wikiItems = findItemsByIconName('book');

      expect(wikiItems).toHaveLength(1);
      expect(wikiItems.at(0).text()).toBe('Architecture Overview');
    });

    it('renders epic type (for backward compatibility when FF is off)', async () => {
      const mockEpicResponse = {
        data: {
          currentUser: {
            id: 123,
            recentlyViewedItems: [
              {
                viewedAt: '2025-06-19T15:30:00Z',
                item: {
                  __typename: 'Epic',
                  id: 'epic-1',
                  title: 'Legacy Epic Type',
                  webUrl: '/groups/company/-/epics/888',
                },
              },
            ],
          },
        },
      };

      const epicHandler = jest.fn().mockResolvedValue(mockEpicResponse);
      createComponent({ recentlyViewedHandler: epicHandler });
      await waitForPromises();

      expect(findItemLinks()).toHaveLength(1);
      expect(findItemIcons().at(0).props('name')).toBe('work-item-epic');
      expect(findItemLinks().at(0).text()).toBe('Legacy Epic Type');
    });

    it('renders the custom icon of a custom work item type', async () => {
      const mockCustomTypeResponse = {
        data: {
          currentUser: {
            id: 123,
            recentlyViewedItems: [
              {
                viewedAt: '2025-06-19T15:30:00Z',
                item: {
                  __typename: 'WorkItem',
                  id: 'work-item-1',
                  title: 'Custom Type Item',
                  webUrl: '/groups/company/-/work_items/1',
                  workItemType: {
                    id: 'gid://gitlab/WorkItems::Type/100',
                    name: 'Initiative',
                    iconName: 'rocket',
                  },
                },
              },
            ],
          },
        },
      };

      const customTypeHandler = jest.fn().mockResolvedValue(mockCustomTypeResponse);
      createComponent({ recentlyViewedHandler: customTypeHandler });
      await waitForPromises();

      expect(findItemIcons().at(0).props('name')).toBe('rocket');
      expect(findItemLinks().at(0).text()).toBe('Custom Type Item');
    });

    it('renders items with correct URLs', () => {
      const links = findItemLinks();

      expect(links.at(0).attributes('href')).toBe('/groups/company/-/epics/999');
      expect(links.at(1).attributes('href')).toBe('/project/-/wikis/architecture-overview');
    });

    it('renders items with correct icons', () => {
      const icons = findItemIcons();

      expect(icons.at(0).props('name')).toBe('work-item-epic');
      expect(icons.at(1).props('name')).toBe('book');
    });

    it('renders tooltip components for each item', () => {
      const tooltips = findTooltipComponents();

      expect(tooltips).toHaveLength(2);
      expect(tooltips.at(0).props('title')).toBe('Q3 Development Roadmap');
      expect(tooltips.at(1).props('title')).toBe('Architecture Overview');
    });
  });
});
