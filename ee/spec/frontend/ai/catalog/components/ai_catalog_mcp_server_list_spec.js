import { GlKeysetPagination } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';

import AiCatalogMcpServerList from 'ee/ai/catalog/components/ai_catalog_mcp_server_list.vue';
import AiCatalogMcpServerListItem from 'ee/ai/catalog/components/ai_catalog_mcp_server_list_item.vue';
import AiCatalogListSkeleton from 'ee/ai/catalog/components/ai_catalog_list_skeleton.vue';

describe('AiCatalogMcpServerList', () => {
  let wrapper;

  const mockItems = [
    {
      id: 'gid://gitlab/Ai::Catalog::McpServer/1',
      name: 'Server 1',
      description: 'Description 1',
      url: 'https://example.com/1',
      transport: 'HTTP',
      authType: 'OAUTH',
    },
    {
      id: 'gid://gitlab/Ai::Catalog::McpServer/2',
      name: 'Server 2',
      description: 'Description 2',
      url: 'https://example.com/2',
      transport: 'HTTP',
      authType: 'NO_AUTH',
    },
  ];

  const mockPageInfo = {
    hasNextPage: true,
    hasPreviousPage: false,
    startCursor: 'start',
    endCursor: 'end',
  };

  const defaultProps = {
    items: mockItems,
    pageInfo: mockPageInfo,
    isLoading: false,
    emptyStateTitle: 'No MCP servers',
    emptyStateDescription: 'Add your first MCP server',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogMcpServerList, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findListItems = () => wrapper.findAllComponents(AiCatalogMcpServerListItem);
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);
  const findSkeleton = () => wrapper.findComponent(AiCatalogListSkeleton);
  const findFirstListItem = () => findListItems().at(0);

  describe('when items are present', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders list items', () => {
      const items = findListItems();
      expect(items).toHaveLength(2);
      expect(items.at(0).props('item')).toEqual(mockItems[0]);
      expect(items.at(1).props('item')).toEqual(mockItems[1]);
    });

    it('passes showRoute prop to list items', () => {
      createComponent({ showRoute: 'custom_route' });
      expect(findFirstListItem().props('showRoute')).toBe('custom_route');
    });

    it('passes showConnect prop to list items', () => {
      createComponent({ showConnect: true });
      expect(findFirstListItem().props('showConnect')).toBe(true);
    });

    it('emits connect event when list item emits connect', () => {
      const serverItem = mockItems[0];
      findFirstListItem().vm.$emit('connect', serverItem);
      expect(wrapper.emitted('connect')).toHaveLength(1);
      expect(wrapper.emitted('connect')[0]).toEqual([serverItem]);
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('renders pagination', () => {
      expect(findPagination().exists()).toBe(true);
      expect(findPagination().props()).toMatchObject({
        hasNextPage: true,
        hasPreviousPage: false,
      });
    });

    it('emits next-page event when pagination next is clicked', () => {
      findPagination().vm.$emit('next');
      expect(wrapper.emitted('next-page')).toHaveLength(1);
    });

    it('emits prev-page event when pagination prev is clicked', () => {
      findPagination().vm.$emit('prev');
      expect(wrapper.emitted('prev-page')).toHaveLength(1);
    });
  });

  describe('when items are empty', () => {
    beforeEach(() => {
      createComponent({
        items: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
        },
      });
    });

    it('renders empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().props()).toMatchObject({
        title: 'No MCP servers',
        description: 'Add your first MCP server',
      });
    });

    it('does not render list items', () => {
      expect(findListItems()).toHaveLength(0);
    });

    it('does not render pagination', () => {
      expect(findPagination().exists()).toBe(false);
    });

    it('does not render pagination even when pageInfo has pages', () => {
      createComponent({
        items: [],
        pageInfo: {
          hasNextPage: true,
          hasPreviousPage: false,
        },
      });

      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ isLoading: true, items: [] });
    });

    it('renders the skeleton loader', () => {
      expect(findSkeleton().exists()).toBe(true);
    });

    it('does not render empty state', () => {
      expect(findEmptyState().exists()).toBe(false);
    });

    it('does not render list items', () => {
      expect(findListItems()).toHaveLength(0);
    });

    it('does not render pagination', () => {
      createComponent({
        isLoading: true,
        items: [],
        pageInfo: {
          hasNextPage: true,
          hasPreviousPage: false,
        },
      });

      expect(findPagination().exists()).toBe(false);
    });
  });

  describe('pagination visibility', () => {
    it('hides pagination when there are no pages', () => {
      createComponent({
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
        },
      });

      expect(findPagination().exists()).toBe(false);
    });

    it('shows pagination when there is a next page', () => {
      createComponent({
        pageInfo: {
          hasNextPage: true,
          hasPreviousPage: false,
        },
      });

      expect(findPagination().exists()).toBe(true);
    });

    it('shows pagination when there is a previous page', () => {
      createComponent({
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: true,
        },
      });

      expect(findPagination().exists()).toBe(true);
    });
  });
});
