import Vue from 'vue';
import VueApollo from 'vue-apollo';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import createAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import createAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import createAiCatalogThirdPartyFlow from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_third_party_flow.mutation.graphql';
import AiCatalogItemDuplicate from 'ee/ai/catalog/pages/ai_catalog_item_duplicate.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import {
  AI_CATALOG_TYPE_AGENT,
  VERSION_LATEST,
  VERSION_PINNED,
  VERSION_PINNED_GROUP,
  VISIBILITY_LEVEL_RESTRICTED,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';
import {
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
} from 'ee/ai/catalog/router/constants';
import * as utils from 'ee/ai/catalog/utils';
import {
  mockAgent,
  mockFlow,
  mockAgentVersion,
  mockAgentPinnedVersion,
  mockAgentGroupPinnedVersion,
  mockFlowVersion,
  mockFlowPinnedVersion,
  mockFlowGroupPinnedVersion,
  mockAgentConfigurationForProject,
  mockItemConfigurationForGroup,
  mockFlowConfigurationForProject,
  mockFlowConfigurationForGroup,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowErrorMutation,
  mockCreateAiCatalogThirdPartyFlowSuccessMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');
jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

describe('AiCatalogItemDuplicate', () => {
  let wrapper;
  let createAiCatalogAgentMock;
  let createAiCatalogFlowMock;
  let createAiCatalogThirdPartyFlowMock;
  let resolveVersionSpy;

  const mockToast = { show: jest.fn() };
  const mockRouter = { push: jest.fn() };
  const itemId = 1;

  const defaultProvide = {
    isGlobalNamespace: false,
    isGroupNamespace: false,
    glAbilities: { adminAiCatalogItem: true },
    glFeatures: {},
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    createAiCatalogAgentMock = jest.fn().mockResolvedValue(mockCreateAiCatalogAgentSuccessMutation);
    createAiCatalogFlowMock = jest.fn().mockResolvedValue(mockCreateAiCatalogFlowSuccessMutation);
    createAiCatalogThirdPartyFlowMock = jest
      .fn()
      .mockResolvedValue(mockCreateAiCatalogThirdPartyFlowSuccessMutation);

    const apolloProvider = createMockApollo([
      [createAiCatalogAgent, createAiCatalogAgentMock],
      [createAiCatalogFlow, createAiCatalogFlowMock],
      [createAiCatalogThirdPartyFlow, createAiCatalogThirdPartyFlowMock],
    ]);

    wrapper = shallowMountExtended(AiCatalogItemDuplicate, {
      apolloProvider,
      propsData: props,
      provide: {
        ...defaultProvide,
        ...provide,
      },
      mocks: {
        $route: { params: { id: itemId } },
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findAgentForm = () => wrapper.findComponent(AiCatalogAgentForm);
  const findFlowForm = () => wrapper.findComponent(AiCatalogFlowForm);
  const findPageHeading = () => wrapper.findComponent(PageHeading);

  beforeEach(() => {
    mockRouter.push.mockClear();
    mockToast.show.mockClear();
  });

  afterEach(() => {
    resolveVersionSpy?.mockRestore();
  });

  describe('when itemType is AGENT', () => {
    beforeEach(() => {
      resolveVersionSpy = jest.spyOn(utils, 'resolveVersion').mockReturnValue({
        ...mockAgentVersion,
        key: VERSION_LATEST,
      });
    });

    describe('Page Heading', () => {
      beforeEach(() => {
        createComponent({ props: { aiCatalogItem: mockAgent } });
      });

      it('renders page heading with correct title and description', () => {
        expect(findPageHeading().props('heading')).toBe('Duplicate agent');
        expect(findPageHeading().text()).toContain(
          'Create a copy of this agent with the same configuration.',
        );
      });
    });

    it('renders the agent form', () => {
      createComponent({ props: { aiCatalogItem: mockAgent } });

      expect(findAgentForm().exists()).toBe(true);
    });

    describe('Form Initial Values', () => {
      const baseExpectedInitialValues = {
        name: `Copy of ${mockAgent.name}`,
        description: mockAgent.description,
        itemType: AI_CATALOG_TYPE_AGENT,
        public: false,
        mcpTools: [],
        mcpServers: [],
        definition: '',
        visibility: VISIBILITY_LEVEL_PRIVATE,
      };

      const expectedInitialValuesWithLatestVersion = {
        ...baseExpectedInitialValues,
        systemPrompt: mockAgent.latestVersion.systemPrompt,
        tools: mockAgent.latestVersion.tools.nodes.map((t) => t.id),
      };

      const expectedInitialValuesWithGroupPinnedVersion = {
        ...baseExpectedInitialValues,
        systemPrompt: mockItemConfigurationForGroup.pinnedItemVersion.systemPrompt,
        tools: mockItemConfigurationForGroup.pinnedItemVersion.tools.nodes.map((t) => t.id),
      };

      const expectedInitialValuesWithProjectPinnedVersion = {
        ...baseExpectedInitialValues,
        systemPrompt: mockAgentConfigurationForProject.pinnedItemVersion.systemPrompt,
        tools: mockAgentConfigurationForProject.pinnedItemVersion.tools.nodes.map((t) => t.id),
      };

      const findInitialValues = () => findAgentForm().props('initialValues');

      it('sets initial values from the resolved version in global context', async () => {
        const item = { ...mockAgent, configurationForProject: mockAgentConfigurationForProject };

        createComponent({
          props: { aiCatalogItem: item },
          provide: { isGlobalNamespace: true },
        });
        await waitForPromises();

        expect(findInitialValues()).toEqual(expectedInitialValuesWithLatestVersion);
        expect(resolveVersionSpy).toHaveBeenCalledWith(expect.objectContaining(item), {
          isGlobalNamespace: true,
          isGroupNamespace: false,
        });
      });

      it('sets initial values to group-pinned version when only group configuration is present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockAgentGroupPinnedVersion,
          key: VERSION_PINNED_GROUP,
        });

        const item = { ...mockAgent, configurationForGroup: mockItemConfigurationForGroup };

        createComponent({
          props: { aiCatalogItem: item },
          provide: { projectId: '1' },
        });
        await waitForPromises();

        expect(findInitialValues()).toEqual(expectedInitialValuesWithGroupPinnedVersion);
      });

      it('sets initial values to project-pinned version when both configurations are present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockAgentPinnedVersion,
          key: VERSION_PINNED,
        });

        const item = {
          ...mockAgent,
          configurationForGroup: mockItemConfigurationForGroup,
          configurationForProject: mockAgentConfigurationForProject,
        };

        createComponent({
          props: { aiCatalogItem: item },
          provide: { projectId: '1' },
        });
        await waitForPromises();

        expect(findInitialValues()).toEqual(expectedInitialValuesWithProjectPinnedVersion);
      });

      it('forces public to false when duplicating a public item', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockAgentPinnedVersion,
          key: VERSION_PINNED,
        });

        const item = {
          ...mockAgent,
          configurationForProject: { ...mockAgentConfigurationForProject, public: true },
        };

        createComponent({
          props: { aiCatalogItem: item },
          provide: { projectId: '1' },
        });
        await waitForPromises();

        expect(findInitialValues().public).toBe(false);
        expect(findInitialValues()).not.toHaveProperty('project');
      });

      describe('when duplicating a restricted agent', () => {
        const restrictedAgent = {
          ...mockAgent,
          public: false,
          visibility: VISIBILITY_LEVEL_RESTRICTED,
        };

        it('pre-selects Restricted when aiCatalogInternalVisibility is enabled', async () => {
          createComponent({
            props: { aiCatalogItem: restrictedAgent },
            provide: { glFeatures: { aiCatalogInternalVisibility: true } },
          });
          await waitForPromises();

          expect(findInitialValues().visibility).toBe(VISIBILITY_LEVEL_RESTRICTED);
        });

        it('pre-selects Private when aiCatalogInternalVisibility is disabled', async () => {
          createComponent({
            props: { aiCatalogItem: restrictedAgent },
          });
          await waitForPromises();

          expect(findInitialValues().visibility).toBe(VISIBILITY_LEVEL_PRIVATE);
        });
      });
    });

    describe('Form Submit', () => {
      const { name, description, project } = mockAgent;
      const input = {
        name: `${name} 2`,
        description,
        projectId: project.id,
        systemPrompt: 'A new system prompt',
        public: true,
        visibility: VISIBILITY_LEVEL_PUBLIC,
      };

      const submitForm = () =>
        findAgentForm().vm.$emit('submit', { itemType: AI_CATALOG_TYPE_AGENT, ...input });

      beforeEach(async () => {
        createComponent({ props: { aiCatalogItem: mockAgent } });
        await waitForPromises();
      });

      it('sends a create request', () => {
        submitForm();

        expect(createAiCatalogAgentMock).toHaveBeenCalledTimes(1);
        expect(createAiCatalogAgentMock).toHaveBeenCalledWith({ input });
      });

      it('sets a loading state on the form while submitting', async () => {
        expect(findAgentForm().props('isLoading')).toBe(false);

        await submitForm();

        expect(findAgentForm().props('isLoading')).toBe(true);
      });

      describe('when request succeeds', () => {
        beforeEach(async () => {
          submitForm();
          await waitForPromises();
        });

        it('shows toast', () => {
          expect(mockToast.show).toHaveBeenCalledWith('Agent created.');
        });

        it('navigates to agents show page', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: 1 },
          });
        });
      });

      describe('when request fails', () => {
        beforeEach(async () => {
          createAiCatalogAgentMock.mockRejectedValue(new Error());
          submitForm();
          await waitForPromises();
        });

        it('sets error messages and captures exception', () => {
          expect(findAgentForm().props('errors')).toEqual([
            'Could not create agent in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
          ]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
          expect(findAgentForm().props('isLoading')).toBe(false);
        });

        it('allows user to dismiss errors', async () => {
          await findAgentForm().vm.$emit('dismiss-errors');

          expect(findAgentForm().props('errors')).toEqual([]);
        });
      });

      describe('when request succeeds but returns error', () => {
        beforeEach(async () => {
          createAiCatalogAgentMock.mockResolvedValue(mockCreateAiCatalogAgentErrorMutation);
          submitForm();
          await waitForPromises();
        });

        it('shows an alert', () => {
          expect(findAgentForm().props('errors')).toEqual([
            mockCreateAiCatalogAgentErrorMutation.data.aiCatalogAgentCreate.errors[0],
          ]);
          expect(findAgentForm().props('isLoading')).toBe(false);
        });
      });

      describe('when form submits as THIRD_PARTY_FLOW', () => {
        const thirdPartyInput = {
          name,
          description,
          projectId: project.id,
          public: true,
          definition: 'image:node@22',
          visibility: VISIBILITY_LEVEL_PUBLIC,
        };

        const submitThirdPartyFlow = () =>
          findAgentForm().vm.$emit('submit', {
            itemType: 'THIRD_PARTY_FLOW',
            ...thirdPartyInput,
          });

        it('uses the third-party flow create mutation', () => {
          submitThirdPartyFlow();

          expect(createAiCatalogAgentMock).not.toHaveBeenCalled();
          expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledTimes(1);
          expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledWith({
            input: thirdPartyInput,
          });
        });
      });
    });

    describe('created hook - redirect behavior', () => {
      it.each([
        {
          name: 'allows duplication in global area with admin permissions',
          isGlobalNamespace: true,
          isThirdPartyFlow: false,
          isCreateThirdPartyFlowsAvailable: true,
          userPermissions: { adminAiCatalogItem: true },
          shouldRedirect: false,
        },
        {
          name: 'allows duplication in global area without admin permissions',
          isGlobalNamespace: true,
          isThirdPartyFlow: false,
          isCreateThirdPartyFlowsAvailable: true,
          userPermissions: { adminAiCatalogItem: false },
          shouldRedirect: false,
        },
        {
          name: 'allows duplication in non-global area with admin permissions',
          isGlobalNamespace: false,
          isThirdPartyFlow: false,
          isCreateThirdPartyFlowsAvailable: true,
          userPermissions: { adminAiCatalogItem: true },
          shouldRedirect: false,
        },
        {
          name: 'redirects in non-global area without admin permissions',
          isGlobalNamespace: false,
          isThirdPartyFlow: false,
          isCreateThirdPartyFlowsAvailable: true,
          userPermissions: { adminAiCatalogItem: false },
          shouldRedirect: true,
        },
        {
          name: 'redirects when duplicating an external agent with create feature disabled',
          isGlobalNamespace: true,
          isThirdPartyFlow: true,
          isCreateThirdPartyFlowsAvailable: false,
          userPermissions: { adminAiCatalogItem: true },
          shouldRedirect: true,
        },
      ])(
        '$name',
        ({
          isGlobalNamespace,
          isThirdPartyFlow,
          isCreateThirdPartyFlowsAvailable,
          userPermissions,
          shouldRedirect,
        }) => {
          const itemType = isThirdPartyFlow ? 'THIRD_PARTY_FLOW' : AI_CATALOG_TYPE_AGENT;
          const item = { ...mockAgent, itemType, userPermissions };

          createComponent({
            props: { aiCatalogItem: item },
            provide: {
              isGlobalNamespace,
              glAbilities: { createAiCatalogThirdPartyFlow: isCreateThirdPartyFlowsAvailable },
              glFeatures: {
                aiCatalogThirdPartyFlows: isCreateThirdPartyFlowsAvailable,
                aiCatalogCreateThirdPartyFlows: isCreateThirdPartyFlowsAvailable,
              },
            },
          });

          if (shouldRedirect) {
            expect(mockRouter.push).toHaveBeenCalledWith({
              name: AI_CATALOG_AGENTS_SHOW_ROUTE,
              params: { id: itemId },
            });
          } else {
            expect(mockRouter.push).not.toHaveBeenCalled();
          }
        },
      );
    });
  });

  describe('when itemType is FLOW', () => {
    beforeEach(() => {
      resolveVersionSpy = jest.spyOn(utils, 'resolveVersion').mockReturnValue({
        ...mockFlowVersion,
        key: VERSION_LATEST,
      });
    });

    describe('Page Heading', () => {
      beforeEach(() => {
        createComponent({ props: { aiCatalogItem: mockFlow } });
      });

      it('renders page heading with correct title and description', () => {
        expect(findPageHeading().props('heading')).toBe('Duplicate flow');
        expect(findPageHeading().text()).toContain(
          'Duplicate this flow with all its settings and configuration.',
        );
      });
    });

    it('renders the flow form', () => {
      createComponent({ props: { aiCatalogItem: mockFlow } });

      expect(findFlowForm().exists()).toBe(true);
    });

    describe('Form Initial Values', () => {
      const baseExpectedInitialValues = {
        name: `Copy of ${mockFlow.name}`,
        description: mockFlow.description,
        public: false,
        visibility: VISIBILITY_LEVEL_PRIVATE,
      };

      const findInitialValues = () => findFlowForm().props('initialValues');

      it('sets initial values to latest version in global context', async () => {
        const item = { ...mockFlow, configurationForProject: mockFlowConfigurationForProject };

        createComponent({
          props: { aiCatalogItem: item },
          provide: { isGlobalNamespace: true },
        });
        await waitForPromises();

        expect(findInitialValues()).toEqual({
          ...baseExpectedInitialValues,
          definition: mockFlow.latestVersion.definition,
        });
        expect(resolveVersionSpy).toHaveBeenCalledWith(expect.objectContaining(item), {
          isGlobalNamespace: true,
          isGroupNamespace: false,
        });
      });

      it('sets initial values to group-pinned version when only group configuration is present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockFlowGroupPinnedVersion,
          key: VERSION_PINNED_GROUP,
        });

        const item = { ...mockFlow, configurationForGroup: mockFlowConfigurationForGroup };

        createComponent({
          props: { aiCatalogItem: item },
          provide: { projectId: '1' },
        });
        await waitForPromises();

        expect(findInitialValues()).toEqual({
          ...baseExpectedInitialValues,
          definition: mockFlowConfigurationForGroup.pinnedItemVersion.definition,
        });
      });

      it('sets initial values to project-pinned version when both configurations are present', async () => {
        resolveVersionSpy.mockReturnValue({
          ...mockFlowPinnedVersion,
          key: VERSION_PINNED,
        });

        const item = {
          ...mockFlow,
          configurationForGroup: mockFlowConfigurationForGroup,
          configurationForProject: mockFlowConfigurationForProject,
        };

        createComponent({
          props: { aiCatalogItem: item },
          provide: { projectId: '1' },
        });
        await waitForPromises();

        expect(findInitialValues()).toEqual({
          ...baseExpectedInitialValues,
          definition: mockFlowConfigurationForProject.pinnedItemVersion.definition,
        });
      });

      describe('when duplicating a restricted flow', () => {
        const restrictedFlow = {
          ...mockFlow,
          public: false,
          visibility: VISIBILITY_LEVEL_RESTRICTED,
        };

        it('pre-selects Restricted when aiCatalogInternalVisibility is enabled', async () => {
          createComponent({
            props: { aiCatalogItem: restrictedFlow },
            provide: { glFeatures: { aiCatalogInternalVisibility: true } },
          });
          await waitForPromises();

          expect(findInitialValues().visibility).toBe(VISIBILITY_LEVEL_RESTRICTED);
        });

        it('pre-selects Private when aiCatalogInternalVisibility is disabled', async () => {
          createComponent({
            props: { aiCatalogItem: restrictedFlow },
          });
          await waitForPromises();

          expect(findInitialValues().visibility).toBe(VISIBILITY_LEVEL_PRIVATE);
        });
      });
    });

    describe('Form Submit', () => {
      const { name, description, project, latestVersion } = mockFlow;
      const formValues = {
        name: `${name} 2`,
        description,
        projectId: project.id,
        public: true,
        definition: latestVersion.definition,
        visibility: VISIBILITY_LEVEL_PUBLIC,
      };

      const submitForm = () => findFlowForm().vm.$emit('submit', formValues);

      beforeEach(async () => {
        createComponent({ props: { aiCatalogItem: mockFlow } });
        await waitForPromises();
      });

      it('sends a create request', () => {
        submitForm();

        expect(createAiCatalogFlowMock).toHaveBeenCalledTimes(1);
        expect(createAiCatalogFlowMock).toHaveBeenCalledWith({ input: formValues });
      });

      it('sets a loading state on the form while submitting', async () => {
        expect(findFlowForm().props('isLoading')).toBe(false);

        await submitForm();

        expect(findFlowForm().props('isLoading')).toBe(true);
      });

      describe('when request succeeds', () => {
        beforeEach(async () => {
          submitForm();
          await waitForPromises();
        });

        it('shows toast', () => {
          expect(mockToast.show).toHaveBeenCalledWith('Flow created.');
        });

        it('navigates to flows show page', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({
            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
            params: { id: 4 },
          });
        });
      });

      describe('when request fails', () => {
        beforeEach(async () => {
          createAiCatalogFlowMock.mockRejectedValue(new Error());
          submitForm();
          await waitForPromises();
        });

        it('sets error messages and captures exception', () => {
          expect(findFlowForm().props('errors')).toEqual([
            'Could not create flow in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
          ]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
          expect(findFlowForm().props('isLoading')).toBe(false);
        });

        it('allows user to dismiss errors', async () => {
          await findFlowForm().vm.$emit('dismiss-errors');

          expect(findFlowForm().props('errors')).toEqual([]);
        });
      });

      describe('when request succeeds but returns error', () => {
        beforeEach(async () => {
          createAiCatalogFlowMock.mockResolvedValue(mockCreateAiCatalogFlowErrorMutation);
          submitForm();
          await waitForPromises();
        });

        it('shows an alert', () => {
          expect(findFlowForm().props('errors')).toEqual([
            mockCreateAiCatalogFlowErrorMutation.data.aiCatalogFlowCreate.errors[0],
          ]);
          expect(findFlowForm().props('isLoading')).toBe(false);
        });
      });
    });

    describe('created hook - redirect behavior', () => {
      it.each([
        {
          name: 'redirects in non-global area without admin permissions',
          isGlobalNamespace: false,
          adminAiCatalogItem: false,
          shouldRedirect: true,
        },
        {
          name: 'does not redirect in non-global area with admin permissions',
          isGlobalNamespace: false,
          adminAiCatalogItem: true,
          shouldRedirect: false,
        },
        {
          name: 'does not redirect in global area without admin permissions',
          isGlobalNamespace: true,
          adminAiCatalogItem: false,
          shouldRedirect: false,
        },
        {
          name: 'does not redirect in global area with admin permissions',
          isGlobalNamespace: true,
          adminAiCatalogItem: true,
          shouldRedirect: false,
        },
      ])('$name', ({ isGlobalNamespace, adminAiCatalogItem, shouldRedirect }) => {
        const item = { ...mockFlow, userPermissions: { adminAiCatalogItem } };

        createComponent({
          props: { aiCatalogItem: item },
          provide: { isGlobalNamespace },
        });

        if (shouldRedirect) {
          expect(mockRouter.push).toHaveBeenCalledWith({
            name: AI_CATALOG_FLOWS_SHOW_ROUTE,
            params: { id: itemId },
          });
        } else {
          expect(mockRouter.push).not.toHaveBeenCalled();
        }
      });
    });
  });
});
