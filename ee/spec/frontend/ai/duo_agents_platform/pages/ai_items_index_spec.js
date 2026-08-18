import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTabs, GlTab } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import AiItemsIndex from 'ee/ai/duo_agents_platform/pages/ai_items_index.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogConfiguredItemsWrapper from 'ee/ai/duo_agents_platform/components/catalog/ai_catalog_configured_items_wrapper.vue';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import projectAiCatalogTabItemsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_catalog_items.query.graphql';
import projectAiCatalogItemsQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_items.query.graphql';
import aiCatalogConfiguredItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_configured_items.query.graphql';
import {
  mockAgentsWithConfig,
  mockFlowsWithConfigs,
  mockPageInfo,
  mockConfiguredItemsEmptyResponse,
} from 'ee_jest/ai/catalog/mock_data';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED,
  TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_CATALOG,
  TRACK_EVENT_TYPE_AGENT,
  TRACK_EVENT_TYPE_FLOW,
} from 'ee/ai/catalog/constants';
import { AGENT_MESSAGES, FLOW_MESSAGES } from 'ee/ai/catalog//messages';
import { itemTypeDisabledAlertLink } from 'ee/ai/catalog/utils';
import {
  mockProjectAgentsResponse,
  mockProjectFlowsResponse,
  mockProjectCatalogTabAgentsResponse,
  mockProjectCatalogTabFlowsResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('AiItemsIndex', () => {
  let wrapper;
  let mockApollo;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  let mockRoute;
  let mockRouter;

  const mockProjectId = 1;
  const mockRootGroupId = 10000;
  const mockProjectPath = 'test-group/test-project';
  const mockToast = { show: jest.fn() };

  const setupRouteMock = (initialQuery = {}) => {
    // eslint-disable-next-line no-restricted-properties
    mockRoute = Vue.observable({ query: { ...initialQuery } });
    mockRouter = {
      push: jest.fn(({ query }) => {
        mockRoute.query = { ...query };
      }),
      replace: jest.fn(),
    };
  };

  const TYPE_CONFIGS = [
    {
      label: 'agents',
      itemType: AI_CATALOG_TYPE_AGENT,
      projectQuery: projectAiCatalogItemsQuery,
      catalogQuery: projectAiCatalogTabItemsQuery,
      projectQueryResponse: mockProjectAgentsResponse,
      catalogQueryResponse: mockProjectCatalogTabAgentsResponse,
      items: mockAgentsWithConfig,
      explorePathKey: 'exploreAiCatalogAgentsPath',
      explorePath: '/explore/ai-catalog/agents',
      managedTestId: 'managed-agents-list',
      catalogTestId: 'catalog-agents-list',
      trackLabel: TRACK_EVENT_TYPE_AGENT,
      emptyStateTitle: 'Use agents in your project.',
      emptyStateDescription: 'Use agents to automate tasks and answer questions.',
      groupEmptyStateTitle: 'Use agents in your group.',
      itemTypes: ['AGENT', 'THIRD_PARTY_FLOW'],
      messages: AGENT_MESSAGES,
    },
    {
      label: 'flows',
      itemType: AI_CATALOG_TYPE_FLOW,
      projectQuery: projectAiCatalogItemsQuery,
      catalogQuery: projectAiCatalogTabItemsQuery,
      projectQueryResponse: mockProjectFlowsResponse,
      catalogQueryResponse: mockProjectCatalogTabFlowsResponse,
      items: mockFlowsWithConfigs,
      explorePathKey: 'exploreAiCatalogFlowsPath',
      explorePath: '/explore/ai-catalog/flows',
      managedTestId: 'managed-flows-list',
      catalogTestId: 'catalog-flows-list',
      trackLabel: TRACK_EVENT_TYPE_FLOW,
      emptyStateTitle: 'Use flows in your project.',
      emptyStateDescription: 'Flows use multiple agents to complete tasks automatically.',
      groupEmptyStateTitle: 'Use flows in your group.',
      itemTypes: ['FLOW'],
      messages: FLOW_MESSAGES,
    },
  ];

  describe.each(TYPE_CONFIGS)('with $label itemType', (config) => {
    let mockProjectQueryHandler;
    let mockCatalogQueryHandler;
    let mockConfiguredItemsQueryHandler;

    const createComponent = ({ provide = {}, routeQuery = {} } = {}) => {
      setupRouteMock(routeQuery);
      mockProjectQueryHandler = jest.fn().mockResolvedValue(config.projectQueryResponse);
      mockCatalogQueryHandler = jest.fn().mockResolvedValue(config.catalogQueryResponse);
      mockConfiguredItemsQueryHandler = jest
        .fn()
        .mockResolvedValue(mockConfiguredItemsEmptyResponse);

      mockApollo = createMockApollo([
        [aiCatalogConfiguredItemsQuery, mockConfiguredItemsQueryHandler],
        [config.projectQuery, mockProjectQueryHandler],
        [config.catalogQuery, mockCatalogQueryHandler],
      ]);

      wrapper = shallowMountExtended(AiItemsIndex, {
        apolloProvider: mockApollo,
        propsData: { itemType: config.itemType },
        provide: {
          isProjectNamespace: true,
          projectId: mockProjectId,
          projectPath: mockProjectPath,
          [config.explorePathKey]: config.explorePath,
          rootGroupId: mockRootGroupId,
          glFeatures: { aiCatalogThirdPartyFlows: config.itemType === AI_CATALOG_TYPE_AGENT },
          ...provide,
        },
        mocks: { $toast: mockToast, $route: mockRoute, $router: mockRouter },
        stubs: { GlTab },
      });
    };

    const findHeader = () => wrapper.findComponent(AiCatalogListHeader);
    const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
    const findConfiguredItemsWrapper = () => wrapper.findComponent(AiCatalogConfiguredItemsWrapper);
    const findManagedList = () => wrapper.findComponentByTestId(config.managedTestId);
    const findCatalogList = () => wrapper.findComponentByTestId(config.catalogTestId);
    const findTabs = () => wrapper.findComponent(GlTabs);
    const findAllTabs = () => wrapper.findAllComponents(GlTab);

    describe('Enabled tab (project namespace)', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the list header', () => {
        expect(findHeader().exists()).toBe(true);
      });

      it('renders AiCatalogConfiguredItemsWrapper with correct props', () => {
        expect(findConfiguredItemsWrapper().props()).toMatchObject({
          emptyStateTitle: config.emptyStateTitle,
          emptyStateDescription: config.emptyStateDescription,
          emptyStateButtonText: 'Explore the AI Catalog',
          itemTypes: config.itemTypes,
        });
      });

      it('switches to the Catalog tab when empty state button is clicked', async () => {
        findConfiguredItemsWrapper().vm.$emit('empty-state-click');
        await nextTick();

        expect(findTabs().props('value')).toBe(2);
      });

      it('shows error alert when wrapper emits an error', async () => {
        await findConfiguredItemsWrapper().vm.$emit('error', {
          title: 'Error title',
          errors: ['Something went wrong'],
        });

        expect(findErrorsAlert().props('title')).toBe('Error title');
        expect(findErrorsAlert().props('errors')).toEqual(['Something went wrong']);
      });

      it('clears errors when error alert is dismissed', async () => {
        await findConfiguredItemsWrapper().vm.$emit('error', {
          title: 'Error',
          errors: ['err'],
        });

        findErrorsAlert().vm.$emit('dismiss');
        await nextTick();

        expect(findErrorsAlert().props('errors')).toEqual([]);
      });
    });

    describe('Managed tab', () => {
      const baseVariables = {
        projectPath: mockProjectPath,
        allAvailable: false,
        search: '',
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        groupId: `gid://gitlab/Group/${mockRootGroupId}`,
        after: null,
        before: null,
        first: 20,
        last: null,
      };

      beforeEach(() => {
        createComponent();
        findTabs().vm.$emit('input', 1);
      });

      describe('personal project (no rootGroupId)', () => {
        it('does not throw an error and skips the query when rootGroupId is null', async () => {
          createComponent({ provide: { rootGroupId: null } });
          expect(() => findTabs().vm.$emit('input', 1)).not.toThrow();
          await waitForPromises();

          expect(mockProjectQueryHandler).not.toHaveBeenCalled();
        });
      });

      it('shows loading state initially then renders items', async () => {
        expect(findManagedList().props('isLoading')).toBe(true);

        await waitForPromises();

        expect(findManagedList().props('items')).toMatchObject(config.items);
        expect(findManagedList().props('isLoading')).toBe(false);
      });

      it('passes empty state props to the list', async () => {
        await waitForPromises();

        expect(findManagedList().props()).toMatchObject({
          emptyStateTitle: config.emptyStateTitle,
          emptyStateDescription: config.emptyStateDescription,
          emptyStateButtonText: 'Explore the AI Catalog',
        });
      });

      it('passes pageInfo to the list', async () => {
        await waitForPromises();

        expect(findManagedList().props('pageInfo')).toMatchObject(mockPageInfo);
      });

      it('switches to Catalog tab when empty state click is emitted', async () => {
        await waitForPromises();
        findManagedList().vm.$emit('empty-state-click');
        await nextTick();

        expect(findTabs().props('value')).toBe(2);
      });

      describe('pagination', () => {
        beforeEach(() => waitForPromises());

        it('refetches with next-page cursor', async () => {
          findManagedList().vm.$emit('next-page');
          await nextTick();

          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({
              ...baseVariables,
              after: mockPageInfo.endCursor,
              before: null,
              first: 20,
              last: null,
            }),
          );
        });

        it('refetches with prev-page cursor', async () => {
          findManagedList().vm.$emit('prev-page');
          await nextTick();

          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({
              ...baseVariables,
              before: mockPageInfo.startCursor,
              after: null,
              first: null,
              last: 20,
            }),
          );
        });
      });

      describe('search', () => {
        beforeEach(() => waitForPromises());

        it('refetches with search term when filter is submitted', async () => {
          findManagedList().vm.$emit('filter', { search: 'test item' });
          await nextTick();

          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ search: 'test item' }),
          );
        });

        it('refetches with empty search when filter is emitted with empty search', async () => {
          findManagedList().vm.$emit('filter', { search: 'test item' });
          await nextTick();

          findManagedList().vm.$emit('filter', {});
          await nextTick();

          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ search: '' }),
          );
        });

        it('preserves search term when switching tabs', async () => {
          findManagedList().vm.$emit('filter', { search: 'persisted search' });
          await nextTick();

          findAllTabs().at(0).vm.$emit('click');
          await nextTick();

          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ search: 'persisted search' }),
          );
        });
      });

      describe('sort', () => {
        beforeEach(() => waitForPromises());

        it('passes sort: null to managed query by default (catalog priority)', () => {
          expect(mockProjectQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ sort: null }),
          );
        });

        it('passes empty initialSortBy prop to managed list by default', () => {
          expect(findManagedList().props('initialSortBy')).toBe('');
        });

        it('refetches with USAGE_COUNT_DESC when sort emits USAGE_COUNT_DESC', async () => {
          findManagedList().vm.$emit('sort', 'USAGE_COUNT_DESC');
          await nextTick();

          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ sort: 'USAGE_COUNT_DESC' }),
          );
        });

        it('refetches with USAGE_COUNT_ASC when sort emits USAGE_COUNT_ASC', async () => {
          findManagedList().vm.$emit('sort', 'USAGE_COUNT_ASC');
          await nextTick();

          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ sort: 'USAGE_COUNT_ASC' }),
          );
        });

        it('resets to CATALOG_PRIORITY and null sort when sort emits CATALOG_PRIORITY', async () => {
          findManagedList().vm.$emit('sort', 'USAGE_COUNT_DESC');
          await nextTick();

          mockProjectQueryHandler.mockClear();

          findManagedList().vm.$emit('sort', 'CATALOG_PRIORITY');
          await nextTick();

          expect(findManagedList().props('initialSortBy')).toBe('');
          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ sort: null }),
          );
        });

        it('resets pagination when sort is emitted', async () => {
          findManagedList().vm.$emit('next-page');
          await nextTick();

          findManagedList().vm.$emit('sort', 'STAR_COUNT_DESC');
          await nextTick();

          expect(mockProjectQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({
              after: null,
              before: null,
              first: 20,
              last: null,
              sort: 'STAR_COUNT_DESC',
            }),
          );
        });
      });
    });

    describe('Catalog tab', () => {
      it('renders the catalog list', async () => {
        createComponent();
        findTabs().vm.$emit('input', 2);
        await waitForPromises();

        expect(findCatalogList().exists()).toBe(true);
      });

      it('fetches catalog items', async () => {
        createComponent();
        findTabs().vm.$emit('input', 2);
        await waitForPromises();

        expect(mockCatalogQueryHandler).toHaveBeenCalled();
      });

      it('scopes the catalog query to the current project', async () => {
        createComponent();
        findTabs().vm.$emit('input', 2);
        await waitForPromises();

        expect(mockCatalogQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({ projectPath: mockProjectPath }),
        );
      });

      it('shows error message when catalog query fails', async () => {
        createComponent();
        mockCatalogQueryHandler.mockRejectedValueOnce(new Error('Query failed'));
        findTabs().vm.$emit('input', 2);
        await waitForPromises();

        expect(findErrorsAlert().props('errors')).not.toEqual([]);
      });

      describe('sort', () => {
        beforeEach(async () => {
          createComponent();
          findTabs().vm.$emit('input', 2);
          await waitForPromises();
        });

        it('passes sort: null to catalog query by default (catalog priority)', () => {
          expect(mockCatalogQueryHandler).toHaveBeenCalledWith(
            expect.objectContaining({ sort: null }),
          );
        });

        it('passes empty initialSortBy prop to catalog list by default', () => {
          expect(findCatalogList().props('initialSortBy')).toBe('');
        });

        it('refetches with STAR_COUNT_DESC when sort emits STAR_COUNT_DESC', async () => {
          findCatalogList().vm.$emit('sort', 'STAR_COUNT_DESC');
          await nextTick();

          expect(mockCatalogQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ sort: 'STAR_COUNT_DESC' }),
          );
        });

        it('refetches with STAR_COUNT_ASC when sort emits STAR_COUNT_ASC', async () => {
          findCatalogList().vm.$emit('sort', 'STAR_COUNT_ASC');
          await nextTick();

          expect(mockCatalogQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ sort: 'STAR_COUNT_ASC' }),
          );
        });

        it('resets to CATALOG_PRIORITY and null sort when sort emits CATALOG_PRIORITY', async () => {
          findCatalogList().vm.$emit('sort', 'STAR_COUNT_DESC');
          await nextTick();

          mockCatalogQueryHandler.mockClear();

          findCatalogList().vm.$emit('sort', 'CATALOG_PRIORITY');
          await nextTick();

          expect(findCatalogList().props('initialSortBy')).toBe('');
          expect(mockCatalogQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({ sort: null }),
          );
        });

        it('resets pagination when sort is emitted', async () => {
          findCatalogList().vm.$emit('next-page');
          await nextTick();

          findCatalogList().vm.$emit('sort', 'STAR_COUNT_DESC');
          await nextTick();

          expect(mockCatalogQueryHandler).toHaveBeenLastCalledWith(
            expect.objectContaining({
              after: null,
              before: null,
              first: 20,
              last: null,
              sort: 'STAR_COUNT_DESC',
            }),
          );
        });
      });
    });

    describe('URL tab state', () => {
      it('initializes the Enabled tab when no tab query param is present', () => {
        createComponent();

        expect(findTabs().props('value')).toBe(0);
      });

      it('initializes the Managed tab from ?tab=managed', () => {
        createComponent({ routeQuery: { tab: 'managed' } });

        expect(findTabs().props('value')).toBe(1);
      });

      it('initializes the Catalog tab from ?tab=catalog', () => {
        createComponent({ routeQuery: { tab: 'catalog' } });

        expect(findTabs().props('value')).toBe(2);
      });

      it('falls back to the Enabled tab when ?tab= is an unknown value', () => {
        createComponent({ routeQuery: { tab: 'bogus' } });

        expect(findTabs().props('value')).toBe(0);
      });

      it('does not write tab query when not in project namespace', async () => {
        createComponent({ provide: { isProjectNamespace: false } });
        await nextTick();

        expect(mockRouter.push).not.toHaveBeenCalled();
      });

      it('pushes ?tab=managed when the Managed tab is activated', () => {
        createComponent();
        findTabs().vm.$emit('input', 1);

        expect(mockRouter.push).toHaveBeenCalledWith({ query: { tab: 'managed' } });
      });

      it('pushes ?tab=catalog when the Catalog tab is activated', () => {
        createComponent();
        findTabs().vm.$emit('input', 2);

        expect(mockRouter.push).toHaveBeenCalledWith({ query: { tab: 'catalog' } });
      });

      it('removes the tab query when the Enabled tab is activated from another tab', () => {
        createComponent({ routeQuery: { tab: 'managed' } });
        findTabs().vm.$emit('input', 0);

        expect(mockRouter.push).toHaveBeenCalledWith({ query: {} });
      });

      it('does not push when the active tab is re-clicked', () => {
        createComponent({ routeQuery: { tab: 'managed' } });
        findTabs().vm.$emit('input', 1);

        expect(mockRouter.push).not.toHaveBeenCalled();
      });

      it('reactively follows external changes to $route.query.tab', async () => {
        createComponent();
        mockRoute.query = { tab: 'catalog' };
        await nextTick();

        expect(findTabs().props('value')).toBe(2);
      });
    });

    describe('when custom item type is deactivated in duo settings', () => {
      const duoSettingPath = '/groups/gitlab-duo/-/edit#js-gitlab-duo-settings';

      beforeEach(() => {
        createComponent({
          provide: {
            duoSettings: {
              duoCustomAgentsEnabled: false,
              duoCustomFlowsEnabled: false,
              duoExternalAgentsEnabled: true,
              duoSettingsPath: duoSettingPath,
            },
          },
        });
      });

      it('passes disabledItemTypeMessages prop to Enabled and Managed tabs', () => {
        expect(findConfiguredItemsWrapper().props('disabledItemTypeMessages')).toEqual([
          itemTypeDisabledAlertLink(config.messages.index.itemTypeDisabledAlert, duoSettingPath),
        ]);

        expect(findManagedList().props('disabledItemTypeMessages')).toEqual([
          itemTypeDisabledAlertLink(config.messages.index.itemTypeDisabledAlert, duoSettingPath),
        ]);
      });
    });

    describe('tracking', () => {
      describe('Managed tab', () => {
        it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED} when clicked`, () => {
          createComponent();
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          findAllTabs().at(1).vm.$emit('click');

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED,
            { label: config.trackLabel },
            undefined,
          );
        });

        it(`does not re-track ${TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED} when already active`, async () => {
          createComponent({ routeQuery: { tab: 'managed' } });
          await nextTick();
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          findAllTabs().at(1).vm.$emit('click');

          expect(trackEventSpy).not.toHaveBeenCalledWith(
            TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_MANAGED,
            { label: config.trackLabel },
            undefined,
          );
        });
      });

      describe('Catalog tab', () => {
        it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_CATALOG} when clicked`, () => {
          createComponent();
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          findAllTabs().at(2).vm.$emit('click');

          expect(trackEventSpy).toHaveBeenCalledWith(
            TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_CATALOG,
            { label: config.trackLabel },
            undefined,
          );
        });

        it(`does not re-track ${TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_CATALOG} when already active`, async () => {
          createComponent({ routeQuery: { tab: 'catalog' } });
          await nextTick();
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          findAllTabs().at(2).vm.$emit('click');

          expect(trackEventSpy).not.toHaveBeenCalledWith(
            TRACK_EVENT_VIEW_AI_CATALOG_PROJECT_CATALOG,
            { label: config.trackLabel },
            undefined,
          );
        });
      });
    });

    describe('group namespace', () => {
      beforeEach(() => {
        createComponent({ provide: { isProjectNamespace: false } });
      });

      it('does not render tabs', () => {
        expect(findTabs().exists()).toBe(false);
      });

      it('renders configured items wrapper without tabs', () => {
        expect(findConfiguredItemsWrapper().exists()).toBe(true);
      });

      it('passes explore href to the configured items wrapper', () => {
        expect(findConfiguredItemsWrapper().props('emptyStateButtonHref')).toBe(config.explorePath);
      });

      it('passes group-specific empty state title', () => {
        expect(findConfiguredItemsWrapper().props('emptyStateTitle')).toBe(
          config.groupEmptyStateTitle,
        );
      });
    });
  });

  describe('AGENT-specific behavior', () => {
    let mockProjectAgentsQueryHandler;
    let mockCatalogAgentsQueryHandler;
    let mockConfiguredItemsQueryHandler;

    const createAgentComponent = ({ provide = {} } = {}) => {
      setupRouteMock();
      mockProjectAgentsQueryHandler = jest.fn().mockResolvedValue(mockProjectAgentsResponse);
      mockCatalogAgentsQueryHandler = jest
        .fn()
        .mockResolvedValue(mockProjectCatalogTabAgentsResponse);
      mockConfiguredItemsQueryHandler = jest
        .fn()
        .mockResolvedValue(mockConfiguredItemsEmptyResponse);

      mockApollo = createMockApollo([
        [aiCatalogConfiguredItemsQuery, mockConfiguredItemsQueryHandler],
        [projectAiCatalogTabItemsQuery, mockCatalogAgentsQueryHandler],
        [projectAiCatalogItemsQuery, mockProjectAgentsQueryHandler],
      ]);

      wrapper = shallowMountExtended(AiItemsIndex, {
        apolloProvider: mockApollo,
        propsData: { itemType: AI_CATALOG_TYPE_AGENT },
        provide: {
          isProjectNamespace: true,
          projectId: mockProjectId,
          projectPath: mockProjectPath,
          exploreAiCatalogAgentsPath: '/explore/ai-catalog/agents',
          rootGroupId: mockRootGroupId,
          glFeatures: { aiCatalogThirdPartyFlows: true },
          ...provide,
        },
        mocks: { $toast: mockToast, $route: mockRoute, $router: mockRouter },
        stubs: { GlTab },
      });
    };

    const findTabs = () => wrapper.findComponent(GlTabs);
    const findManagedList = () => wrapper.findComponentByTestId('managed-agents-list');

    describe('itemTypes query variable', () => {
      it('includes AGENT and THIRD_PARTY_FLOW when feature flag is enabled', async () => {
        createAgentComponent({ provide: { glFeatures: { aiCatalogThirdPartyFlows: true } } });
        findTabs().vm.$emit('input', 1);
        await waitForPromises();

        expect(mockProjectAgentsQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({ itemTypes: ['AGENT', 'THIRD_PARTY_FLOW'] }),
        );
      });

      it('only includes AGENT when feature flag is disabled', async () => {
        createAgentComponent({ provide: { glFeatures: { aiCatalogThirdPartyFlows: false } } });
        findTabs().vm.$emit('input', 1);
        await waitForPromises();

        expect(mockProjectAgentsQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({ itemTypes: ['AGENT'] }),
        );
      });

      it('includes itemTypes in catalog query', async () => {
        createAgentComponent({ provide: { glFeatures: { aiCatalogThirdPartyFlows: true } } });
        findTabs().vm.$emit('input', 2);
        await waitForPromises();

        expect(mockCatalogAgentsQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({ itemTypes: ['AGENT', 'THIRD_PARTY_FLOW'] }),
        );
      });
    });

    describe('isUpdateAvailable calculation', () => {
      beforeEach(async () => {
        createAgentComponent();
        findTabs().vm.$emit('input', 1);
        await nextTick();
        await waitForPromises();
      });

      it('marks item as update available when latest and pinned versions differ', () => {
        expect(findManagedList().props('items')[0].isUpdateAvailable).toBe(true);
      });

      it('marks item as not update available when latest and pinned versions match', () => {
        expect(findManagedList().props('items')[1].isUpdateAvailable).toBe(false);
      });

      it('computes isUpdateAvailable for all items in the list', () => {
        const items = findManagedList().props('items');
        items.forEach((item) => {
          expect(item).toHaveProperty('isUpdateAvailable');
        });
      });
    });

    describe('showActionItem', () => {
      it('returns false when user lacks adminAiCatalogItemConsumer permission', () => {
        createAgentComponent({ provide: { glAbilities: { adminAiCatalogItemConsumer: false } } });
        const { showActionItem } = wrapper.vm.itemTypeConfigEnabled.disableActionItem;

        expect(showActionItem({ foundational: false })).toBe(false);
      });

      it('returns false for foundational items even when user has permission', () => {
        createAgentComponent({ provide: { glAbilities: { adminAiCatalogItemConsumer: true } } });
        const { showActionItem } = wrapper.vm.itemTypeConfigEnabled.disableActionItem;

        expect(showActionItem({ foundational: true })).toBe(false);
      });

      it('returns true when user has permission and item is not foundational', () => {
        createAgentComponent({ provide: { glAbilities: { adminAiCatalogItemConsumer: true } } });
        const { showActionItem } = wrapper.vm.itemTypeConfigEnabled.disableActionItem;

        expect(showActionItem({ foundational: false })).toBe(true);
      });
    });
  });

  describe('FLOW-specific behavior', () => {
    let mockProjectFlowsQueryHandler;
    let mockCatalogFlowsQueryHandler;
    let mockConfiguredItemsQueryHandler;

    const createFlowComponent = ({ provide = {} } = {}) => {
      setupRouteMock();
      mockProjectFlowsQueryHandler = jest.fn().mockResolvedValue(mockProjectFlowsResponse);
      mockCatalogFlowsQueryHandler = jest
        .fn()
        .mockResolvedValue(mockProjectCatalogTabFlowsResponse);
      mockConfiguredItemsQueryHandler = jest
        .fn()
        .mockResolvedValue(mockConfiguredItemsEmptyResponse);

      mockApollo = createMockApollo([
        [aiCatalogConfiguredItemsQuery, mockConfiguredItemsQueryHandler],
        [projectAiCatalogTabItemsQuery, mockCatalogFlowsQueryHandler],
        [projectAiCatalogItemsQuery, mockProjectFlowsQueryHandler],
      ]);

      wrapper = shallowMountExtended(AiItemsIndex, {
        apolloProvider: mockApollo,
        propsData: { itemType: AI_CATALOG_TYPE_FLOW },
        provide: {
          isProjectNamespace: true,
          projectId: mockProjectId,
          projectPath: mockProjectPath,
          exploreAiCatalogFlowsPath: '/explore/ai-catalog/flows',
          rootGroupId: mockRootGroupId,
          ...provide,
        },
        mocks: { $toast: mockToast, $route: mockRoute, $router: mockRouter },
        stubs: { GlTab },
      });
    };

    const findTabs = () => wrapper.findComponent(GlTabs);

    describe('itemTypes query variable', () => {
      it('includes itemTypes in managed query', async () => {
        createFlowComponent();
        findTabs().vm.$emit('input', 1);
        await waitForPromises();

        expect(mockProjectFlowsQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({ itemTypes: ['FLOW'] }),
        );
      });

      it('includes itemTypes in catalog query', async () => {
        createFlowComponent();
        findTabs().vm.$emit('input', 2);
        await waitForPromises();

        expect(mockCatalogFlowsQueryHandler).toHaveBeenCalledWith(
          expect.objectContaining({ itemTypes: ['FLOW'] }),
        );
      });
    });

    describe('showActionItem', () => {
      it('returns false when user lacks adminAiCatalogItemConsumer permission', () => {
        createFlowComponent({ provide: { glAbilities: { adminAiCatalogItemConsumer: false } } });
        const { showActionItem } = wrapper.vm.itemTypeConfigEnabled.disableActionItem;

        expect(showActionItem({ foundational: false })).toBe(false);
      });

      it('returns true for foundational items at the project level when user has permission', () => {
        createFlowComponent({ provide: { glAbilities: { adminAiCatalogItemConsumer: true } } });
        const { showActionItem } = wrapper.vm.itemTypeConfigEnabled.disableActionItem;

        expect(showActionItem({ foundational: true })).toBe(true);
      });

      it('returns false for foundational items at the group level even when user has permission', () => {
        createFlowComponent({
          provide: {
            isProjectNamespace: false,
            isGroupNamespace: true,
            glAbilities: { adminAiCatalogItemConsumer: true },
          },
        });
        const { showActionItem } = wrapper.vm.itemTypeConfigEnabled.disableActionItem;

        expect(showActionItem({ foundational: true })).toBe(false);
      });

      it('returns true for non-foundational items at the group level when user has permission', () => {
        createFlowComponent({
          provide: {
            isProjectNamespace: false,
            isGroupNamespace: true,
            glAbilities: { adminAiCatalogItemConsumer: true },
          },
        });
        const { showActionItem } = wrapper.vm.itemTypeConfigEnabled.disableActionItem;

        expect(showActionItem({ foundational: false })).toBe(true);
      });

      it('returns true for non-foundational items when user has permission', () => {
        createFlowComponent({ provide: { glAbilities: { adminAiCatalogItemConsumer: true } } });
        const { showActionItem } = wrapper.vm.itemTypeConfigEnabled.disableActionItem;

        expect(showActionItem({ foundational: false })).toBe(true);
      });
    });
  });
});
