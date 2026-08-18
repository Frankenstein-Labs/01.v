import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_ITEM } from 'ee/graphql_shared/constants';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import AiCatalogItemEdit from 'ee/ai/catalog/pages/ai_catalog_item_edit.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import updateAiCatalogAgent from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_agent.mutation.graphql';
import updateAiCatalogFlow from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import updateAiCatalogThirdPartyFlow from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_third_party_flow.mutation.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import {
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
} from 'ee/ai/catalog/router/constants';
import { VISIBILITY_LEVEL_PUBLIC } from 'ee/ai/catalog/constants';
import {
  mockAgent,
  mockFlow,
  mockVersionProp,
  mockAgentConfigurationForProject,
  mockFlowConfigurationForProject,
  mockUpdateAiCatalogAgentSuccessMutation,
  mockUpdateAiCatalogAgentNoChangeMutation,
  mockUpdateAiCatalogAgentMetadataOnlyMutation,
  mockUpdateAiCatalogAgentErrorMutation,
  mockUpdateAiCatalogFlowSuccessMutation,
  mockUpdateAiCatalogFlowNoChangeMutation,
  mockUpdateAiCatalogFlowMetadataOnlyMutation,
  mockUpdateAiCatalogFlowErrorMutation,
  mockUpdateAiCatalogThirdPartyFlowSuccessMutation,
  mockThirdPartyFlow,
  mockAiCatalogAgentResponse,
  mockAiCatalogFlowResponse,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

const AGENT_CASE = {
  label: 'agent',
  item: mockAgent,
  itemWithConfig: {
    ...mockAgent,
    configurationForProject: mockAgentConfigurationForProject,
  },
  formComponent: AiCatalogAgentForm,
  showRoute: AI_CATALOG_AGENTS_SHOW_ROUTE,
  duplicateRoute: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  headingText: 'Edit agent',
  descriptionText: 'Manage agent settings.',
  updatedToast: 'Agent updated.',
  errorText: 'Could not update agent. Try again.',
  versionWarningContains: ['latest version of this agent', 'duplicate the agent'],
  routeId: 1,
  successMutation: mockUpdateAiCatalogAgentSuccessMutation,
  noChangeMutation: mockUpdateAiCatalogAgentNoChangeMutation,
  metadataOnlyMutation: mockUpdateAiCatalogAgentMetadataOnlyMutation,
  errorMutation: mockUpdateAiCatalogAgentErrorMutation,
  expectedInitialValues: {
    name: mockAgent.name,
    description: mockAgent.description,
    projectId: 'gid://gitlab/Project/1',
    systemPrompt: mockAgent.latestVersion.systemPrompt,
    tools: [],
    mcpTools: [],
    mcpServers: [],
    definition: '',
    itemType: 'AGENT',
    public: true,
    visibility: VISIBILITY_LEVEL_PUBLIC,
  },
  submitValues: {
    name: mockAgent.name,
    description: mockAgent.description,
    systemPrompt: mockAgent.systemPrompt,
    userPrompt: mockAgent.userPrompt,
    public: mockAgent.public,
    itemType: mockAgent.itemType,
  },
  expectedMutationInput: {
    name: mockAgent.name,
    description: mockAgent.description,
    systemPrompt: mockAgent.systemPrompt,
    userPrompt: mockAgent.userPrompt,
    public: mockAgent.public,
    id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, 1),
  },
};

const FLOW_CASE = {
  label: 'flow',
  item: mockFlow,
  itemWithConfig: {
    ...mockFlow,
    configurationForProject: {
      ...mockFlowConfigurationForProject,
      pinnedItemVersion: {
        ...mockFlowConfigurationForProject.pinnedItemVersion,
        definition: 'this is not expected',
      },
    },
  },
  formComponent: AiCatalogFlowForm,
  showRoute: AI_CATALOG_FLOWS_SHOW_ROUTE,
  duplicateRoute: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
  headingText: 'Edit flow',
  descriptionText: 'Manage flow settings.',
  updatedToast: 'Flow updated.',
  errorText: 'Could not update flow. Try again.',
  versionWarningContains: ['latest version of this flow', 'duplicate the flow'],
  routeId: 4,
  successMutation: mockUpdateAiCatalogFlowSuccessMutation,
  noChangeMutation: mockUpdateAiCatalogFlowNoChangeMutation,
  metadataOnlyMutation: mockUpdateAiCatalogFlowMetadataOnlyMutation,
  errorMutation: mockUpdateAiCatalogFlowErrorMutation,
  expectedInitialValues: {
    name: mockFlow.name,
    description: mockFlow.description,
    projectId: 'gid://gitlab/Project/1',
    definition: mockFlow.latestVersion.definition,
    public: true,
    visibility: VISIBILITY_LEVEL_PUBLIC,
  },
  submitValues: {
    name: mockFlow.name,
    description: mockFlow.description,
    public: true,
    definition: mockFlow.latestVersion.definition,
    visibility: VISIBILITY_LEVEL_PUBLIC,
  },
  expectedMutationInput: {
    name: mockFlow.name,
    description: mockFlow.description,
    public: true,
    definition: mockFlow.latestVersion.definition,
    id: mockFlow.id,
    visibility: VISIBILITY_LEVEL_PUBLIC,
  },
};

describe('AiCatalogItemEdit', () => {
  let wrapper;
  let mockApollo;

  const mockToast = { show: jest.fn() };
  const mockRouter = { push: jest.fn() };

  const mockUpdateAiCatalogAgentHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogAgentSuccessMutation);

  const mockUpdateAiCatalogFlowHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogFlowSuccessMutation);

  const mockUpdateAiCatalogThirdPartyFlowHandler = jest
    .fn()
    .mockResolvedValue(mockUpdateAiCatalogThirdPartyFlowSuccessMutation);

  const mockAiCatalogAgentQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);

  const mockAiCatalogFlowQueryHandler = jest.fn().mockResolvedValue(mockAiCatalogFlowResponse);

  const createComponent = ({ item, version = mockVersionProp, routeId } = {}) => {
    mockApollo = createMockApollo([
      [updateAiCatalogAgent, mockUpdateAiCatalogAgentHandler],
      [updateAiCatalogFlow, mockUpdateAiCatalogFlowHandler],
      [updateAiCatalogThirdPartyFlow, mockUpdateAiCatalogThirdPartyFlowHandler],
      [aiCatalogAgentQuery, mockAiCatalogAgentQueryHandler],
      [aiCatalogFlowQuery, mockAiCatalogFlowQueryHandler],
    ]);

    // Subscribe so that the mutation's refetchQueries has an active observer to refetch.
    mockApollo.defaultClient.watchQuery({ query: aiCatalogAgentQuery }).subscribe();
    mockApollo.defaultClient.watchQuery({ query: aiCatalogFlowQuery }).subscribe();

    wrapper = shallowMountExtended(AiCatalogItemEdit, {
      apolloProvider: mockApollo,
      propsData: {
        aiCatalogItem: item,
        version,
      },
      mocks: {
        $route: { params: { id: routeId } },
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findEditingLatestVersionWarning = () => wrapper.findComponent(GlAlert);
  const findEditVersionWarningText = () =>
    findEditingLatestVersionWarning().findComponent(GlSprintf).attributes('message');

  afterEach(() => {
    mockUpdateAiCatalogAgentHandler.mockReset();
    mockUpdateAiCatalogAgentHandler.mockResolvedValue(mockUpdateAiCatalogAgentSuccessMutation);
    mockUpdateAiCatalogFlowHandler.mockReset();
    mockUpdateAiCatalogFlowHandler.mockResolvedValue(mockUpdateAiCatalogFlowSuccessMutation);
    mockAiCatalogAgentQueryHandler.mockClear();
    mockAiCatalogFlowQueryHandler.mockClear();
  });

  describe.each([AGENT_CASE, FLOW_CASE])('$label', (testCase) => {
    const getMutationHandler = () =>
      testCase.label === 'agent' ? mockUpdateAiCatalogAgentHandler : mockUpdateAiCatalogFlowHandler;

    const getQueryHandler = () =>
      testCase.label === 'agent' ? mockAiCatalogAgentQueryHandler : mockAiCatalogFlowQueryHandler;

    const mount = (overrides = {}) =>
      createComponent({ item: testCase.item, routeId: testCase.routeId, ...overrides });

    const findForm = () => wrapper.findComponent(testCase.formComponent);

    describe('Page Heading', () => {
      beforeEach(() => {
        mount();
      });

      it('renders page heading with correct title and description', () => {
        expect(findPageHeading().props('heading')).toBe(testCase.headingText);
        expect(findPageHeading().text()).toContain(testCase.descriptionText);
      });
    });

    describe('Initial Rendering', () => {
      it('renders edit form', () => {
        mount();
        expect(findForm().exists()).toBe(true);
      });

      it('renders correct initial values', async () => {
        mount({ item: testCase.itemWithConfig });
        await waitForPromises();

        expect(findForm().props('initialValues')).toEqual(testCase.expectedInitialValues);
      });
    });

    describe('version update availability behaviour', () => {
      it('shows warning when version update is available', async () => {
        mount({ version: { isUpdateAvailable: true } });
        await waitForPromises();

        expect(findEditingLatestVersionWarning().exists()).toBe(true);
        const warningText = findEditVersionWarningText();
        testCase.versionWarningContains.forEach((text) => {
          expect(warningText).toContain(text);
        });
      });

      it('does not show warning when item is at the latest version already', async () => {
        mount({ version: { isUpdateAvailable: false } });
        await waitForPromises();

        expect(findEditingLatestVersionWarning().exists()).toBe(false);
      });

      it('hides the warning while submitting', async () => {
        mount({ version: { isUpdateAvailable: true } });
        await waitForPromises();
        expect(findEditingLatestVersionWarning().exists()).toBe(true);

        await findForm().vm.$emit('submit', testCase.submitValues);

        expect(findEditingLatestVersionWarning().exists()).toBe(false);
      });
    });

    describe('Form Submit', () => {
      const submitForm = () => findForm().vm.$emit('submit', testCase.submitValues);

      beforeEach(() => {
        mount();
      });

      it('sends an update request', async () => {
        await findForm().vm.$emit('submit', testCase.submitValues);
        await waitForPromises();

        expect(getMutationHandler()).toHaveBeenCalledTimes(1);
        expect(getMutationHandler()).toHaveBeenCalledWith({
          input: testCase.expectedMutationInput,
        });
      });

      it('refetches the item query on successful update to prevent stale data', async () => {
        getQueryHandler().mockClear(); // ignore the initial watchQuery fetch from setup
        submitForm();
        await waitForPromises();

        expect(getQueryHandler()).toHaveBeenCalledTimes(1);
      });

      it('sets a loading state on the form while submitting', async () => {
        expect(findForm().props('isLoading')).toBe(false);

        await submitForm();
        expect(findForm().props('isLoading')).toBe(true);
      });

      describe('when request succeeds with version change', () => {
        it('shows toast when version was updated', async () => {
          submitForm();
          await waitForPromises();

          expect(mockToast.show).toHaveBeenCalledWith(testCase.updatedToast);
        });
      });

      describe('when request succeeds with metadata change only', () => {
        it('shows toast when metadata was updated', async () => {
          getMutationHandler().mockResolvedValue(testCase.metadataOnlyMutation);
          submitForm();
          await waitForPromises();

          expect(mockToast.show).toHaveBeenCalledWith(testCase.updatedToast);
        });
      });

      describe('when request succeeds without any change', () => {
        beforeEach(async () => {
          getMutationHandler().mockResolvedValue(testCase.noChangeMutation);
          submitForm();
          await waitForPromises();
        });

        it('does not show toast when nothing was updated', () => {
          expect(mockToast.show).not.toHaveBeenCalled();
        });

        it('navigates to show page', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({
            name: testCase.showRoute,
            params: { id: testCase.routeId },
          });
        });
      });

      describe('when request fails', () => {
        beforeEach(async () => {
          getMutationHandler().mockRejectedValue(new Error());
          submitForm();
          await waitForPromises();
        });

        it('sets error messages and captures exception', () => {
          expect(findForm().props('errors')).toEqual([testCase.errorText]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
          expect(findForm().props('isLoading')).toBe(false);
        });

        it('allows user to dismiss errors', async () => {
          await findForm().vm.$emit('dismiss-errors');

          expect(findForm().props('errors')).toEqual([]);
        });
      });

      describe('when request succeeds but returns error', () => {
        it('shows an alert', async () => {
          getMutationHandler().mockResolvedValue(testCase.errorMutation);
          submitForm();
          await waitForPromises();

          const errorKey =
            testCase.label === 'agent' ? 'aiCatalogAgentUpdate' : 'aiCatalogFlowUpdate';
          expect(findForm().props('errors')).toEqual([
            testCase.errorMutation.data[errorKey].errors[0],
          ]);
          expect(findForm().props('isLoading')).toBe(false);
        });
      });
    });

    describe('created hook - redirect behavior', () => {
      it('redirects when adminAiCatalogItem is false', () => {
        mount({
          item: { ...testCase.item, userPermissions: { adminAiCatalogItem: false } },
        });

        expect(mockRouter.push).toHaveBeenCalledWith({
          name: testCase.showRoute,
          params: { id: testCase.routeId },
        });
      });

      it('does not redirect when adminAiCatalogItem is true', () => {
        mount({
          item: { ...testCase.item, userPermissions: { adminAiCatalogItem: true } },
        });

        expect(mockRouter.push).not.toHaveBeenCalled();
      });
    });
  });

  describe('when form submits as THIRD_PARTY_FLOW', () => {
    const findAgentForm = () => wrapper.findComponent(AiCatalogAgentForm);

    const thirdPartyFlowInput = {
      name: mockThirdPartyFlow.name,
      description: mockThirdPartyFlow.description,
      public: true,
      definition: mockThirdPartyFlow.latestVersion.definition,
      visibility: VISIBILITY_LEVEL_PUBLIC,
    };

    const submitThirdPartyFlow = () =>
      findAgentForm().vm.$emit('submit', {
        itemType: 'THIRD_PARTY_FLOW',
        ...thirdPartyFlowInput,
      });

    beforeEach(() => {
      createComponent({ item: mockThirdPartyFlow, routeId: 4 });
    });

    it('uses the third-party flow update mutation', async () => {
      submitThirdPartyFlow();
      await waitForPromises();

      expect(mockUpdateAiCatalogFlowHandler).not.toHaveBeenCalled();
      expect(mockUpdateAiCatalogThirdPartyFlowHandler).toHaveBeenCalledTimes(1);
      expect(mockUpdateAiCatalogThirdPartyFlowHandler).toHaveBeenCalledWith({
        input: { ...thirdPartyFlowInput, id: mockThirdPartyFlow.id },
      });
    });
  });
});
