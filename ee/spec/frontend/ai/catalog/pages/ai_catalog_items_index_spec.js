import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { isLoggedIn } from '~/lib/utils/common_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiCatalogItemsIndex from 'ee/ai/catalog/pages/ai_catalog_items_index.vue';
import AiCatalogListWrapper from 'ee/ai/catalog/components/ai_catalog_list_wrapper.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import aiCatalogItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_items.query.graphql';
import aiCatalogCustomAndFoundationalItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_custom_and_foundational_items.query.graphql';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  VERIFICATION_LEVEL_GITLAB_MAINTAINED,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
  TRACK_EVENT_TYPE_AGENT,
  TRACK_EVENT_TYPE_FLOW,
} from 'ee/ai/catalog/constants';
import {
  mockAgents,
  mockFlows,
  mockCatalogItemsResponse,
  mockCatalogFlowsResponse,
  mockCatalogCustomAndFoundationalItemsResponse,
  mockPageInfo,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/common_utils');

Vue.use(VueApollo);

const ITEM_TYPE_SCENARIOS = [
  {
    itemType: AI_CATALOG_TYPE_AGENT,
    query: aiCatalogItemsQuery,
    mockItems: mockAgents,
    mockResponse: mockCatalogItemsResponse,
    trackLabel: TRACK_EVENT_TYPE_AGENT,
    glFeatures: { aiCatalogThirdPartyFlows: true },
    resolvedItemTypes: [AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW],
  },
  {
    itemType: AI_CATALOG_TYPE_FLOW,
    query: aiCatalogItemsQuery,
    mockItems: mockFlows,
    mockResponse: mockCatalogFlowsResponse,
    trackLabel: TRACK_EVENT_TYPE_FLOW,
    glFeatures: {},
    resolvedItemTypes: [AI_CATALOG_TYPE_FLOW],
  },
];

describe('AiCatalogItemsIndex', () => {
  describe.each(ITEM_TYPE_SCENARIOS)(
    'when itemType is $itemType',
    ({ itemType, query, mockItems, mockResponse, trackLabel, glFeatures, resolvedItemTypes }) => {
      let wrapper;
      let mockApollo;
      let mockRouter;
      let mockRoute;
      let mockCatalogItemsQueryHandler;

      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      beforeEach(() => {
        mockRouter = { push: jest.fn(), replace: jest.fn() };
        mockRoute = { query: {} };
        mockCatalogItemsQueryHandler = jest.fn().mockResolvedValue(mockResponse);
      });

      const createComponent = ({ provide = {}, routeQuery = {} } = {}) => {
        isLoggedIn.mockReturnValue(true);
        mockApollo = createMockApollo([[query, mockCatalogItemsQueryHandler]]);
        mockRoute.query = routeQuery;

        wrapper = shallowMountExtended(AiCatalogItemsIndex, {
          apolloProvider: mockApollo,
          propsData: { itemType },
          mocks: { $router: mockRouter, $route: mockRoute },
          provide: {
            glFeatures,
            ...provide,
          },
        });
      };

      const findListWrapper = () => wrapper.findComponent(AiCatalogListWrapper);

      describe('component rendering', () => {
        beforeEach(() => {
          createComponent();
        });

        it('renders AiCatalogListHeader', () => {
          expect(wrapper.findComponent(AiCatalogListHeader).exists()).toBe(true);
        });

        it('renders AiCatalogListWrapper', () => {
          expect(findListWrapper().exists()).toBe(true);
        });

        it('passes loading state as true initially', () => {
          expect(findListWrapper().props('isLoading')).toBe(true);
        });

        it('passes items and isLoading=false after data loads', async () => {
          await waitForPromises();

          expect(findListWrapper().props('items')).toEqual(mockItems);
          expect(findListWrapper().props('isLoading')).toBe(false);
        });
      });

      describe('Apollo query', () => {
        it('fetches with correct itemTypes by default', () => {
          createComponent();

          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ itemTypes: resolvedItemTypes }),
          );
        });

        it('fetches with default sort by default', () => {
          createComponent();

          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ sort: null }),
          );
        });
      });

      describe('pagination', () => {
        it('passes pageInfo to list component', async () => {
          createComponent();
          await waitForPromises();

          expect(findListWrapper().props('pageInfo')).toMatchObject(mockPageInfo);
        });

        it('refetches query with correct variables when paging forward', async () => {
          createComponent();
          await waitForPromises();

          findListWrapper().vm.$emit('next-page');
          await waitForPromises();

          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({
              after: 'eyJpZCI6IjM1In0',
              before: null,
              first: 20,
              last: null,
            }),
          );
        });

        it('refetches query with correct variables when paging backward', async () => {
          createComponent();
          await waitForPromises();

          findListWrapper().vm.$emit('prev-page');
          await waitForPromises();

          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({
              before: 'eyJpZCI6IjUxIn0',
              after: null,
              first: null,
              last: 20,
            }),
          );
        });
      });

      describe('search', () => {
        describe('default', () => {
          beforeEach(() => {
            createComponent();
          });

          it('passes search param to query on filter', async () => {
            findListWrapper().vm.$emit('filter', { search: 'foo' });
            await waitForPromises();

            expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
              expect.objectContaining({ search: 'foo' }),
            );
          });

          it('updates URL query param when filtering', async () => {
            findListWrapper().vm.$emit('filter', { search: 'foo' });
            await waitForPromises();

            expect(mockRouter.replace).toHaveBeenCalledWith(
              expect.objectContaining({ query: expect.objectContaining({ search: 'foo' }) }),
            );
          });

          it('clears search param when filter is emitted with empty search', async () => {
            findListWrapper().vm.$emit('filter', { search: 'foo' });
            await waitForPromises();

            findListWrapper().vm.$emit('filter', {});
            await waitForPromises();

            expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
              expect.objectContaining({ search: '' }),
            );
          });

          it('does not update URL when search term has not changed', async () => {
            mockRoute.query = { search: 'foo' };

            findListWrapper().vm.$emit('filter', { search: 'foo' });
            await waitForPromises();

            expect(mockRouter.replace).not.toHaveBeenCalled();
          });
        });

        it('initializes search term from URL query param', async () => {
          await createComponent({ routeQuery: { search: 'initial' } });
          await waitForPromises();

          expect(findListWrapper().props('searchTerm')).toBe('initial');
          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ search: 'initial' }),
          );
        });
      });

      describe('sort', () => {
        it('passes sort: null to Apollo query by default (backend uses catalog priority)', () => {
          createComponent();

          // DEFAULT_SORT is CATALOG_PRIORITY but sortGraphQLValue returns null for it,
          // letting the backend resolver apply catalog priority ordering.
          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ sort: null }),
          );
        });

        it('emits USAGE_COUNT_DESC to Apollo when sort emits USAGE_COUNT_DESC', async () => {
          createComponent();
          await waitForPromises();

          findListWrapper().vm.$emit('sort', 'USAGE_COUNT_DESC');
          await waitForPromises();

          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ sort: 'USAGE_COUNT_DESC' }),
          );
        });

        it('emits USAGE_COUNT_ASC to Apollo when sort emits USAGE_COUNT_ASC', async () => {
          createComponent();
          await waitForPromises();

          findListWrapper().vm.$emit('sort', 'USAGE_COUNT_ASC');
          await waitForPromises();

          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ sort: 'USAGE_COUNT_ASC' }),
          );
        });

        it('persists sort in URL query string when sort is emitted', async () => {
          createComponent();
          await waitForPromises();

          findListWrapper().vm.$emit('sort', 'USAGE_COUNT_DESC');
          await waitForPromises();

          expect(mockRouter.replace).toHaveBeenCalledWith(
            expect.objectContaining({
              query: expect.objectContaining({ sort: 'USAGE_COUNT_DESC' }),
            }),
          );
        });

        it('restores sort from URL query param on mount', async () => {
          createComponent({ routeQuery: { sort: 'USAGE_COUNT_DESC' } });
          await waitForPromises();

          expect(mockCatalogItemsQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ sort: 'USAGE_COUNT_DESC' }),
          );
        });

        it('passes initialSortBy as empty string for default sort', () => {
          createComponent();

          expect(findListWrapper().props('initialSortBy')).toBe('');
        });

        it('passes initialSortBy from URL sort param', async () => {
          createComponent({ routeQuery: { sort: 'USAGE_COUNT_ASC' } });
          await waitForPromises();

          expect(findListWrapper().props('initialSortBy')).toBe('USAGE_COUNT_ASC');
        });

        it('resets sort and removes URL param when sort emits CATALOG_PRIORITY', async () => {
          createComponent({ routeQuery: { sort: 'USAGE_COUNT_DESC' } });
          await waitForPromises();

          mockRouter.replace.mockClear();
          mockCatalogItemsQueryHandler.mockClear();

          findListWrapper().vm.$emit('sort', 'CATALOG_PRIORITY');
          await waitForPromises();

          expect(findListWrapper().props('initialSortBy')).toBe('');
          expect(mockCatalogItemsQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ sort: null }),
          );
          expect(mockRouter.replace).toHaveBeenCalledWith({ query: {} });
        });

        it('passes updated initialSortBy when sort changes from one directional sort to another', async () => {
          createComponent({ routeQuery: { sort: 'STAR_COUNT_DESC' } });
          await waitForPromises();

          expect(findListWrapper().props('initialSortBy')).toBe('STAR_COUNT_DESC');

          findListWrapper().vm.$emit('sort', 'USAGE_COUNT_DESC');
          await waitForPromises();

          expect(findListWrapper().props('initialSortBy')).toBe('USAGE_COUNT_DESC');
          expect(mockCatalogItemsQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ sort: 'USAGE_COUNT_DESC' }),
          );
        });

        it('resets pagination when sort changes', async () => {
          createComponent({ routeQuery: { sort: 'STAR_COUNT_DESC' } });
          await waitForPromises();

          // Simulate being on page 2.
          findListWrapper().vm.$emit('next-page');
          await waitForPromises();

          mockCatalogItemsQueryHandler.mockClear();

          // Change sort — pagination must reset to page 1.
          findListWrapper().vm.$emit('sort', 'USAGE_COUNT_DESC');
          await waitForPromises();

          expect(mockCatalogItemsQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({
              sort: 'USAGE_COUNT_DESC',
              after: null,
              before: null,
              first: 20,
              last: null,
            }),
          );
        });
      });

      describe('tracking events', () => {
        describe('when component is mounted', () => {
          beforeEach(() => {
            createComponent();
          });

          it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX} event with correct label`, () => {
            const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

            expect(trackEventSpy).toHaveBeenCalledWith(
              TRACK_EVENT_VIEW_AI_CATALOG_ITEM_INDEX,
              { label: trackLabel },
              undefined,
            );
          });
        });
      });

      describe('when catalog items query fails', () => {
        it('reports error to Sentry', async () => {
          const error = new Error('GraphQL error');
          mockCatalogItemsQueryHandler.mockRejectedValue(error);
          createComponent();
          await waitForPromises();

          expect(Sentry.captureException).toHaveBeenCalledWith(error);
        });
      });
    },
  );

  describe('when itemType is AGENT and aiCatalogThirdPartyFlows feature flag is off', () => {
    it('fetches without third-party flow types', () => {
      const handler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
      isLoggedIn.mockReturnValue(true);
      const mockApollo = createMockApollo([[aiCatalogItemsQuery, handler]]);

      shallowMountExtended(AiCatalogItemsIndex, {
        apolloProvider: mockApollo,
        propsData: { itemType: AI_CATALOG_TYPE_AGENT },
        mocks: { $router: { replace: jest.fn() }, $route: { query: {} } },
        provide: { glFeatures: { aiCatalogThirdPartyFlows: false } },
      });

      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({ itemTypes: [AI_CATALOG_TYPE_AGENT] }),
      );
    });
  });

  describe('when itemType is AGENT and aiCatalogSyntheticFoundationalItems feature flag is on', () => {
    let wrapper;
    let itemsHandler;
    let foundationalHandler;

    const createComponent = () => {
      isLoggedIn.mockReturnValue(true);
      itemsHandler = jest.fn().mockResolvedValue(mockCatalogItemsResponse);
      foundationalHandler = jest
        .fn()
        .mockResolvedValue(mockCatalogCustomAndFoundationalItemsResponse);
      const mockApollo = createMockApollo([
        [aiCatalogItemsQuery, itemsHandler],
        [aiCatalogCustomAndFoundationalItemsQuery, foundationalHandler],
      ]);

      wrapper = shallowMountExtended(AiCatalogItemsIndex, {
        apolloProvider: mockApollo,
        propsData: { itemType: AI_CATALOG_TYPE_AGENT },
        mocks: { $router: { replace: jest.fn() }, $route: { query: {} } },
        provide: { glFeatures: { aiCatalogSyntheticFoundationalItems: true } },
      });
    };

    const findListWrapper = () => wrapper.findComponent(AiCatalogListWrapper);

    it('queries the custom and foundational items query', () => {
      createComponent();

      expect(foundationalHandler).toHaveBeenCalled();
      expect(itemsHandler).not.toHaveBeenCalled();
    });

    it('requests foundational agent item type alongside agents', () => {
      createComponent();

      expect(foundationalHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          itemTypes: expect.arrayContaining([
            AI_CATALOG_TYPE_AGENT,
            AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
          ]),
        }),
      );
    });

    it('normalizes foundational agent nodes into list items', async () => {
      createComponent();
      await waitForPromises();

      const items = findListWrapper().props('items');
      const foundationalItem = items.find(
        (item) => item.itemType === AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
      );

      expect(foundationalItem).toMatchObject({
        itemType: AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
        foundational: true,
        public: true,
        verificationLevel: VERIFICATION_LEVEL_GITLAB_MAINTAINED,
        starCount: 0,
        starred: false,
        last30DayUsageCount: 0,
      });
    });

    it('passes pageInfo from the custom and foundational items response', async () => {
      createComponent();
      await waitForPromises();

      expect(findListWrapper().props('pageInfo')).toMatchObject(mockPageInfo);
    });
  });

  describe('when itemType is FLOW and aiCatalogSyntheticFoundationalItems feature flag is on', () => {
    it('uses the regular items query and does not include foundational items', () => {
      isLoggedIn.mockReturnValue(true);
      const itemsHandler = jest.fn().mockResolvedValue(mockCatalogFlowsResponse);
      const foundationalHandler = jest
        .fn()
        .mockResolvedValue(mockCatalogCustomAndFoundationalItemsResponse);
      const mockApollo = createMockApollo([
        [aiCatalogItemsQuery, itemsHandler],
        [aiCatalogCustomAndFoundationalItemsQuery, foundationalHandler],
      ]);

      shallowMountExtended(AiCatalogItemsIndex, {
        apolloProvider: mockApollo,
        propsData: { itemType: AI_CATALOG_TYPE_FLOW },
        mocks: { $router: { replace: jest.fn() }, $route: { query: {} } },
        provide: { glFeatures: { aiCatalogSyntheticFoundationalItems: true } },
      });

      expect(itemsHandler).toHaveBeenCalledWith(
        expect.objectContaining({ itemTypes: [AI_CATALOG_TYPE_FLOW] }),
      );
      expect(foundationalHandler).not.toHaveBeenCalled();
    });
  });
});
