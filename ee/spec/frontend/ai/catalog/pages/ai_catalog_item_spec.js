import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiCatalogItem from 'ee/ai/catalog/pages/ai_catalog_item.vue';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import aiFoundationalChatAgentQuery from 'ee/ai/catalog/graphql/queries/ai_foundational_chat_agent.query.graphql';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
  VERIFICATION_LEVEL_GITLAB_MAINTAINED,
  VERSION_PINNED,
  VERSION_PINNED_GROUP,
  VERSION_LATEST,
} from 'ee/ai/catalog/constants';
import { AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import * as utils from 'ee/ai/catalog/utils';
import {
  mockAiCatalogAgentResponse,
  mockAiCatalogAgentNullResponse,
  mockAgent,
  mockAgentConfigurationForProject,
  mockItemConfigurationForGroup,
  mockAgentVersion,
  mockAgentPinnedVersion,
  mockAgentGroupPinnedVersion,
  mockProjectWithGroup,
  mockAiCatalogFlowResponse,
  mockAiCatalogFlowNullResponse,
  mockFlow,
  mockFlowConfigurationForProject,
  mockFlowConfigurationForGroup,
  mockFlowVersion,
  mockFlowPinnedVersion,
  mockFlowGroupPinnedVersion,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const RouterViewStub = {
  name: 'RouterViewStub',
  props: ['aiCatalogItem', 'version'],
  template: '<div />',
};

const TEST_CASES = [
  {
    description: 'AiCatalogItem (agent)',
    itemType: AI_CATALOG_TYPE_AGENT,
    query: aiCatalogAgentQuery,
    mockResponse: mockAiCatalogAgentResponse,
    mockNullResponse: mockAiCatalogAgentNullResponse,
    mockItem: mockAgent,
    mockItemWithBothConfigs: {
      ...mockAgent,
      project: mockProjectWithGroup,
      isEnabledInManagedByProject: false,
      configurationForProject: mockAgentConfigurationForProject,
      configurationForGroup: mockItemConfigurationForGroup,
    },
    configForProject: mockAgentConfigurationForProject,
    configForGroup: mockItemConfigurationForGroup,
    mockVersion: mockAgentVersion,
    mockPinnedVersion: mockAgentPinnedVersion,
    mockGroupPinnedVersion: mockAgentGroupPinnedVersion,
    notFoundTitle: 'Agent not found.',
    errorMessage: 'Agent does not exist',
    pageTitle: 'Agents · Automate · GitLab',
    invalidItemType: 'FLOW',
    expectedPageTitle: 'My Agent · Agents · Automate · GitLab',
    itemName: 'My Agent',
  },
  {
    description: 'AiCatalogItem (flow)',
    itemType: AI_CATALOG_TYPE_FLOW,
    query: aiCatalogFlowQuery,
    mockResponse: mockAiCatalogFlowResponse,
    mockNullResponse: mockAiCatalogFlowNullResponse,
    mockItem: mockFlow,
    mockItemWithBothConfigs: {
      ...mockFlow,
      isEnabledInManagedByProject: false,
      configurationForProject: mockFlowConfigurationForProject,
      configurationForGroup: mockFlowConfigurationForGroup,
    },
    configForProject: mockFlowConfigurationForProject,
    configForGroup: mockFlowConfigurationForGroup,
    mockVersion: mockFlowVersion,
    mockPinnedVersion: mockFlowPinnedVersion,
    mockGroupPinnedVersion: mockFlowGroupPinnedVersion,
    notFoundTitle: 'Flow not found.',
    errorMessage: 'Flow does not exist',
    pageTitle: 'Flows · Automate · GitLab',
    invalidItemType: 'AGENT',
    expectedPageTitle: 'My Flow · Flows · Automate · GitLab',
    itemName: 'My Flow',
  },
];

describe.each(TEST_CASES)(
  '$description',
  ({
    itemType,
    query,
    mockResponse,
    mockNullResponse,
    mockItem,
    mockItemWithBothConfigs,
    configForProject,
    configForGroup,
    mockVersion,
    mockPinnedVersion,
    mockGroupPinnedVersion,
    notFoundTitle,
    errorMessage,
    pageTitle,
    invalidItemType,
    expectedPageTitle,
    itemName,
  }) => {
    let wrapper;
    let mockApollo;
    let mockQueryHandler;
    let mockNullQueryHandler;

    const itemId = 1;
    const routeParams = { id: itemId };
    const defaultProvide = { isGlobalNamespace: false, isGroupNamespace: false };

    const createComponent = ({ queryHandler = mockQueryHandler, provide = {} } = {}) => {
      mockApollo = createMockApollo([[query, queryHandler]]);

      wrapper = shallowMount(AiCatalogItem, {
        apolloProvider: mockApollo,
        provide: { ...defaultProvide, ...provide },
        propsData: { itemType },
        mocks: {
          $route: {
            params: routeParams,
          },
        },
        stubs: {
          RouterView: RouterViewStub,
        },
      });
    };

    const findErrorAlert = () => wrapper.findComponent(ErrorsAlert);
    const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
    const findGlEmptyState = () => wrapper.findComponent(GlEmptyState);
    const findRouterView = () => wrapper.findComponent(RouterViewStub);

    beforeEach(() => {
      mockQueryHandler = jest.fn().mockResolvedValue(mockResponse);
      mockNullQueryHandler = jest.fn().mockResolvedValue(mockNullResponse);
    });

    afterEach(() => {
      mockQueryHandler.mockRestore();
      mockNullQueryHandler.mockRestore();
    });

    describe('loading', () => {
      beforeEach(() => {
        createComponent({
          provide: { projectId: '1', rootGroupId: '1' },
        });
      });

      it('renders loading icon while fetching data', async () => {
        expect(findGlLoadingIcon().exists()).toBe(true);

        await waitForPromises();

        expect(findGlLoadingIcon().exists()).toBe(false);
      });
    });

    describe('when request succeeds but returns null', () => {
      beforeEach(async () => {
        createComponent({ queryHandler: mockNullQueryHandler });
        await waitForPromises();
      });

      it('renders empty state', () => {
        expect(findGlEmptyState().exists()).toBe(true);
        expect(findGlEmptyState().props('title')).toBe(notFoundTitle);
      });

      it('does not render router view', () => {
        expect(findRouterView().exists()).toBe(false);
      });
    });

    describe('when request succeeds', () => {
      beforeEach(async () => {
        createComponent({
          provide: { projectId: '1', rootGroupId: '1' },
        });
        await waitForPromises();
      });

      it('does not render empty state', () => {
        expect(findGlEmptyState().exists()).toBe(false);
      });

      it(`renders the router view`, () => {
        expect(findRouterView().exists()).toBe(true);
      });
    });

    describe('when displaying soft-deleted items', () => {
      it('should show soft-deleted items in the Projects area', async () => {
        createComponent({
          provide: { projectId: '1', rootGroupId: '1' },
        });
        await waitForPromises();

        expect(mockQueryHandler).toHaveBeenCalledWith({
          id: 'gid://gitlab/Ai::Catalog::Item/1',
          showSoftDeleted: true,
          hasProject: true,
          projectId: 'gid://gitlab/Project/1',
          hasGroup: true,
          groupId: 'gid://gitlab/Group/1',
        });
      });

      it('should not show soft-deleted items in the explore area', async () => {
        createComponent({
          provide: { isGlobalNamespace: true },
        });
        await waitForPromises();

        expect(mockQueryHandler).toHaveBeenCalledWith({
          id: 'gid://gitlab/Ai::Catalog::Item/1',
          showSoftDeleted: false,
          hasProject: false,
          projectId: 'gid://gitlab/Project/0',
          hasGroup: false,
          groupId: 'gid://gitlab/Group/0',
        });
      });
    });

    describe('when request fails', () => {
      const error = new Error('Request failed');

      beforeEach(async () => {
        createComponent({ queryHandler: jest.fn().mockRejectedValue(error) });
        await waitForPromises();
      });

      it('does not render router view', () => {
        expect(findRouterView().exists()).toBe(false);
      });

      it('renders empty state', () => {
        expect(findGlEmptyState().exists()).toBe(true);
      });

      it('renders and captures error', () => {
        expect(findErrorAlert().exists()).toBe(true);
        expect(findErrorAlert().props('errors')).toEqual([errorMessage]);
        expect(Sentry.captureException).toHaveBeenCalledWith(error);
      });
    });

    describe('when displaying different item versions', () => {
      let resolveVersionSpy;

      const mockItemBothConfigsHandler = jest.fn().mockResolvedValue({
        data: { aiCatalogItem: mockItemWithBothConfigs },
      });

      beforeEach(() => {
        resolveVersionSpy = jest
          .spyOn(utils, 'resolveVersion')
          .mockReturnValue({ ...mockVersion, key: VERSION_LATEST });
      });

      afterEach(() => {
        resolveVersionSpy.mockRestore();
      });

      it('should show latest version when in the explore area', async () => {
        createComponent({
          provide: { isGlobalNamespace: true },
        });
        await waitForPromises();

        const routerView = findRouterView();
        expect(routerView.props('version')).toMatchObject({
          isUpdateAvailable: false,
          activeVersionKey: VERSION_LATEST,
        });
      });

      it('should show group pinned version when in the group area', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockGroupPinnedVersion,
          key: VERSION_PINNED_GROUP,
        });

        createComponent({
          provide: { groupId: '1', projectId: null, isGroupNamespace: true },
        });
        await waitForPromises();

        expect(resolveVersionSpy).toHaveBeenCalledWith(expect.any(Object), {
          isGlobalNamespace: false,
          isGroupNamespace: true,
        });

        const routerView = findRouterView();
        expect(routerView.props('version')).toMatchObject({
          isUpdateAvailable: true,
          activeVersionKey: VERSION_PINNED_GROUP,
        });
      });

      it('should show project pinned version when in project area', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockPinnedVersion,
          key: VERSION_PINNED,
        });

        createComponent({
          provide: { projectId: '1', rootGroupId: '1' },
          queryHandler: mockItemBothConfigsHandler,
        });
        await waitForPromises();

        expect(resolveVersionSpy).toHaveBeenCalledWith(mockItemWithBothConfigs, {
          isGlobalNamespace: false,
          isGroupNamespace: false,
        });

        const routerView = findRouterView();
        expect(routerView.props('version')).toMatchObject({
          isUpdateAvailable: true,
          activeVersionKey: VERSION_PINNED,
        });
      });

      it('should show the latest version when in the project area without a project configuration', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockVersion,
          key: VERSION_LATEST,
        });

        const aiCatalogItemWithGroupConfigOnly = {
          ...mockItem,
          isEnabledInManagedByProject: false,
          configurationForProject: null,
          configurationForGroup: configForGroup,
        };

        const mockItemWithGroupConfigOnlyHandler = jest.fn().mockResolvedValue({
          data: { aiCatalogItem: aiCatalogItemWithGroupConfigOnly },
        });

        createComponent({
          provide: { projectId: '1', rootGroupId: '1' },
          queryHandler: mockItemWithGroupConfigOnlyHandler,
        });
        await waitForPromises();

        expect(resolveVersionSpy).toHaveBeenCalledWith(aiCatalogItemWithGroupConfigOnly, {
          isGlobalNamespace: false,
          isGroupNamespace: false,
        });

        const routerView = findRouterView();
        expect(routerView.props('version')).toMatchObject({
          isUpdateAvailable: false,
          activeVersionKey: VERSION_LATEST,
        });
      });

      it('should show latest version when in the project area without a group nor project configuration', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockVersion,
          key: VERSION_LATEST,
        });

        const aiCatalogItemWithNoConfig = {
          ...mockItem,
          isEnabledInManagedByProject: false,
          configurationForProject: null,
        };

        const mockItemWithNoConfigHandler = jest.fn().mockResolvedValue({
          data: { aiCatalogItem: aiCatalogItemWithNoConfig },
        });

        createComponent({
          provide: { projectId: '1' },
          queryHandler: mockItemWithNoConfigHandler,
        });
        await waitForPromises();

        expect(resolveVersionSpy).toHaveBeenCalledWith(aiCatalogItemWithNoConfig, {
          isGlobalNamespace: false,
          isGroupNamespace: false,
        });

        const routerView = findRouterView();
        expect(routerView.props('version')).toMatchObject({
          isUpdateAvailable: false,
          activeVersionKey: VERSION_LATEST,
        });
      });
    });

    describe(`when itemType does not match ${itemType}`, () => {
      it('renders item not found', async () => {
        const mockWrongTypeResponse = {
          data: {
            aiCatalogItem: {
              ...mockItem,
              isEnabledInManagedByProject: false,
              itemType: invalidItemType,
            },
          },
        };
        createComponent({
          queryHandler: jest.fn().mockResolvedValue(mockWrongTypeResponse),
        });

        await waitForPromises();

        expect(findGlEmptyState().exists()).toBe(true);
        expect(findRouterView().exists()).toBe(false);
      });
    });

    describe('adds the correct page title', () => {
      const makeItemResponse = (name) => ({
        data: {
          aiCatalogItem: {
            ...mockItem,
            name,
            isEnabledInManagedByProject: false,
            configurationForProject: configForProject,
            configurationForGroup: configForGroup,
          },
        },
      });

      it('prefixes the item name to the base page title', async () => {
        document.title = pageTitle;

        const mockItemWithNameHandler = jest.fn().mockResolvedValue(makeItemResponse(itemName));

        createComponent({
          queryHandler: mockItemWithNameHandler,
          provide: { projectId: '1', rootGroupId: '1' },
        });
        await waitForPromises();

        expect(document.title).toBe(expectedPageTitle);
      });

      it('does not prepend the updated name to the already-updated title on refetch', async () => {
        document.title = pageTitle;

        const updatedName = `Updated ${itemName}`;
        const mockItemWithNameHandler = jest
          .fn()
          .mockResolvedValueOnce(makeItemResponse(itemName))
          .mockResolvedValueOnce(makeItemResponse(updatedName));

        createComponent({
          queryHandler: mockItemWithNameHandler,
          provide: { projectId: '1', rootGroupId: '1' },
        });
        await waitForPromises();

        expect(document.title).toBe(expectedPageTitle);

        await wrapper.vm.$apollo.queries.aiCatalogItem.refetch();
        await waitForPromises();

        expect(document.title).toBe(`${updatedName} · ${pageTitle}`);
      });

      it('prepends the section title when document.title does not include it', async () => {
        const baseDocTitle = 'GitLab';
        document.title = baseDocTitle;

        const sectionTitle = pageTitle.split(' · ')[0];

        const mockItemWithNameHandler = jest.fn().mockResolvedValue(makeItemResponse(itemName));

        createComponent({
          queryHandler: mockItemWithNameHandler,
          provide: { projectId: '1', rootGroupId: '1' },
        });
        await waitForPromises();

        expect(document.title).toBe(`${itemName} · ${sectionTitle} · ${baseDocTitle}`);
      });
    });
  },
);

describe('AiCatalogItem (foundational agent)', () => {
  let wrapper;
  let mockApollo;

  const mockFoundationalChatAgent = {
    id: 'gid://gitlab/Ai::FoundationalChatAgent/1',
    name: 'GitLab Duo Chat',
    description: 'A foundational chat agent',
    reference: 'gitlab-duo-chat',
    referenceWithVersion: 'gitlab-duo-chat@1.0',
    version: '1.0',
    avatarUrl: null,
    systemPrompt: 'You are a helpful assistant',
    tools: [{ id: 'tool-1', title: 'Search', description: 'Search tool' }],
  };

  const mockFoundationalChatAgentResponse = {
    data: {
      aiFoundationalChatAgent: mockFoundationalChatAgent,
    },
  };

  const findRouterView = () => wrapper.findComponent(RouterViewStub);

  const mockFoundationalHandler = jest.fn().mockResolvedValue(mockFoundationalChatAgentResponse);

  const createComponent = () => {
    mockApollo = createMockApollo([[aiFoundationalChatAgentQuery, mockFoundationalHandler]]);

    wrapper = shallowMount(AiCatalogItem, {
      apolloProvider: mockApollo,
      provide: { isGlobalNamespace: false },
      propsData: { itemType: AI_CATALOG_TYPE_FOUNDATIONAL_AGENT },
      mocks: {
        $route: {
          params: { reference: 'gitlab-duo-chat' },
          matched: [{ name: AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE }],
        },
      },
      stubs: {
        RouterView: RouterViewStub,
      },
    });
  };

  it('uses the foundational chat agent query', () => {
    createComponent();

    expect(mockFoundationalHandler).toHaveBeenCalledWith({
      reference: 'gitlab-duo-chat',
    });
  });

  it('transforms the response into a catalog item shape', async () => {
    createComponent();
    await waitForPromises();

    const routerView = findRouterView();
    expect(routerView.exists()).toBe(true);

    const item = routerView.props('aiCatalogItem');
    expect(item.itemType).toBe(AI_CATALOG_TYPE_FOUNDATIONAL_AGENT);
    expect(item.foundational).toBe(true);
    expect(item.verificationLevel).toBe(VERIFICATION_LEVEL_GITLAB_MAINTAINED);
    expect(item.name).toBe(mockFoundationalChatAgent.name);
    expect(item.description).toBe(mockFoundationalChatAgent.description);
    expect(item.latestVersion.systemPrompt).toBe(mockFoundationalChatAgent.systemPrompt);
    expect(item.latestVersion.tools.nodes).toEqual(mockFoundationalChatAgent.tools);
    expect(item.latestVersion.mcpServers.nodes).toEqual([]);
    expect(item.latestVersion.humanVersionName).toBe('1.0');
  });
});
