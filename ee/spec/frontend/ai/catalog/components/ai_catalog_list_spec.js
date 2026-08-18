import { GlButton, GlKeysetPagination, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import AiCatalogListItem from 'ee/ai/catalog/components/ai_catalog_list_item.vue';
import AiCatalogListSkeleton from 'ee/ai/catalog/components/ai_catalog_list_skeleton.vue';
import { AI_CATALOG_TYPE_AGENT } from 'ee/ai/catalog/constants';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { mockAgents, mockPageInfo, mockItemTypeConfig } from '../mock_data';

describe('AiCatalogList', () => {
  let wrapper;

  const mockItems = mockAgents;

  const mockDisableTitle = 'Disable item';
  const mockDisableMessage = 'Are you sure you want to disable item %{name}?';
  const mockDisableFn = jest.fn();

  const createComponent = ({
    props = {},
    slots = {},
    provide = { isGlobalNamespace: true },
  } = {}) => {
    wrapper = shallowMountExtended(AiCatalogList, {
      provide,
      propsData: {
        items: mockItems,
        itemTypes: [AI_CATALOG_TYPE_AGENT],
        itemTypeConfig: mockItemTypeConfig,
        isLoading: false,
        pageInfo: mockPageInfo,
        disableConfirmTitle: mockDisableTitle,
        disableConfirmMessage: mockDisableMessage,
        disableFn: mockDisableFn,
        emptyStateTitle: 'Custom Title',
        emptyStateDescription: 'Custom Description',
        ...props,
      },
      slots,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findLoadingStateList = () => wrapper.findComponent(AiCatalogListSkeleton);
  const findEmptyState = () => wrapper.findComponent(ResourceListsEmptyState);
  const findListItems = () => wrapper.findAllComponents(AiCatalogListItem);
  const findConfirmModal = () => wrapper.findComponent(ConfirmActionModal);
  const findPaginator = () => wrapper.findComponent(GlKeysetPagination);
  const findEmptyStateButton = () => wrapper.findComponent(GlButton);
  const findDisabledItemTypeAlert = () => wrapper.findByTestId('disabled-type-alert');

  describe('component rendering', () => {
    describe('template', () => {
      beforeEach(() => {
        createComponent();
      });

      it('does not render the loading state component', () => {
        expect(findLoadingStateList().exists()).toBe(false);
      });

      it('does render list items', () => {
        const listItems = findListItems();

        expect(listItems).toHaveLength(3);
      });

      it('passes correct props to each list item', () => {
        const listItems = findListItems();

        listItems.wrappers.forEach((listItem, index) => {
          expect(listItem.props('item')).toEqual(mockItems[index]);
        });
      });

      it('does not render empty state', () => {
        expect(findEmptyState().exists()).toBe(false);
      });

      it('does not render the confirm modal by default', () => {
        expect(findConfirmModal().exists()).toBe(false);
      });

      it('does not display disabled item type banner', () => {
        expect(findDisabledItemTypeAlert().exists()).toBe(false);
      });
    });

    describe('when loading data', () => {
      describe('default', () => {
        beforeEach(() => {
          createComponent({
            props: {
              isLoading: true,
            },
          });
        });

        it('renders loading state component', () => {
          const loadingStateList = findLoadingStateList();

          expect(loadingStateList.exists()).toBe(true);
          expect(loadingStateList.props('showRightElement')).toBe(false);
        });

        it('does not render list items', () => {
          const listItems = findListItems();

          expect(listItems).toHaveLength(0);
        });

        it('does not render empty state', () => {
          expect(findEmptyState().exists()).toBe(false);
        });
      });

      it('renders loading state with right-hand component placeholder', () => {
        createComponent({
          props: {
            isLoading: true,
            itemTypeConfig: { ...mockItemTypeConfig, disableActionItem: () => [] },
          },
        });
        const loadingStateList = findLoadingStateList();

        expect(loadingStateList.props('showRightElement')).toBe(true);
      });
    });

    describe('when data is loaded and there are no items', () => {
      beforeEach(() => {
        createComponent({
          props: { items: [] },
        });
      });

      it('does not render the loading state component', () => {
        expect(findLoadingStateList().exists()).toBe(false);
      });

      it('does not render list items', () => {
        const listItems = findListItems();

        expect(listItems).toHaveLength(0);
      });

      it('renders custom empty state with provided props', () => {
        createComponent({
          props: {
            items: [],
          },
        });

        expect(findEmptyState().props()).toMatchObject({
          title: 'Custom Title',
          description: 'Custom Description',
        });
      });

      it('renders empty state with search prop', () => {
        createComponent({
          props: { items: [], search: 'test search' },
        });

        expect(findEmptyState().props()).toMatchObject({
          search: 'test search',
        });
      });

      it('renders custom empty state slot', () => {
        createComponent({
          props: { items: [] },
          slots: {
            'empty-state': '<div data-testid="custom-empty-state">Custom empty state</div>',
          },
        });

        expect(wrapper.findByTestId('custom-empty-state').exists()).toBe(true);
        expect(findEmptyState().exists()).toBe(false);
      });

      it('renders empty state with button when emptyStateButtonHref is provided', () => {
        createComponent({
          props: {
            items: [],
            emptyStateTitle: 'No items',
            emptyStateDescription: 'Get started',
            emptyStateButtonHref: '/explore',
            emptyStateButtonText: 'Explore',
          },
        });

        const button = findEmptyStateButton();
        expect(button.exists()).toBe(true);
        expect(button.props('variant')).toBe('confirm');
        expect(button.attributes('href')).toBe('/explore');
        expect(button.text()).toBe('Explore');
      });

      it('does not render button when emptyStateButtonHref is not provided', () => {
        createComponent({
          props: {
            items: [],
            emptyStateTitle: 'No items',
            emptyStateDescription: 'Get started',
          },
        });

        expect(findEmptyStateButton().exists()).toBe(false);
      });
    });
  });

  describe('disabling an item', () => {
    describe('default', () => {
      beforeEach(() => {
        createComponent();
        const secondItem = findListItems().at(1);

        secondItem.vm.$emit('disable');
      });

      it('opens confirm modal on disable', () => {
        expect(findConfirmModal().props()).toMatchObject({
          title: mockDisableTitle,
          actionText: 'Disable',
        });
        expect(findConfirmModal().text()).toBe(
          `Are you sure you want to disable item ${mockItems[1].name}?`,
        );
      });

      it('calls disable function on confirm', () => {
        findConfirmModal().props('actionFn')();

        expect(mockDisableFn).toHaveBeenCalledWith(mockItems[1]);
      });
    });

    describe('with itemTypeConfig', () => {
      beforeEach(() => {
        createComponent({
          props: {
            itemTypeConfig: {
              ...mockItemTypeConfig,
              disableActionItem: {
                text: 'Disable',
              },
            },
          },
        });
        const secondItem = findListItems().at(1);
        secondItem.vm.$emit('disable');
      });

      it('passes correct actionText to modal', () => {
        expect(findConfirmModal().props('actionText')).toBe('Disable');
      });
    });
  });

  describe('pagination', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes pageInfo to pagination component', () => {
      expect(findPaginator().props()).toMatchObject({
        startCursor: mockPageInfo.startCursor,
        endCursor: mockPageInfo.endCursor,
        hasNextPage: mockPageInfo.hasNextPage,
        hasPreviousPage: mockPageInfo.hasPreviousPage,
      });
    });

    it('emits prev-page when prev emitted by pagination component', () => {
      findPaginator().vm.$emit('prev');
      expect(wrapper.emitted('prev-page')).toHaveLength(1);
    });

    it('emits next-page when next emitted by pagination component', () => {
      findPaginator().vm.$emit('next');
      expect(wrapper.emitted('next-page')).toHaveLength(1);
    });
  });

  describe('when disabledItemTypeMessages prop is passed', () => {
    beforeEach(() => {
      createComponent({
        props: {
          disabledItemTypeMessages: [
            'Custom agents are inactive for all projects. To create or use custom agents, turn on custom agents.',
          ],
        },
      });
    });

    it('displays disabled item type banner', () => {
      expect(findDisabledItemTypeAlert().exists()).toBe(true);
      expect(findDisabledItemTypeAlert().text()).toBe(
        'Custom agents are inactive for all projects. To create or use custom agents, turn on custom agents.',
      );
    });
  });
});
