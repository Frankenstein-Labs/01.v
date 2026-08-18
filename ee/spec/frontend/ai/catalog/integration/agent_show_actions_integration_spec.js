import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogItemShow from 'ee/ai/catalog/pages/ai_catalog_item_show.vue';
import deleteAiCatalogAgentMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import createAiCatalogItemConsumerMutation from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import createAiCatalogItemConsumerBulkMutation from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer_bulk.mutation.graphql';
import deleteAiCatalogItemConsumerMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import reportAiCatalogItemMutation from 'ee/ai/catalog/graphql/mutations/report_ai_catalog_item.mutation.graphql';
import aiCatalogProjectsMaintainerQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_projects_maintainer.query.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import getAvailableProjects from 'ee/ai/catalog/graphql/queries/ai_catalog_available_projects.query.graphql';
import {
  mockVersionProp,
  mockCatalogAgentDeleteResponse,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateBulkSuccessProjectResponse,
  mockAiCatalogItemConsumerDeleteResponse,
  mockReportAiCatalogItemSuccessMutation,
  mockProjectsMaintainerResponse,
  mockAvailableProjectsResponse,
  mockAiCatalogAgentResponse,
} from '../mock_data';
import {
  createIntegrationWrapper,
  openActionsDropdown,
  expectActions,
  ACTION_STATE,
  clickDeleteAndConfirm,
  clickDisableAndConfirm,
  clickEnableButton,
  selectEnableModalDropdownItem,
  submitEnableModal,
  clickReportAndFillForm,
  EXPLORE_PROVIDE,
  PROJECT_PROVIDE,
  ROUTE_PRESETS,
} from './helpers';
import { createAgentWithPermissions } from './mock_data_factories';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

const agentRefetchHandler = () => jest.fn().mockResolvedValue(mockAiCatalogAgentResponse);

describe('Agent — show page actions integration', () => {
  const createPermissionHandlers = () => [
    [aiCatalogProjectsMaintainerQuery, jest.fn().mockResolvedValue(mockProjectsMaintainerResponse)],
  ];

  const mountShowPage = ({
    agent,
    provide = {},
    apolloHandlers = [],
    permissionOverrides = {},
  } = {}) => {
    const defaultAgent = agent || createAgentWithPermissions();
    const { wrapper, router, apolloProvider, toast } = createIntegrationWrapper(AiCatalogItemShow, {
      provide: {
        ...PROJECT_PROVIDE,
        ...provide,
        glAbilities: { ...provide.glAbilities, ...permissionOverrides },
      },
      props: {
        aiCatalogItem: defaultAgent,
        version: { ...mockVersionProp, setActiveVersionKey: jest.fn() },
      },
      apolloHandlers: [...createPermissionHandlers(), ...apolloHandlers],
      route: ROUTE_PRESETS.agentShow,
    });

    // Apollo only refetches queries that have active subscribers
    // Subscribe here so that refetchQueries in disableAgent() works on aiCatalogAgentQuery
    const hasAgentQueryHandler = apolloHandlers.some(([query]) => query === aiCatalogAgentQuery);
    if (hasAgentQueryHandler) {
      apolloProvider.defaultClient.watchQuery({ query: aiCatalogAgentQuery }).subscribe();
    }

    return { wrapper, router, toast };
  };

  describe('Delete', () => {
    it('as maintainer: clicking Hide and confirming hides the agent and redirects to list', async () => {
      const deleteHandler = jest.fn().mockResolvedValue(mockCatalogAgentDeleteResponse);
      const agent = createAgentWithPermissions();
      const { wrapper, router, toast } = mountShowPage({
        agent,
        apolloHandlers: [[deleteAiCatalogAgentMutation, deleteHandler]],
        permissionOverrides: { forceHardDeleteAiCatalogItem: false },
      });
      await waitForPromises();

      await openActionsDropdown(wrapper);
      expect(wrapper.findByTestId('delete-button').text()).toContain('Hide');

      await clickDeleteAndConfirm(wrapper);
      await waitForPromises();

      expect(deleteHandler).toHaveBeenCalledWith(
        expect.objectContaining({ id: agent.id, forceHardDelete: false }),
      );
      expect(toast.show).toHaveBeenCalledWith('Agent hidden.');
      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.agentList.name);
    });

    it('as admin: clicking Delete and confirming permanently deletes the agent and redirects to list', async () => {
      const deleteHandler = jest.fn().mockResolvedValue(mockCatalogAgentDeleteResponse);
      const agent = createAgentWithPermissions();
      const { wrapper, router, toast } = mountShowPage({
        agent,
        apolloHandlers: [[deleteAiCatalogAgentMutation, deleteHandler]],
        permissionOverrides: { forceHardDeleteAiCatalogItem: true },
      });
      await waitForPromises();

      await openActionsDropdown(wrapper);
      expect(wrapper.findByTestId('delete-button').text()).toContain('Delete');

      await clickDeleteAndConfirm(wrapper);
      await waitForPromises();

      expect(deleteHandler).toHaveBeenCalledWith(
        expect.objectContaining({ id: agent.id, forceHardDelete: true }),
      );
      expect(toast.show).toHaveBeenCalledWith('Agent deleted.');
      expect(router.currentRoute.name).toBe(ROUTE_PRESETS.agentList.name);
    });
  });

  describe('Enable', () => {
    it('enabling from the catalog selects a project and enables the agent', async () => {
      const consumerHandler = jest
        .fn()
        .mockResolvedValue(mockAiCatalogItemConsumerCreateSuccessProjectResponse);
      const agent = createAgentWithPermissions({ adminAiCatalogItem: false });
      const { wrapper, toast } = mountShowPage({
        agent,
        provide: EXPLORE_PROVIDE,
        apolloHandlers: [
          [createAiCatalogItemConsumerMutation, consumerHandler],
          [aiCatalogAgentQuery, agentRefetchHandler()],
          [getAvailableProjects, jest.fn().mockResolvedValue(mockAvailableProjectsResponse)],
        ],
      });
      await waitForPromises();

      await clickEnableButton(wrapper);
      await selectEnableModalDropdownItem('project-id', 'gid://gitlab/Project/1');
      await submitEnableModal();
      await waitForPromises();

      expect(consumerHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            itemId: agent.id,
            target: { projectId: 'gid://gitlab/Project/1' },
          }),
        }),
      );
      expect(toast.show).toHaveBeenCalledWith(
        expect.stringContaining('Agent enabled'),
        expect.any(Object),
      );
    });

    it('enabling from the catalog with aiCatalogBulkItemConsumerCreate selects multiple projects via bulk mutation', async () => {
      const consumerBulkHandler = jest
        .fn()
        .mockResolvedValue(mockAiCatalogItemConsumerCreateBulkSuccessProjectResponse);
      const agent = createAgentWithPermissions({ adminAiCatalogItem: false });
      const { wrapper, toast } = mountShowPage({
        agent,
        provide: {
          ...EXPLORE_PROVIDE,
          glFeatures: { aiCatalogBulkItemConsumerCreate: true },
        },
        apolloHandlers: [
          [createAiCatalogItemConsumerBulkMutation, consumerBulkHandler],
          [aiCatalogAgentQuery, agentRefetchHandler()],
          [getAvailableProjects, jest.fn().mockResolvedValue(mockAvailableProjectsResponse)],
        ],
      });
      await waitForPromises();

      await clickEnableButton(wrapper);
      await waitForPromises();
      const checkbox = document.querySelector('input[id="gid://gitlab/Project/1"]');
      checkbox.click();
      await waitForPromises();
      await submitEnableModal();
      await waitForPromises();

      expect(consumerBulkHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            itemId: agent.id,
            projectIds: ['gid://gitlab/Project/1'],
          }),
        }),
      );
      expect(toast.show).toHaveBeenCalledWith('Enabled in selected project(s).');
    });

    it('does not let the user select a project where the agent is already enabled', async () => {
      const consumerHandler = jest.fn();
      const agent = createAgentWithPermissions({ adminAiCatalogItem: false });
      const { wrapper } = mountShowPage({
        agent,
        provide: EXPLORE_PROVIDE,
        apolloHandlers: [
          [createAiCatalogItemConsumerMutation, consumerHandler],
          [aiCatalogAgentQuery, agentRefetchHandler()],
          [getAvailableProjects, jest.fn().mockResolvedValue(mockAvailableProjectsResponse)],
        ],
      });
      await waitForPromises();

      await clickEnableButton(wrapper);
      // Project 2 is already-enabled in `mockAvailableProjectsResponse`
      await selectEnableModalDropdownItem('project-id', 'gid://gitlab/Project/2');
      await submitEnableModal();
      await waitForPromises();

      expect(consumerHandler).not.toHaveBeenCalled();
    });

    it('enabling from a project adds the agent to that project', async () => {
      const consumerHandler = jest
        .fn()
        .mockResolvedValue(mockAiCatalogItemConsumerCreateSuccessProjectResponse);
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        projectConfigEnabled: false,
      });
      const { wrapper, toast } = mountShowPage({
        agent,
        apolloHandlers: [
          [createAiCatalogItemConsumerMutation, consumerHandler],
          [aiCatalogAgentQuery, agentRefetchHandler()],
        ],
        permissionOverrides: { adminAiCatalogItemConsumer: true },
      });
      await waitForPromises();

      await clickEnableButton(wrapper);
      await waitForPromises();
      await submitEnableModal();
      await waitForPromises();

      expect(consumerHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: expect.objectContaining({
            itemId: agent.id,
            target: { projectId: 'gid://gitlab/Project/1' },
          }),
        }),
      );
      expect(toast.show).toHaveBeenCalledWith(expect.stringContaining('Agent enabled'));
    });

    it('a private agent already enabled in a group can still be enabled in other projects', async () => {
      const agent = createAgentWithPermissions({
        adminAiCatalogItem: false,
        isPublic: false,
        groupConfigEnabled: true,
      });
      const { wrapper } = mountShowPage({ agent, provide: EXPLORE_PROVIDE });
      await waitForPromises();

      await expectActions(wrapper, {
        'enable-button': ACTION_STATE.VISIBLE,
      });
    });
  });

  describe('Disable', () => {
    it('disabling from a project removes the agent from that project', async () => {
      const disableHandler = jest.fn().mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);
      const agent = createAgentWithPermissions({ projectConfigEnabled: true });
      const { wrapper, toast } = mountShowPage({
        agent,
        apolloHandlers: [
          [deleteAiCatalogItemConsumerMutation, disableHandler],
          [aiCatalogAgentQuery, agentRefetchHandler()],
        ],
        permissionOverrides: { adminAiCatalogItemConsumer: true },
      });
      await waitForPromises();

      await clickDisableAndConfirm(wrapper);
      await waitForPromises();

      expect(disableHandler).toHaveBeenCalledWith(
        expect.objectContaining({ id: agent.configurationForProject.id }),
      );
      expect(toast.show).toHaveBeenCalledWith('Agent disabled in this project.');
    });
  });

  describe('Report', () => {
    it('submitting a report with a reason and body shows a success toast', async () => {
      const reportHandler = jest.fn().mockResolvedValue(mockReportAiCatalogItemSuccessMutation);
      const agent = createAgentWithPermissions();
      const { wrapper, toast } = mountShowPage({
        agent,
        apolloHandlers: [[reportAiCatalogItemMutation, reportHandler]],
        permissionOverrides: { reportAiCatalogItem: true },
      });
      await waitForPromises();

      await clickReportAndFillForm(wrapper, {
        reason: 'SPAM_OR_LOW_QUALITY',
        body: 'This is spam content',
      });
      await waitForPromises();

      expect(reportHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          input: { id: agent.id, reason: 'SPAM_OR_LOW_QUALITY', body: 'This is spam content' },
        }),
      );
      expect(toast.show).toHaveBeenCalledWith('Report submitted successfully.');
    });
  });
});
