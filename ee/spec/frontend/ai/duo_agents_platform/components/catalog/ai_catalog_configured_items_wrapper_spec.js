import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogConfiguredItemsWrapper from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_configured_items_wrapper.vue';
import AiCatalogList from 'ee/ai/catalog/components/ai_catalog_list.vue';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  mockBaseFlow,
  mockBaseItemConsumer,
  mockConfiguredItemsEmptyResponse,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
  mockPageInfo,
} from 'ee_jest/ai/catalog/mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogConfiguredItemsWrapper', () => {
  let wrapper;
  let mockApollo;

  const mockToast = {
    show: jest.fn(),
  };
  const mockProjectId = 1;
  const mockProject = {
    id: 'test-id',
    nameWithNamespace: 'test/test-id',
  };

  const mockFlowWithBasicProject = {
    ...mockBaseFlow,
    latestVersion: {
      ...mockBaseFlow.latestVersion,
      humanVersionName: 'v1.0.0-draft',
    },
    project: mockProject,
  };

  const mockFlowPinnedVersion = {
    id: 'gid://gitlab/Ai::Catalog::ItemVersion/25',
    humanVersionName: 'v0.9.0',
  };

  const mockConsumerUserPermissions = {
    userPermissions: {
      adminAiCatalogItemConsumer: false,
    },
  };

  const mockConfiguredFlowsQueryHandler = jest.fn().mockResolvedValue({
    data: {
      aiCatalogConfiguredItems: {
        nodes: [
          {
            ...mockBaseItemConsumer,
            ...mockConsumerUserPermissions,
            pinnedItemVersion: mockFlowPinnedVersion,
            item: mockFlowWithBasicProject,
          },
        ],
        pageInfo: mockPageInfo,
      },
    },
  });
  const deleteItemConsumerMutationHandler = jest
    .fn()
    .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);

  const defaultProvide = {
    isProjectNamespace: true,
    projectId: mockProjectId,
  };

  const defaultProps = {
    emptyStateTitle: 'Use flows in your project.',
    emptyStateDescription: 'Flows use multiple agents to complete tasks automatically.',
    emptyStateButtonHref: '/explore/ai-catalog/flows',
    emptyStateButtonText: 'Explore AI Catalog flows',
    itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
    itemTypeConfig: {
      showRoute: 'flows.show',
      visibilityTooltip: {
        public: 'Public flows',
        private: 'Private flows',
      },
    },
  };

  const createComponent = ({ provide = {}, props = {}, configuredItemsQueryHandler } = {}) => {
    mockApollo = createMockApollo([
      [
        aiCatalogConfiguredItemsQuery,
        configuredItemsQueryHandler ?? mockConfiguredFlowsQueryHandler,
      ],
      [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
    ]);

    wrapper = shallowMountExtended(AiCatalogConfiguredItemsWrapper, {
      apolloProvider: mockApollo,
      provide: {
        ...defaultProvide,
        ...provide,
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      mocks: {
        $toast: mockToast,
      },
    });
  };

  const findAiCatalogList = () => wrapper.findComponent(AiCatalogList);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AiCatalogList component', async () => {
      const expectedItem = {
        ...mockFlowWithBasicProject,
        isUpdateAvailable: true,
        itemConsumer: {
          ...mockBaseItemConsumer,
          pinnedItemVersion: mockFlowPinnedVersion,
        },
      };
      const catalogList = findAiCatalogList();

      expect(catalogList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(catalogList.props('items')).toEqual([expectedItem]);
      expect(catalogList.props('isLoading')).toBe(false);
    });

    describe('when there are no flows', () => {
      beforeEach(async () => {
        mockConfiguredFlowsQueryHandler.mockResolvedValueOnce(mockConfiguredItemsEmptyResponse);

        await waitForPromises();
      });

      it('passes empty state props for project to catalog list', () => {
        expect(findAiCatalogList().props()).toMatchObject({
          emptyStateTitle: 'Use flows in your project.',
          emptyStateDescription: 'Flows use multiple agents to complete tasks automatically.',
        });
      });

      it('passes empty state props for group to catalog list', async () => {
        const mockGroupId = 2;
        mockConfiguredFlowsQueryHandler.mockResolvedValueOnce(mockConfiguredItemsEmptyResponse);

        createComponent({
          provide: {
            isProjectNamespace: false,
            projectId: null,
            groupId: mockGroupId,
          },
          props: {
            emptyStateTitle: 'Use flows in your group.',
          },
        });

        await waitForPromises();

        expect(findAiCatalogList().props()).toMatchObject({
          emptyStateTitle: 'Use flows in your group.',
          emptyStateDescription: 'Flows use multiple agents to complete tasks automatically.',
        });
      });
    });
  });

  describe('when the query fails', () => {
    describe.each`
      description                 | configuredItemsQueryHandler
      ${'GraphQL error response'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'error' }] })}
      ${'network error'}          | ${jest.fn().mockRejectedValue(new Error('network error'))}
    `('with a $description', ({ configuredItemsQueryHandler }) => {
      beforeEach(async () => {
        createComponent({ configuredItemsQueryHandler });

        await waitForPromises();
      });

      // Apollo calls the result hook with { data: undefined } on network/GraphQL errors.
      // The callback must guard against this to avoid a TypeError.
      it('leaves pageInfo at its initial empty value without throwing', () => {
        expect(findAiCatalogList().props('pageInfo')).toEqual({});
      });

      it('emits an error event so the parent can surface the failure', () => {
        expect(wrapper.emitted('error')[0][0]).toMatchObject({
          title: 'Failed to load items.',
        });
      });
    });
  });

  describe('Apollo queries', () => {
    describe('when in project namespace', () => {
      beforeEach(() => {
        createComponent();
      });

      it('fetches list data with projectId', () => {
        expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          projectId: `gid://gitlab/Project/${mockProjectId}`,
          includeFoundationalConsumers: true,
          after: null,
          before: null,
          first: 20,
          last: null,
        });
      });
    });

    describe('when in group namespace', () => {
      const mockGroupId = 2;

      beforeEach(() => {
        createComponent({
          provide: {
            isProjectNamespace: false,
            groupId: mockGroupId,
            projectId: null,
          },
        });
      });

      it('fetches list data with groupId', () => {
        expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
          itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
          includeFoundationalConsumers: true,
          groupId: `gid://gitlab/Group/${mockGroupId}`,
          after: null,
          before: null,
          first: 20,
          last: null,
        });
      });
    });

    describe('disabling a flow', () => {
      const item = {
        ...mockBaseFlow,
        itemConsumer: mockBaseItemConsumer,
      };
      const disableFlow = () => findAiCatalogList().props('disableFn')(item);

      beforeEach(() => {
        createComponent();
      });

      it('calls delete consumer mutation', () => {
        disableFlow();

        expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
          id: mockBaseItemConsumer.id,
        });
      });

      describe('when request succeeds', () => {
        it('shows a toast message and refetches the list', async () => {
          disableFlow();

          await waitForPromises();

          expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledTimes(2);
          expect(mockToast.show).toHaveBeenCalledWith('Flow disabled in this project.');
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('does not show toast and emits error', async () => {
          deleteItemConsumerMutationHandler.mockResolvedValue(
            mockAiCatalogItemConsumerDeleteErrorResponse,
          );

          disableFlow();

          await waitForPromises();
          expect(wrapper.emitted('error')).toEqual([
            [
              {
                title: 'Failed to disable flow',
                errors: ['You do not have permission to disable this item.'],
              },
            ],
          ]);
          expect(mockToast.show).not.toHaveBeenCalled();
        });
      });

      describe('when request fails', () => {
        it('emits error event with title and errors, and captures exception', async () => {
          deleteItemConsumerMutationHandler.mockRejectedValue(new Error('Request failed'));

          disableFlow();

          await waitForPromises();
          expect(wrapper.emitted('error')).toEqual([
            [
              {
                title: 'Failed to disable flow',
                errors: ['Request failed'],
              },
            ],
          ]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes pageInfo to list component', () => {
      expect(findAiCatalogList().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('refetches query with correct variables when paging backward', async () => {
      findAiCatalogList().vm.$emit('prev-page');
      await nextTick();
      expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        includeFoundationalConsumers: true,
        after: null,
        before: 'eyJpZCI6IjUxIn0',
        first: null,
        last: 20,
      });
    });

    it('refetches query with correct variables when paging forward', async () => {
      findAiCatalogList().vm.$emit('next-page');
      await nextTick();
      expect(mockConfiguredFlowsQueryHandler).toHaveBeenCalledWith({
        itemTypes: ['FLOW', 'THIRD_PARTY_FLOW'],
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        includeFoundationalConsumers: true,
        after: 'eyJpZCI6IjM1In0',
        before: null,
        first: 20,
        last: null,
      });
    });
  });

  describe('items with different latest and pinned versions', () => {
    const itemConsumerFactory = ({ latest, pinned, baseId = 0, n = 0 } = {}) => {
      const { pinnedItemVersion, ...baseWithoutPinned } = mockBaseItemConsumer;

      return {
        ...baseWithoutPinned,
        id: `gid://gitlab/Ai::Catalog::ItemConsumer/${baseId + 1}`,
        item: {
          ...mockFlowWithBasicProject,
          id: `gid://gitlab/Ai::Catalog::Item/${baseId + 1}`,
          latestVersion:
            latest != null
              ? {
                  ...mockFlowWithBasicProject.latestVersion,
                  id: `gid://gitlab/Ai::Catalog/ItemVersion/${baseId + 1}`,
                  humanVersionName: latest,
                }
              : null,
        },
        pinnedItemVersion: {
          id: `gid://gitlab/Ai::Catalog::ItemVersion/${n + baseId + 1}`, // `n` allows offset from `i` so it never clashes with latestVersion ID
          humanVersionName: pinned,
        },
      };
    };

    const mockQueryHandler = jest.fn().mockResolvedValue({
      data: {
        aiCatalogConfiguredItems: {
          __typename: 'AiCatalogItemConsumerConnection',
          pageInfo: mockPageInfo,
          nodes: [
            itemConsumerFactory({
              latest: 'v1.2.3',
              pinned: 'v1.0.0',
              baseId: 0,
              n: 3,
            }),
            itemConsumerFactory({
              latest: 'v1.2.3',
              pinned: 'v1.2.3',
              baseId: 1,
              n: 3,
            }),
            itemConsumerFactory({
              latest: 'v1.2.3',
              pinned: 'v2.3.4',
              baseId: 2,
              n: 3,
            }),
            itemConsumerFactory({
              latest: null,
              pinned: 'v1.0.0',
              baseId: 3,
              n: 3,
            }),
            {
              ...itemConsumerFactory({ latest: 'v1.0.0', pinned: 'v1.0.0', baseId: 4, n: 3 }),
              item: null,
            },
          ],
        },
      },
    });

    describe('when in group area', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            isProjectNamespace: false,
            projectId: null,
            groupId: 1,
          },
          configuredItemsQueryHandler: mockQueryHandler,
        });
      });

      it('isUpdateAvailable should be true for item 1 and 3, false for item 2 and 4', async () => {
        const catalogList = findAiCatalogList();
        await waitForPromises();

        const items = catalogList.props('items');

        // The configured item with a null `item` is filtered out.
        expect(items).toHaveLength(4);
        expect(items[0].isUpdateAvailable).toBe(true);
        expect(items[1].isUpdateAvailable).toBe(false);
        expect(items[2].isUpdateAvailable).toBe(true);
        expect(items[3].isUpdateAvailable).toBe(false);
      });
    });

    describe('when in project area', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            projectId: 1,
            groupId: null,
          },
          configuredItemsQueryHandler: mockQueryHandler,
        });
      });

      it('isUpdateAvailable should be true for item 1 and 3, false for item 2 and 4', async () => {
        const catalogList = findAiCatalogList();
        await waitForPromises();

        const items = catalogList.props('items');

        // The configured item with a null `item` is filtered out.
        expect(items).toHaveLength(4);
        expect(items[0].isUpdateAvailable).toBe(true);
        expect(items[1].isUpdateAvailable).toBe(false);
        expect(items[2].isUpdateAvailable).toBe(true);
        expect(items[3].isUpdateAvailable).toBe(false);
      });
    });
  });
});
