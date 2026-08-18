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
import AiCatalogItemNew from 'ee/ai/catalog/pages/ai_catalog_item_new.vue';
import AiCatalogAgentForm from 'ee/ai/catalog/components/ai_catalog_agent_form.vue';
import AiCatalogFlowForm from 'ee/ai/catalog/components/ai_catalog_flow_form.vue';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  VISIBILITY_LEVEL_RESTRICTED,
} from 'ee/ai/catalog/constants';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
} from 'ee/ai/catalog/router/constants';
import {
  mockAgent,
  mockFlow,
  mockCreateAiCatalogAgentSuccessMutation,
  mockCreateAiCatalogAgentErrorMutation,
  mockCreateAiCatalogFlowSuccessMutation,
  mockCreateAiCatalogFlowErrorMutation,
  mockCreateAiCatalogThirdPartyFlowSuccessMutation,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/sentry/sentry_browser_wrapper');

describe('AiCatalogItemNew', () => {
  let wrapper;
  let createAiCatalogAgentMock;
  let createAiCatalogFlowMock;
  let createAiCatalogThirdPartyFlowMock;

  const mockToast = { show: jest.fn() };
  const mockRouter = { push: jest.fn() };

  const defaultProvide = {
    isGlobalNamespace: false,
    glAbilities: { adminAiCatalogItem: true },
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

    wrapper = shallowMountExtended(AiCatalogItemNew, {
      apolloProvider,
      propsData: {
        itemType: AI_CATALOG_TYPE_AGENT,
        ...props,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
      mocks: {
        $router: mockRouter,
        $toast: mockToast,
      },
    });
  };

  const findAgentForm = () => wrapper.findComponent(AiCatalogAgentForm);
  const findFlowForm = () => wrapper.findComponent(AiCatalogFlowForm);
  const findPageHeading = () => wrapper.findComponent(PageHeading);

  describe('when itemType is AGENT', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('Page Heading', () => {
      it('renders page heading with correct title and description', () => {
        expect(findPageHeading().props('heading')).toBe('New agent');
        expect(findPageHeading().text()).toContain(
          'Use agents with GitLab Duo Chat to complete tasks and answer complex questions.',
        );
      });
    });

    it('renders the agent form', () => {
      expect(findAgentForm().exists()).toBe(true);
    });

    describe('permission check', () => {
      it('redirects to agents list when user cannot create items', () => {
        createComponent({ provide: { glAbilities: { adminAiCatalogItem: false } } });

        expect(mockRouter.push).toHaveBeenCalledWith({ name: AI_CATALOG_AGENTS_ROUTE });
      });

      it('does not redirect when user is in global namespace', () => {
        mockRouter.push.mockClear();
        createComponent({ provide: { isGlobalNamespace: true, glAbilities: {} } });

        expect(mockRouter.push).not.toHaveBeenCalled();
      });
    });

    describe('Form Submit', () => {
      const { name, description, project } = mockAgent;
      const input = {
        name,
        description,
        projectId: project.id,
        systemPrompt: 'A new system prompt',
        userPrompt: 'A new user prompt',
        public: false,
      };

      const submitForm = () => findAgentForm().vm.$emit('submit', { itemType: 'AGENT', ...input });

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

      describe('when request fails with a known permission error', () => {
        beforeEach(async () => {
          const permissionError = new Error("You don't have permission to access this workflow.");
          createAiCatalogAgentMock.mockRejectedValue(permissionError);
          submitForm();
          await waitForPromises();
        });

        it('sets error messages but does not capture exception in Sentry', () => {
          expect(findAgentForm().props('errors')).toEqual([
            'Could not create agent in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
          ]);
          expect(Sentry.captureException).not.toHaveBeenCalled();
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

      describe('when item type is THIRD_PARTY_FLOW', () => {
        const inputThirdPartyFlow = {
          name,
          description,
          projectId: project.id,
          public: true,
          definition: 'image:node@22',
        };

        const submitThirdPartyFlowForm = () =>
          findAgentForm().vm.$emit('submit', {
            itemType: 'THIRD_PARTY_FLOW',
            ...inputThirdPartyFlow,
          });

        it('sends a create request for third-party flow', () => {
          submitThirdPartyFlowForm();

          expect(createAiCatalogAgentMock).not.toHaveBeenCalled();
          expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledTimes(1);
          expect(createAiCatalogThirdPartyFlowMock).toHaveBeenCalledWith({
            input: inputThirdPartyFlow,
          });
        });
      });

      describe('when aiCatalogInternalVisibility is true', () => {
        const inputWithVisibility = {
          name,
          description,
          projectId: project.id,
          systemPrompt: 'A new system prompt',
          userPrompt: 'A new user prompt',
          visibility: VISIBILITY_LEVEL_RESTRICTED,
        };

        const submitFormWithVisibility = () =>
          findAgentForm().vm.$emit('submit', { itemType: 'AGENT', ...inputWithVisibility });

        beforeEach(() => {
          createComponent({ provide: { glFeatures: { aiCatalogInternalVisibility: true } } });
        });

        it('forwards the visibility level to the create request', () => {
          submitFormWithVisibility();

          expect(createAiCatalogAgentMock).toHaveBeenCalledTimes(1);
          expect(createAiCatalogAgentMock).toHaveBeenCalledWith({ input: inputWithVisibility });
        });
      });
    });
  });

  describe('when itemType is FLOW', () => {
    beforeEach(() => {
      createComponent({ props: { itemType: AI_CATALOG_TYPE_FLOW } });
    });

    describe('Page Heading', () => {
      it('renders page heading with correct title and description', () => {
        expect(findPageHeading().props('heading')).toBe('New flow');
        expect(findPageHeading().text()).toContain(
          'Use flows to automate complex, multi-step tasks.',
        );
      });
    });

    it('renders the flow form', () => {
      expect(findFlowForm().exists()).toBe(true);
    });

    describe('permission check', () => {
      it('redirects to flows list when user cannot create items', () => {
        createComponent({
          props: { itemType: AI_CATALOG_TYPE_FLOW },
          provide: { glAbilities: { adminAiCatalogItem: false } },
        });

        expect(mockRouter.push).toHaveBeenCalledWith({ name: AI_CATALOG_FLOWS_ROUTE });
      });
    });

    describe('Form Submit', () => {
      const { name, description, project, latestVersion } = mockFlow;
      const formValues = {
        name,
        description,
        projectId: project.id,
        public: true,
        definition: latestVersion.definition,
      };

      const submitForm = () => findFlowForm().vm.$emit('submit', formValues);

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

      describe('when request fails with a known permission error', () => {
        beforeEach(async () => {
          const permissionError = new Error(
            "The resource that you are attempting to access does not exist or you don't have permission to perform this action",
          );
          createAiCatalogFlowMock.mockRejectedValue(permissionError);
          submitForm();
          await waitForPromises();
        });

        it('sets error messages but does not capture exception in Sentry', () => {
          expect(findFlowForm().props('errors')).toEqual([
            'Could not create flow in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
          ]);
          expect(Sentry.captureException).not.toHaveBeenCalled();
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

      describe('when aiCatalogInternalVisibility is true', () => {
        const formValuesWithVisibility = {
          name,
          description,
          projectId: project.id,
          visibility: VISIBILITY_LEVEL_RESTRICTED,
          definition: latestVersion.definition,
        };

        const submitFormWithVisibility = () =>
          findFlowForm().vm.$emit('submit', formValuesWithVisibility);

        beforeEach(() => {
          createComponent({
            props: { itemType: AI_CATALOG_TYPE_FLOW },
            provide: { glFeatures: { aiCatalogInternalVisibility: true } },
          });
        });

        it('forwards the visibility level to the create request', () => {
          submitFormWithVisibility();

          expect(createAiCatalogFlowMock).toHaveBeenCalledTimes(1);
          expect(createAiCatalogFlowMock).toHaveBeenCalledWith({ input: formValuesWithVisibility });
        });
      });
    });
  });
});
