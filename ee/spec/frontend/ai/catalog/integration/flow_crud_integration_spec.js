import { nextTick, reactive } from 'vue';
import { GlModal } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import getAvailableProjects from 'ee/ai/catalog/graphql/queries/ai_catalog_available_projects.query.graphql';
import AiCatalogItemNew from 'ee/ai/catalog/pages/ai_catalog_item_new.vue';
import AiCatalogItemEdit from 'ee/ai/catalog/pages/ai_catalog_item_edit.vue';
import AiCatalogItemDuplicate from 'ee/ai/catalog/pages/ai_catalog_item_duplicate.vue';
import AiCatalogItemShow from 'ee/ai/catalog/pages/ai_catalog_item_show.vue';
import { VERSION_LATEST, VERSION_PINNED, AI_CATALOG_TYPE_FLOW } from 'ee/ai/catalog/constants';
import createAiCatalogFlowMutation from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_flow.mutation.graphql';
import updateAiCatalogFlowMutation from 'ee/ai/catalog/graphql/mutations/update_ai_catalog_flow.mutation.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import createAiCatalogItemConsumerBulk from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer_bulk.mutation.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import deleteAiCatalogFlowMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import reportAiCatalogItem from 'ee/ai/catalog/graphql/mutations/report_ai_catalog_item.mutation.graphql';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import AiCatalogItemConsumerModal from 'ee/ai/catalog/components/ai_catalog_item_consumer_modal.vue';
import AiCatalogItemReportModal from 'ee/ai/catalog/components/ai_catalog_item_report_modal.vue';

import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import {
  mockFlow,
  mockFlowVersion,
  mockFlowConfigurationForProject,
  mockAiCatalogFlowResponse,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateBulkSuccessProjectResponse,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAvailableProjectsResponse,
  mockCatalogFlowDeleteResponse,
  mockReportAiCatalogItemSuccessMutation,
  mockVersionProp,
  mockCreateAiCatalogFlowSuccessMutation,
  mockUpdateAiCatalogFlowSuccessMutation,
  mockUpdateAiCatalogFlowNoChangeMutation,
} from '../mock_data';
import {
  createIntegrationWrapper,
  createMockRouter,
  EXPLORE_PROVIDE,
  PROJECT_PROVIDE,
  ROUTE_PRESETS,
  SourceEditorStub,
  openActionsDropdown,
  clickEnableButton,
} from './helpers';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  // isLoggedIn() evaluates Boolean(window.gon?.current_user_id), which is undefined in jsdom
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

const { name, description, project, latestVersion } = mockFlow;
const mockFormValues = {
  name,
  description,
  projectId: project.id,
  public: true,
  definition: latestVersion.definition,
};

const submitFlowForm = async (wrapper, formValues) => {
  await wrapper.findByLabelText('Display name').setValue(formValues.name);
  await wrapper.findByLabelText('Description').setValue(formValues.description);
  await wrapper
    .findByTestId('flow-form-definition')
    .find('textarea')
    .setValue(formValues.definition);
  return wrapper.find('form').trigger('submit');
};

describe('Flow new page', () => {
  const mountFlowNew = (mutationHandler) =>
    createIntegrationWrapper(AiCatalogItemNew, {
      provide: {
        ...PROJECT_PROVIDE,
        glAbilities: { adminAiCatalogItem: true },
      },
      props: {
        itemType: AI_CATALOG_TYPE_FLOW,
      },
      apolloHandlers: [[createAiCatalogFlowMutation, mutationHandler]],
      route: ROUTE_PRESETS.flowNew,
      stubs: { SourceEditor: SourceEditorStub },
    });

  describe('In a project, a user with adminAiCatalogItem permissions can', () => {
    it('create a flow and be redirected to the show page', async () => {
      const handler = jest.fn().mockResolvedValue(mockCreateAiCatalogFlowSuccessMutation);
      const { wrapper, router, toast } = mountFlowNew(handler);

      await submitFlowForm(wrapper, mockFormValues);
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith({
        input: {
          name,
          description,
          projectId: project.id,
          public: false,
          definition: latestVersion.definition,
        },
      });
      expect(toast.show).toHaveBeenCalledWith('Flow created.');
      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowShow.name);
      expect(String(router.currentRoute.params.id)).toBe(String(getIdFromGraphQLId(mockFlow.id)));
    });
  });
});

describe('Flow edit page', () => {
  const mountFlowEdit = ({
    flow = mockFlow,
    version = mockVersionProp,
    mutationHandler = jest.fn().mockResolvedValue(mockUpdateAiCatalogFlowSuccessMutation),
    router,
  } = {}) => {
    const result = createIntegrationWrapper(AiCatalogItemEdit, {
      provide: {
        ...PROJECT_PROVIDE,
        glAbilities: { adminAiCatalogItem: true },
      },
      props: {
        aiCatalogItem: flow,
        version,
      },
      apolloHandlers: [
        [updateAiCatalogFlowMutation, mutationHandler],
        [aiCatalogFlowQuery, jest.fn().mockResolvedValue(mockAiCatalogFlowResponse)],
      ],
      route: ROUTE_PRESETS.flowEdit,
      stubs: { SourceEditor: SourceEditorStub },
      router,
    });
    // Subscribe so that the edit mutation's refetchQueries has an active observer to refetch.
    result.apolloProvider.defaultClient.watchQuery({ query: aiCatalogFlowQuery }).subscribe();
    return result;
  };

  describe('In a project, a user with adminAiCatalogItem permissions can', () => {
    it('navigate to the edit page without being redirected', async () => {
      const { router } = mountFlowEdit();
      await waitForPromises();

      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowEdit.name);
    });

    it('see the form pre-populated with current flow values', () => {
      const { wrapper } = mountFlowEdit();

      expect(wrapper.findByLabelText('Display name').element.value).toBe(mockFlow.name);
      expect(wrapper.findByLabelText('Description').element.value).toBe(mockFlow.description);
      expect(wrapper.findByTestId('flow-form-definition').find('textarea').element.value).toBe(
        mockFlowVersion.definition,
      );
    });

    it('save changes to the flow and be redirected to the show page', async () => {
      const handler = jest.fn().mockResolvedValue(mockUpdateAiCatalogFlowSuccessMutation);
      const { wrapper, router, toast } = mountFlowEdit({ mutationHandler: handler });

      // In Vue Router 4 (Vue 3) router.push() is async
      // Await promises so $route.params.id is populated before handleSubmit reads it
      await waitForPromises(); // initial router navigation
      await submitFlowForm(wrapper, mockFormValues);
      await waitForPromises(); // mutation + redirect

      expect(handler).toHaveBeenCalledWith({
        input: { id: mockFlow.id, ...mockFormValues, projectId: undefined },
      });
      expect(toast.show).toHaveBeenCalledWith('Flow updated.');
      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowShow.name);
      expect(router.currentRoute.params.id).toBe(ROUTE_PRESETS.flowEdit.params.id);
    });

    it('be redirected to the show page when there are no changes to save', async () => {
      const handler = jest.fn().mockResolvedValue(mockUpdateAiCatalogFlowNoChangeMutation);
      const { wrapper, router, toast } = mountFlowEdit({ mutationHandler: handler });

      await waitForPromises(); // initial router navigation
      await submitFlowForm(wrapper, mockFormValues);
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith({
        input: { id: mockFlow.id, ...mockFormValues, projectId: undefined },
      });
      expect(toast.show).not.toHaveBeenCalled();
      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowShow.name);
    });
  });

  describe('In a project, a user without edit permission', () => {
    it('is redirected to the show page', async () => {
      // Pre-navigate before mounting so $route.params.id is set when created() runs
      // Vue Router 4 (Vue 3) navigation is async; awaiting ensures params are populated at mount time
      const router = createMockRouter(ROUTE_PRESETS.flowEdit);
      await waitForPromises();

      mountFlowEdit({
        flow: { ...mockFlow, userPermissions: { adminAiCatalogItem: false } },
        router,
      });
      await waitForPromises();

      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowShow.name);
    });
  });
});

describe('Flow duplicate page', () => {
  const mockDuplicateFormValues = {
    name: `Copy of ${mockFlow.name}`,
    public: false,
    description: mockFlow.description,
    definition: mockFlowVersion.definition,
    projectId: project.id,
  };

  const mountFlowDuplicate = ({
    flow = mockFlow,
    mutationHandler = jest.fn().mockResolvedValue(mockCreateAiCatalogFlowSuccessMutation),
    router,
  } = {}) =>
    createIntegrationWrapper(AiCatalogItemDuplicate, {
      provide: {
        ...PROJECT_PROVIDE,
        glAbilities: { adminAiCatalogItem: true },
      },
      props: {
        aiCatalogItem: flow,
      },
      apolloHandlers: [[createAiCatalogFlowMutation, mutationHandler]],
      route: ROUTE_PRESETS.flowDuplicate,
      stubs: { SourceEditor: SourceEditorStub },
      router,
    });

  describe('In a project, a user with adminAiCatalogItem permissions can', () => {
    it('create a copy of the flow and be redirected to the new flow show page', async () => {
      const handler = jest.fn().mockResolvedValue(mockCreateAiCatalogFlowSuccessMutation);
      const { wrapper, router, toast } = mountFlowDuplicate({ mutationHandler: handler });

      await submitFlowForm(wrapper, mockDuplicateFormValues);
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith({ input: mockDuplicateFormValues });
      expect(toast.show).toHaveBeenCalledWith('Flow created.');
      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowShow.name);
      expect(String(router.currentRoute.params.id)).toBe(
        String(
          getIdFromGraphQLId(
            mockCreateAiCatalogFlowSuccessMutation.data.aiCatalogFlowCreate.item.id,
          ),
        ),
      );
    });

    it('navigate to the duplicate page without being redirected', async () => {
      const { router } = mountFlowDuplicate();
      await waitForPromises();

      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowDuplicate.name);
    });
  });

  describe('In a project, a user without duplicate permission', () => {
    it('is redirected to the show page', async () => {
      // Pre-navigate before mounting so $route.params.id is set when created() runs
      // Vue Router 4 (Vue 3) navigation is async; awaiting ensures params are populated at mount time
      const router = createMockRouter(ROUTE_PRESETS.flowDuplicate);
      await waitForPromises();

      mountFlowDuplicate({
        flow: { ...mockFlow, userPermissions: { adminAiCatalogItem: false } },
        router,
      });
      await waitForPromises();

      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowShow.name);
    });
  });
});

describe('Flow show page', () => {
  const mountFlowShow = ({
    flow = null,
    provide = PROJECT_PROVIDE,
    apolloHandlers = [],
    glAbilities = { adminAiCatalogItem: true },
  } = {}) => {
    const defaultFlow = flow ?? {
      ...mockFlow,
      configurationForProject: mockFlowConfigurationForProject,
    };
    const version = reactive({
      ...mockVersionProp,
      activeVersionKey: VERSION_PINNED,
      setActiveVersionKey(key) {
        version.activeVersionKey = key ?? VERSION_LATEST;
      },
    });

    const { wrapper, router, apolloProvider, toast } = createIntegrationWrapper(AiCatalogItemShow, {
      provide: {
        ...provide,
        glAbilities,
      },
      props: {
        aiCatalogItem: defaultFlow,
        version,
      },
      apolloHandlers: [...apolloHandlers],
      route: ROUTE_PRESETS.flowShow,
      stubs: {
        // GlModal renders via a portal into document.body, outside the wrapper's DOM tree
        // Stubbing it keeps modal content inline so wrapper.find() queries work correctly
        // The stub exposes `modalId` as the wrapper id and `.js-modal-action-primary` on the
        // confirm button so shared helpers (e.g. submitEnableModal) that target
        // `#<modalId> .js-modal-action-primary` work, while still emitting 'primary' so
        // ConfirmActionModal's actionFn can be triggered via a DOM click.
        GlModal: stubComponent(GlModal, {
          template:
            '<div><slot></slot><button @click="$emit(\'primary\', $event)">Confirm</button></div>',
        }),
      },
    });

    // Apollo only refetches queries that have active subscribers
    // Subscribe here so that refetchQueries in disableFlow() works on aiCatalogFlowQuery
    const hasFlowQueryHandler = apolloHandlers.some(([query]) => query === aiCatalogFlowQuery);
    if (hasFlowQueryHandler) {
      apolloProvider.defaultClient.watchQuery({ query: aiCatalogFlowQuery }).subscribe();
    }

    return { wrapper, router, version, toast };
  };

  const openEnableModalAndSelectProject = async (wrapper, optionName) => {
    await wrapper.findByRole('button', { name: 'Enable' }).trigger('click');
    await wrapper.findByRole('option', { name: optionName }).trigger('click');
  };
  const submitEnableModalForm = (wrapper) =>
    wrapper.findComponent(AiCatalogItemConsumerModal).find('form').trigger('submit');

  describe('In the Explore area, a logged-in user can', () => {
    let wrapper;
    let handler;
    let toast;

    beforeEach(async () => {
      handler = jest.fn().mockResolvedValue(mockAiCatalogItemConsumerCreateSuccessProjectResponse);

      ({ wrapper, toast } = mountFlowShow({
        provide: EXPLORE_PROVIDE,
        apolloHandlers: [
          [aiCatalogFlowQuery, jest.fn().mockResolvedValue(mockAiCatalogFlowResponse)],
          [createAiCatalogItemConsumer, handler],
          [getAvailableProjects, jest.fn().mockResolvedValue(mockAvailableProjectsResponse)],
        ],
      }));

      await waitForPromises();
      await openEnableModalAndSelectProject(wrapper, /Group \/ Project 1/);
      await submitEnableModalForm(wrapper);
      await waitForPromises();
    });

    it('enable the flow in a selected project and see a toast notification with a view link', () => {
      expect(handler).toHaveBeenCalledTimes(1);
      expect(handler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          itemId: mockFlow.id,
          target: { projectId: 'gid://gitlab/Project/1' },
        }),
      });
      expect(toast.show).toHaveBeenCalledWith(
        'Flow enabled in Test.',
        expect.objectContaining({ action: expect.objectContaining({ text: 'View' }) }),
      );
    });
  });

  describe('In the Explore area, when aiCatalogBulkItemConsumerCreate is enabled, a logged-in user can', () => {
    let wrapper;
    let handler;
    let toast;

    beforeEach(async () => {
      handler = jest
        .fn()
        .mockResolvedValue(mockAiCatalogItemConsumerCreateBulkSuccessProjectResponse);

      ({ wrapper, toast } = mountFlowShow({
        provide: { ...EXPLORE_PROVIDE, glFeatures: { aiCatalogBulkItemConsumerCreate: true } },
        apolloHandlers: [
          [aiCatalogFlowQuery, jest.fn().mockResolvedValue(mockAiCatalogFlowResponse)],
          [createAiCatalogItemConsumerBulk, handler],
          [getAvailableProjects, jest.fn().mockResolvedValue(mockAvailableProjectsResponse)],
        ],
      }));

      await waitForPromises();
      await wrapper.findByRole('button', { name: 'Enable' }).trigger('click');
      await waitForPromises();
      await wrapper.findByRole('checkbox', { name: /Project 1/ }).setChecked();
      await submitEnableModalForm(wrapper);
      await waitForPromises();
    });

    it('enable the flow in multiple selected projects and see a success toast', () => {
      expect(handler).toHaveBeenCalledTimes(1);
      expect(handler).toHaveBeenCalledWith({
        input: expect.objectContaining({
          itemId: mockFlow.id,
          projectIds: ['gid://gitlab/Project/1'],
        }),
      });
      expect(toast.show).toHaveBeenCalledWith('Enabled in selected project(s).');
    });
  });

  describe('In the Explore area, projects where the flow is already enabled', () => {
    it('are fetched via the filter query scoped to the current item', async () => {
      const consumerHandler = jest.fn();
      const availableProjectsHandler = jest.fn().mockResolvedValue(mockAvailableProjectsResponse);
      const { wrapper } = mountFlowShow({
        provide: EXPLORE_PROVIDE,
        apolloHandlers: [
          [aiCatalogFlowQuery, jest.fn().mockResolvedValue(mockAiCatalogFlowResponse)],
          [createAiCatalogItemConsumer, consumerHandler],
          [getAvailableProjects, availableProjectsHandler],
        ],
      });

      await waitForPromises();
      await wrapper.findByRole('button', { name: 'Enable' }).trigger('click');
      await waitForPromises();

      expect(availableProjectsHandler).toHaveBeenCalledWith(
        expect.objectContaining({ itemId: mockFlow.id }),
      );
      expect(consumerHandler).not.toHaveBeenCalled();
    });
  });

  describe('In a project, a maintainer can', () => {
    describe('enable the flow in the current project', () => {
      let wrapper;
      let handler;
      let toast;

      beforeEach(async () => {
        handler = jest
          .fn()
          .mockResolvedValue(mockAiCatalogItemConsumerCreateSuccessProjectResponse);

        ({ wrapper, toast } = mountFlowShow({
          flow: {
            ...mockFlow,
            configurationForProject: { ...mockFlowConfigurationForProject, enabled: false },
          },
          provide: PROJECT_PROVIDE,
          apolloHandlers: [
            [aiCatalogFlowQuery, jest.fn().mockResolvedValue(mockAiCatalogFlowResponse)],
            [createAiCatalogItemConsumer, handler],
          ],
          glAbilities: { adminAiCatalogItem: true, adminAiCatalogItemConsumer: true },
        }));

        await waitForPromises();
        await clickEnableButton(wrapper);
        await wrapper.findComponent(AiCatalogItemConsumerModal).find('form').trigger('submit');
        await waitForPromises();
      });

      it('enables the flow and shows a confirmation toast', () => {
        expect(handler).toHaveBeenCalledTimes(1);
        expect(handler).toHaveBeenCalledWith({
          input: expect.objectContaining({
            itemId: mockFlow.id,
            target: { projectId: 'gid://gitlab/Project/1' },
          }),
        });
        expect(toast.show).toHaveBeenCalledWith('Flow enabled in Test.');
      });
    });

    describe('disable the flow', () => {
      let wrapper;
      let handler;
      let toast;

      beforeEach(async () => {
        handler = jest.fn().mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);
        ({ wrapper, toast } = mountFlowShow({
          apolloHandlers: [
            [aiCatalogFlowQuery, jest.fn().mockResolvedValue(mockAiCatalogFlowResponse)],
            [deleteAiCatalogItemConsumer, handler],
          ],
          // showDisable requires canAdminConsumer
          glAbilities: { adminAiCatalogItemConsumer: true },
        }));
        await waitForPromises(); // let the permissions query resolve so the disable button renders
        await openActionsDropdown(wrapper);
        await wrapper.findByRole('button', { name: 'Disable' }).trigger('click');
        await nextTick();
        await wrapper.findByRole('button', { name: 'Confirm' }).trigger('click');
        await waitForPromises();
      });

      it('see a confirmation toast and the version reset to latest', () => {
        expect(handler).toHaveBeenCalledWith({ id: mockFlowConfigurationForProject.id });
        expect(toast.show).toHaveBeenCalledWith('Flow disabled in this project.');
        expect(wrapper.findByTestId('metadata-version').text()).toContain(
          mockFlowVersion.humanVersionName,
        );
      });
    });

    describe('hide the flow from the catalog', () => {
      let wrapper;
      let router;
      let handler;

      beforeEach(async () => {
        handler = jest.fn().mockResolvedValue(mockCatalogFlowDeleteResponse);
        ({ wrapper, router } = mountFlowShow({
          flow: {
            ...mockFlow,
            configurationForProject: mockFlowConfigurationForProject,
            userPermissions: mockFlow.userPermissions,
          },
          apolloHandlers: [[deleteAiCatalogFlowMutation, handler]],
          glAbilities: { forceHardDeleteAiCatalogItem: false },
        }));
        await openActionsDropdown(wrapper);
        await wrapper.findByRole('button', { name: 'Hide' }).trigger('click');
        await nextTick();
        await wrapper.findByRole('button', { name: 'Confirm' }).trigger('click');
        await waitForPromises();
      });

      it('hides the flow and redirects to the flows list', () => {
        expect(handler).toHaveBeenCalledWith({ id: mockFlow.id, forceHardDelete: false });
        expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowList.name);
      });
    });
  });

  describe('In a project, a user with the forceHardDeleteAiCatalogItem permission can either hide or permanently delete an item', () => {
    let wrapper;
    let router;
    let handler;

    beforeEach(async () => {
      handler = jest.fn().mockResolvedValue(mockCatalogFlowDeleteResponse);
      ({ wrapper, router } = mountFlowShow({
        flow: {
          ...mockFlow,
          configurationForProject: mockFlowConfigurationForProject,
          userPermissions: mockFlow.userPermissions,
        },
        apolloHandlers: [[deleteAiCatalogFlowMutation, handler]],
        glAbilities: { adminAiCatalogItem: true, forceHardDeleteAiCatalogItem: true },
      }));
      await openActionsDropdown(wrapper);
      await wrapper.findByRole('button', { name: 'Delete' }).trigger('click');
      await nextTick();
    });

    describe('when choosing "Delete permanently"', () => {
      beforeEach(async () => {
        await wrapper.findComponent(ConfirmActionModal).find('input[value="true"]').setChecked();
        await nextTick();
        await wrapper.findByRole('button', { name: 'Confirm' }).trigger('click');
        await waitForPromises();
      });

      it('permanently deletes the flow and redirects to the flows list', () => {
        expect(handler).toHaveBeenCalledWith({ id: mockFlow.id, forceHardDelete: true });
        expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowList.name);
      });
    });

    describe('when choosing "Hide from the AI Catalog"', () => {
      beforeEach(async () => {
        await wrapper.findComponent(ConfirmActionModal).find('input[value="false"]').setChecked();
        await nextTick();
        await wrapper.findByRole('button', { name: 'Confirm' }).trigger('click');
        await waitForPromises();
      });

      it('hides the flow and redirects to the flows list', () => {
        expect(handler).toHaveBeenCalledWith({ id: mockFlow.id, forceHardDelete: false });
        expect(router.currentRoute.name).toBe(ROUTE_PRESETS.flowList.name);
      });
    });
  });

  describe('In a project, a user can', () => {
    let wrapper;
    let handler;
    let toast;

    beforeEach(async () => {
      handler = jest.fn().mockResolvedValue(mockReportAiCatalogItemSuccessMutation);
      ({ wrapper, toast } = mountFlowShow({
        apolloHandlers: [[reportAiCatalogItem, handler]],
        glAbilities: { reportAiCatalogItem: true },
      }));

      await openActionsDropdown(wrapper);

      await wrapper
        .findComponent(AiCatalogItemReportModal)
        .find('input[value="SPAM_OR_LOW_QUALITY"]')
        .setChecked();
      await wrapper
        .findByLabelText('Additional information', { exact: false })
        .setValue('This flow is spam.');
      await wrapper.findComponent(AiCatalogItemReportModal).find('form').trigger('submit');
      await waitForPromises();
    });

    it('report the flow to the admin and see a success confirmation toast', () => {
      expect(handler).toHaveBeenCalledWith({
        input: { id: mockFlow.id, reason: 'SPAM_OR_LOW_QUALITY', body: 'This flow is spam.' },
      });
      expect(toast.show).toHaveBeenCalledWith('Report submitted successfully.');
    });
  });
});
