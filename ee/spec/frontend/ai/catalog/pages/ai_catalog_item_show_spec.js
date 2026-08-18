import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import AiCatalogItemShow from 'ee/ai/catalog/pages/ai_catalog_item_show.vue';
import AiCatalogItemActions from 'ee/ai/catalog/components/ai_catalog_item_actions.vue';
import AiCatalogItemView from 'ee/ai/catalog/components/ai_catalog_item_view.vue';
import VersionAlert from 'ee/ai/catalog/components/version_alert.vue';
import FoundationalIcon from 'ee/ai/components/foundational_icon.vue';
import AiCatalogItemMetadata from 'ee/ai/catalog/components/ai_catalog_item_metadata.vue';
import {
  EVENT_ITEM_TYPE_CUSTOM_AGENT,
  EVENT_ITEM_TYPE_CUSTOM_FLOW,
  TRACK_EVENT_TYPE_AGENT,
  TRACK_EVENT_TYPE_FLOW,
  TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
  VERSION_PINNED,
} from 'ee/ai/catalog/constants';
import reportAiCatalogItem from 'ee/ai/catalog/graphql/mutations/report_ai_catalog_item.mutation.graphql';
import aiCatalogAgentQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_agent.query.graphql';
import aiCatalogFlowQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_flow.query.graphql';
import createAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer.mutation.graphql';
import createAiCatalogItemConsumerBulk from 'ee/ai/catalog/graphql/mutations/create_ai_catalog_item_consumer_bulk.mutation.graphql';
import deleteAiCatalogAgentMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_agent.mutation.graphql';
import deleteAiCatalogThirdPartyFlowMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_third_party_flow.mutation.graphql';
import deleteAiCatalogFlowMutation from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_flow.mutation.graphql';
import deleteAiCatalogItemConsumer from 'ee/ai/catalog/graphql/mutations/delete_ai_catalog_item_consumer.mutation.graphql';
import {
  mockAgent,
  mockFoundationalCatalogAgent,
  mockThirdPartyFlow,
  mockAgentConfigurationForProject,
  mockItemConfigurationForGroup,
  mockAiCatalogAgentResponse,
  mockAiCatalogItemConsumerCreateSuccessProjectResponse,
  mockAiCatalogItemConsumerCreateBulkSuccessProjectResponse,
  mockAiCatalogItemConsumerBulkCreateErrorResponse,
  mockAiCatalogItemConsumerCreateSuccessGroupResponse,
  mockAiCatalogItemConsumerCreateSuccessFlowGroupResponse,
  mockAiCatalogItemConsumerCreateErrorResponse,
  mockCatalogAgentDeleteResponse,
  mockCatalogAgentDeleteErrorResponse,
  mockAiCatalogItemConsumerDeleteResponse,
  mockAiCatalogItemConsumerDeleteErrorResponse,
  mockReportAiCatalogItemSuccessMutation,
  mockReportAiCatalogItemErrorMutation,
  mockVersionProp,
  mockFlow,
  mockFlowConfigurationForProject,
  mockFlowConfigurationForGroup,
  mockAiCatalogFlowResponse,
  mockCatalogFlowDeleteResponse,
  mockCatalogFlowDeleteErrorResponse,
  defaultDuoSettings,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

const agentTestConfig = {
  itemTypeName: 'agent',
  aiCatalogItem: mockAgent,
  itemWithConfigs: {
    ...mockAgent,
    configurationForProject: mockAgentConfigurationForProject,
    configurationForGroup: mockItemConfigurationForGroup,
  },
  configurationForProject: mockAgentConfigurationForProject,
  refetchQuery: aiCatalogAgentQuery,
  queryResponse: mockAiCatalogAgentResponse,
  primaryDeleteMutation: deleteAiCatalogAgentMutation,
  deleteSuccessResponse: mockCatalogAgentDeleteResponse,
  deleteErrorResponse: mockCatalogAgentDeleteErrorResponse,
  addToGroupSuccessResponse: mockAiCatalogItemConsumerCreateSuccessGroupResponse,
  addToGroupToastHref: '/groups/group-1/-/automate/agents/1',
  trackLabel: TRACK_EVENT_TYPE_AGENT,
  expectedViewEventProperties: {
    item_type: EVENT_ITEM_TYPE_CUSTOM_AGENT,
    custom_item_id: 1,
    item_version: '1.0.0',
    item_schema_version: 'v1',
  },
  expectedPinnedViewEventProperties: {
    item_type: EVENT_ITEM_TYPE_CUSTOM_AGENT,
    custom_item_id: 1,
    item_version: '0.9.0',
    item_schema_version: 'v1',
    tools: 'ci_linter,gitlab_blob_search,run_git_command',
  },
  enableToast: 'Agent enabled in Test.',
  enableMultiToast: 'Enabled in selected project(s).',
  enableErrorMsg:
    'Could not enable agent in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
  disableToast: 'Agent disabled in this project.',
  disableToastGroup: 'Agent disabled in this group.',
  disableConfirmMessageProject:
    'Are you sure you want to disable agent %{name}? The agent will no longer work in this project.',
  disableConfirmMessageGroup:
    'Are you sure you want to disable agent %{name}? The agent will also be disabled from any projects in this group.',
  disableErrorMsg: 'Failed to disable agent. You do not have permission to disable this item.',
  disableRequestErrorMsg: 'Failed to disable agent. Error: custom error',
  hardDeletedToast: 'Agent deleted.',
  softDeletedToast: 'Agent hidden.',
  deleteErrorMsg: 'Failed to delete agent. You do not have permission to delete this AI agent.',
  deleteRequestErrorMsg: 'Failed to delete agent. Error: custom error',
  reportErrorMsg: 'Failed to report agent. Error: custom error',
  itemTypeDisabledCanAdminAlert:
    'Custom agents are inactive for all projects. To create or use custom agents, turn on custom agents.',
  itemTypeDisabledAlert:
    'Custom agents are inactive for all projects. To create or use custom agents, contact group owner.',
};

const flowTestConfig = {
  itemTypeName: 'flow',
  aiCatalogItem: mockFlow,
  itemWithConfigs: {
    ...mockFlow,
    configurationForProject: mockFlowConfigurationForProject,
    configurationForGroup: mockFlowConfigurationForGroup,
  },
  configurationForProject: mockFlowConfigurationForProject,
  refetchQuery: aiCatalogFlowQuery,
  queryResponse: mockAiCatalogFlowResponse,
  primaryDeleteMutation: deleteAiCatalogFlowMutation,
  deleteSuccessResponse: mockCatalogFlowDeleteResponse,
  deleteErrorResponse: mockCatalogFlowDeleteErrorResponse,
  addToGroupSuccessResponse: mockAiCatalogItemConsumerCreateSuccessFlowGroupResponse,
  addToGroupToastHref: '/groups/group-1/-/automate/flows/4',
  trackLabel: TRACK_EVENT_TYPE_FLOW,
  expectedViewEventProperties: {
    item_type: EVENT_ITEM_TYPE_CUSTOM_FLOW,
    custom_item_id: 4,
    item_version: '1.0.0',
    item_schema_version: 'v1',
  },
  expectedPinnedViewEventProperties: {
    item_type: EVENT_ITEM_TYPE_CUSTOM_FLOW,
    custom_item_id: 4,
    item_version: '0.9.0',
    item_schema_version: 'v1',
  },
  enableToast: 'Flow enabled in Test.',
  enableMultiToast: 'Enabled in selected project(s).',
  enableErrorMsg:
    'Could not enable flow in the project. Check that the project meets the <a href="/help/user/duo_agent_platform/ai_catalog#view-the-ai-catalog" target="_blank">prerequisites</a> and try again.',
  disableToast: 'Flow disabled in this project.',
  disableToastGroup: 'Flow disabled in this group.',
  disableConfirmMessageProject:
    'Are you sure you want to disable flow %{name}? The flow, its service account, and any associated triggers will no longer work in this project.',
  disableConfirmMessageGroup:
    'Are you sure you want to disable flow %{name}? The flow will also be disabled from any projects in this group.',
  disableErrorMsg: 'Failed to disable flow. You do not have permission to disable this item.',
  disableRequestErrorMsg: 'Failed to disable flow. Error: custom error',
  hardDeletedToast: 'Flow deleted.',
  softDeletedToast: 'Flow hidden.',
  deleteErrorMsg: 'Failed to delete flow. You do not have permission to delete this AI flow.',
  deleteRequestErrorMsg: 'Failed to delete flow. Error: custom error',
  reportErrorMsg: 'Failed to report flow. Error: custom error',
  itemTypeDisabledCanAdminAlert:
    'Custom flows are inactive for all projects. To create or use custom flows, turn on custom flows.',
  itemTypeDisabledAlert:
    'Custom flows are inactive for all projects. To create or use custom flows, contact group owner.',
};

describe.each([agentTestConfig, flowTestConfig])(
  'AiCatalogItemShow ($itemTypeName)',
  ({
    itemTypeName,
    aiCatalogItem,
    itemWithConfigs,
    configurationForProject,
    refetchQuery,
    queryResponse,
    primaryDeleteMutation,
    deleteSuccessResponse,
    deleteErrorResponse,
    addToGroupSuccessResponse,
    addToGroupToastHref,
    trackLabel,
    expectedViewEventProperties,
    expectedPinnedViewEventProperties,
    enableToast,
    enableMultiToast,
    enableErrorMsg,
    disableToast,
    disableToastGroup,
    disableConfirmMessageProject,
    disableConfirmMessageGroup,
    disableErrorMsg,
    disableRequestErrorMsg,
    hardDeletedToast,
    softDeletedToast,
    deleteErrorMsg,
    deleteRequestErrorMsg,
    reportErrorMsg,
    itemTypeDisabledCanAdminAlert,
    itemTypeDisabledAlert,
  }) => {
    let wrapper;
    let mockApollo;

    const mockToast = { show: jest.fn() };
    const routeParams = { id: '1' };
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    const reportItemMock = jest.fn().mockResolvedValue(mockReportAiCatalogItemSuccessMutation);
    const queryHandler = jest.fn().mockResolvedValue(queryResponse);
    const createAiCatalogItemConsumerHandler = jest
      .fn()
      .mockResolvedValue(mockAiCatalogItemConsumerCreateSuccessProjectResponse);
    const createAiCatalogItemConsumerBulkHandler = jest
      .fn()
      .mockResolvedValue(mockAiCatalogItemConsumerCreateBulkSuccessProjectResponse);
    const primaryDeleteMutationHandler = jest.fn().mockResolvedValue(deleteSuccessResponse);
    const deleteItemConsumerMutationHandler = jest
      .fn()
      .mockResolvedValue(mockAiCatalogItemConsumerDeleteResponse);
    // Only used in agent context to handle third-party flow items
    const deleteThirdPartyFlowMutationHandler = jest.fn();

    const createComponent = ({ props = {}, provide = {}, glAbilities = {} } = {}) => {
      const apolloHandlers = [
        [reportAiCatalogItem, reportItemMock],
        [refetchQuery, queryHandler],
        [createAiCatalogItemConsumer, createAiCatalogItemConsumerHandler],
        [createAiCatalogItemConsumerBulk, createAiCatalogItemConsumerBulkHandler],
        [deleteAiCatalogItemConsumer, deleteItemConsumerMutationHandler],
        [primaryDeleteMutation, primaryDeleteMutationHandler],
        [deleteAiCatalogThirdPartyFlowMutation, deleteThirdPartyFlowMutationHandler],
      ];

      mockApollo = createMockApollo(apolloHandlers);
      // refetchQueries will only refetch active queries, so simply registering a query handler is not enough.
      // We need to call `subscribe()` to make the query observable and avoid "Unknown query" errors.
      // This simulates what the actual code in VueApollo is doing when adding a smart query.
      // Docs: https://www.apollographql.com/docs/react/api/core/ApolloClient/#watchquery
      mockApollo.defaultClient.watchQuery({ query: refetchQuery }).subscribe();

      wrapper = shallowMountExtended(AiCatalogItemShow, {
        apolloProvider: mockApollo,
        propsData: {
          aiCatalogItem: itemWithConfigs,
          version: mockVersionProp,
          ...props,
        },
        provide: {
          isGlobalNamespace: false,
          isProjectNamespace: true,
          projectId: '1',
          glAbilities,
          ...defaultDuoSettings,
          ...provide,
        },
        mocks: {
          $route: { params: routeParams },
          $toast: mockToast,
        },
      });
    };

    const findErrorsAlert = () => wrapper.findComponent(ErrorsAlert);
    const findItemActions = () => wrapper.findComponent(AiCatalogItemActions);
    const findItemView = () => wrapper.findComponent(AiCatalogItemView);
    const findVersionAlert = () => wrapper.findComponent(VersionAlert);
    const findGitLabMaintainedIcon = () => wrapper.findComponent(FoundationalIcon);
    const findMetadataComponent = () => wrapper.findComponent(AiCatalogItemMetadata);
    const findDisabledItemTypeAlert = () => wrapper.findByTestId('disabled-type-alert');

    describe('template', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders item actions', () => {
        expect(findItemActions().props('item')).toEqual(itemWithConfigs);
      });

      it('passes the latest version to item actions so enable/disable events are fully instrumented', () => {
        expect(findItemActions().props('version')).toEqual(itemWithConfigs.latestVersion);
      });

      it('passes the project-scoped disable confirm message in a project namespace', () => {
        expect(findItemActions().props('disableConfirmMessage')).toBe(disableConfirmMessageProject);
      });

      it('passes the group-scoped disable confirm message in a group namespace', () => {
        createComponent({ provide: { isProjectNamespace: false } });

        expect(findItemActions().props('disableConfirmMessage')).toBe(disableConfirmMessageGroup);
      });

      it('renders AiCatalogItemMetadata component', () => {
        expect(findMetadataComponent().props('item')).toEqual(itemWithConfigs);
      });

      it('renders item view', () => {
        expect(findItemView().props('item')).toEqual(itemWithConfigs);
      });

      it('does not render the version alert by default', () => {
        expect(findVersionAlert().exists()).toBe(false);
      });

      it('does not display disabled item type banner', () => {
        expect(findDisabledItemTypeAlert().exists()).toBe(false);
      });
    });

    describe('when custom item type is deactivated in duo settings and user can admin', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            duoSettings: {
              ...defaultDuoSettings,
              duoCustomAgentsEnabled: false,
              duoCustomFlowsEnabled: false,
            },
          },
          glAbilities: {
            adminAiCatalogItem: true,
          },
        });
      });

      it('displays disabled item type banner and user cannot admin', () => {
        expect(findDisabledItemTypeAlert().exists()).toBe(true);
        expect(findDisabledItemTypeAlert().text()).toBe(itemTypeDisabledCanAdminAlert);
      });
    });

    describe('when custom item type is deactivated in duo settings', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            duoSettings: {
              ...defaultDuoSettings,
              duoCustomAgentsEnabled: false,
              duoCustomFlowsEnabled: false,
            },
          },
        });
      });

      it('displays disabled item type banner', () => {
        expect(findDisabledItemTypeAlert().exists()).toBe(true);
        expect(findDisabledItemTypeAlert().text()).toBe(itemTypeDisabledAlert);
      });
    });

    describe('when the item has a new version available', () => {
      beforeEach(() => {
        createComponent({
          props: {
            version: { isUpdateAvailable: true, activeVersionKey: VERSION_PINNED },
          },
        });
      });

      it('renders the version alert', () => {
        expect(findVersionAlert().exists()).toBe(true);
      });

      it('shows error alert when version-alert emits an error', async () => {
        findVersionAlert().vm.$emit('error', {
          title: `Could not update ${itemTypeName}.`,
          errors: ['You do not have permission.'],
        });
        await Vue.nextTick();

        expect(findErrorsAlert().props('title')).toBe(`Could not update ${itemTypeName}.`);
        expect(findErrorsAlert().props('errors')).toEqual(['You do not have permission.']);
      });
    });

    describe('gitlab-maintained icon', () => {
      describe('when item is GitLab-maintained', () => {
        beforeEach(() => {
          createComponent({
            props: {
              aiCatalogItem: {
                ...aiCatalogItem,
                verificationLevel: 'GITLAB_MAINTAINED',
                configurationForProject,
              },
            },
          });
        });

        it('renders gitlab-maintained icon with correct props', () => {
          expect(findGitLabMaintainedIcon().props('resourceId')).toBe(aiCatalogItem.id);
          expect(findGitLabMaintainedIcon().props('itemType')).toBe(aiCatalogItem.itemType);
        });
      });

      describe('when item is not GitLab-maintained', () => {
        beforeEach(() => {
          createComponent();
        });

        it('does not render gitlab-maintained icon', () => {
          expect(findGitLabMaintainedIcon().exists()).toBe(false);
        });
      });
    });

    describe('tracking events', () => {
      beforeEach(() => {
        createComponent();
      });

      it(`tracks ${TRACK_EVENT_VIEW_AI_CATALOG_ITEM} event on mount`, () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
          {
            label: trackLabel,
            ...expectedViewEventProperties,
          },
          undefined,
        );
      });

      it('tracks the pinned version the viewer is seeing when a pinned version is active', () => {
        createComponent({
          props: { version: { isUpdateAvailable: true, activeVersionKey: VERSION_PINNED } },
        });
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        expect(trackEventSpy).toHaveBeenCalledWith(
          TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
          {
            label: trackLabel,
            ...expectedPinnedViewEventProperties,
          },
          undefined,
        );
      });
    });

    describe('on adding item to multiple projects', () => {
      const addItemToProjects = () =>
        findItemActions().vm.$emit('add-to-target', { target: ['1', '2'] });

      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: { aiCatalogBulkItemConsumerCreate: true },
          },
        });
      });

      it('calls bulk create consumer mutation', () => {
        addItemToProjects();

        expect(createAiCatalogItemConsumerBulkHandler).toHaveBeenCalledWith({
          input: { itemId: aiCatalogItem.id, projectIds: ['1', '2'] },
        });
      });

      it('forwards triggerTypes and triggerFilter when both are present', () => {
        const triggerFilter = {
          pipeline_hooks: {
            rules: [{ field: 'object_attributes.status', operator: 'in', value: ['failed'] }],
          },
        };
        findItemActions().vm.$emit('add-to-target', {
          target: ['1', '2'],
          triggerTypes: ['pipeline_hooks'],
          triggerFilter,
        });

        expect(createAiCatalogItemConsumerBulkHandler).toHaveBeenCalledWith({
          input: {
            itemId: aiCatalogItem.id,
            projectIds: ['1', '2'],
            triggerTypes: ['pipeline_hooks'],
            triggerFilter,
          },
        });
      });

      it('omits triggerFilter from the input when it is empty', () => {
        findItemActions().vm.$emit('add-to-target', {
          target: ['1', '2'],
          triggerTypes: ['mention'],
          triggerFilter: {},
        });

        expect(createAiCatalogItemConsumerBulkHandler).toHaveBeenCalledWith({
          input: {
            itemId: aiCatalogItem.id,
            projectIds: ['1', '2'],
            triggerTypes: ['mention'],
          },
        });
      });

      describe('when request succeeds', () => {
        beforeEach(async () => {
          addItemToProjects();
          await waitForPromises();
        });

        it('shows toast', () => {
          expect(mockToast.show).toHaveBeenCalledWith(enableMultiToast);
        });

        it('clears previous errors', () => {
          expect(findErrorsAlert().props('errors')).toEqual([]);
        });

        it('refetches item data', () => {
          expect(queryHandler).toHaveBeenCalled();
        });
      });

      describe('when request succeeds after a previous error', () => {
        it('clears the error alert', async () => {
          createAiCatalogItemConsumerBulkHandler
            .mockResolvedValueOnce(mockAiCatalogItemConsumerBulkCreateErrorResponse)
            .mockResolvedValueOnce(mockAiCatalogItemConsumerCreateBulkSuccessProjectResponse);

          addItemToProjects();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual(['Item already configured.']);

          addItemToProjects();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([]);
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows error alert', async () => {
          createAiCatalogItemConsumerBulkHandler.mockResolvedValue(
            mockAiCatalogItemConsumerBulkCreateErrorResponse,
          );
          addItemToProjects();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual(['Item already configured.']);
        });

        it('does not report business validation errors to Sentry', async () => {
          createAiCatalogItemConsumerBulkHandler.mockResolvedValue(
            mockAiCatalogItemConsumerBulkCreateErrorResponse,
          );
          addItemToProjects();
          await waitForPromises();

          expect(Sentry.captureException).not.toHaveBeenCalled();
        });
      });

      describe('when request fails', () => {
        it('shows error alert and captures exception', async () => {
          createAiCatalogItemConsumerBulkHandler.mockRejectedValue(new Error('custom error'));
          addItemToProjects();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([enableErrorMsg]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });

    describe('on adding a restricted item to multiple projects', () => {
      const addItemToProjects = () =>
        findItemActions().vm.$emit('add-to-target', { target: ['1', '2'] });

      beforeEach(() => {
        createComponent({
          props: {
            aiCatalogItem: { ...itemWithConfigs, public: false, visibility: 'RESTRICTED' },
          },
          provide: {
            glFeatures: {
              aiCatalogBulkItemConsumerCreate: true,
              aiCatalogInternalVisibility: true,
            },
          },
        });
      });

      it('calls the bulk create mutation', () => {
        addItemToProjects();

        expect(createAiCatalogItemConsumerBulkHandler).toHaveBeenCalledWith({
          input: { itemId: aiCatalogItem.id, projectIds: ['1', '2'] },
        });
      });
    });

    describe('on adding item to project', () => {
      const addItemToProject = () =>
        findItemActions().vm.$emit('add-to-target', { target: { projectId: '1' } });

      beforeEach(() => {
        createComponent();
      });

      it('calls create consumer mutation', () => {
        addItemToProject();

        expect(createAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
          input: {
            itemId: aiCatalogItem.id,
            target: { projectId: '1' },
            pinnedVersion: aiCatalogItem.latestVersion.versionName,
          },
        });
      });

      it('forwards triggerTypes and triggerFilter when both are present', () => {
        const triggerFilter = {
          pipeline_hooks: {
            rules: [{ field: 'object_attributes.status', operator: 'in', value: ['failed'] }],
          },
        };
        findItemActions().vm.$emit('add-to-target', {
          target: { projectId: '1' },
          triggerTypes: ['pipeline_hooks'],
          triggerFilter,
        });

        expect(createAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
          input: {
            itemId: aiCatalogItem.id,
            target: { projectId: '1' },
            pinnedVersion: aiCatalogItem.latestVersion.versionName,
            triggerTypes: ['pipeline_hooks'],
            triggerFilter,
          },
        });
      });

      it('omits triggerFilter from the input when it is empty', () => {
        findItemActions().vm.$emit('add-to-target', {
          target: { projectId: '1' },
          triggerTypes: ['mention'],
          triggerFilter: {},
        });

        expect(createAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
          input: {
            itemId: aiCatalogItem.id,
            target: { projectId: '1' },
            pinnedVersion: aiCatalogItem.latestVersion.versionName,
            triggerTypes: ['mention'],
          },
        });
      });

      describe('when request succeeds', () => {
        beforeEach(async () => {
          addItemToProject();
          await waitForPromises();
        });

        it('shows toast', () => {
          expect(mockToast.show).toHaveBeenCalledWith(enableToast);
        });

        it('clears previous errors', () => {
          expect(findErrorsAlert().props('errors')).toEqual([]);
        });

        it('refetches item data', () => {
          expect(queryHandler).toHaveBeenCalled();
        });
      });

      describe('when request succeeds after a previous error', () => {
        it('clears the error alert', async () => {
          createAiCatalogItemConsumerHandler
            .mockResolvedValueOnce(mockAiCatalogItemConsumerCreateErrorResponse)
            .mockResolvedValueOnce(mockAiCatalogItemConsumerCreateSuccessProjectResponse);

          addItemToProject();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual(['Item already configured.']);

          addItemToProject();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([]);
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows error alert', async () => {
          createAiCatalogItemConsumerHandler.mockResolvedValue(
            mockAiCatalogItemConsumerCreateErrorResponse,
          );
          addItemToProject();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual(['Item already configured.']);
        });

        it('does not report business validation errors to Sentry', async () => {
          createAiCatalogItemConsumerHandler.mockResolvedValue(
            mockAiCatalogItemConsumerCreateErrorResponse,
          );
          addItemToProject();
          await waitForPromises();

          expect(Sentry.captureException).not.toHaveBeenCalled();
        });
      });

      describe('when request fails', () => {
        it('shows error alert and captures exception', async () => {
          createAiCatalogItemConsumerHandler.mockRejectedValue(new Error('custom error'));
          addItemToProject();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([enableErrorMsg]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });

    describe('on adding item to group', () => {
      const addItemToGroup = () =>
        findItemActions().vm.$emit('add-to-target', { target: { groupId: '1' } });

      beforeEach(() => {
        createAiCatalogItemConsumerHandler.mockResolvedValue(addToGroupSuccessResponse);
        createComponent({ props: { aiCatalogItem }, provide: { isGlobalNamespace: true } });
      });

      it('calls create consumer mutation', () => {
        addItemToGroup();

        expect(createAiCatalogItemConsumerHandler).toHaveBeenCalledWith({
          input: {
            itemId: aiCatalogItem.id,
            target: { groupId: '1' },
            pinnedVersion: aiCatalogItem.latestVersion.versionName,
          },
        });
      });

      describe('when request succeeds', () => {
        beforeEach(async () => {
          addItemToGroup();
          await waitForPromises();
        });

        it('shows toast with a link to the group', () => {
          expect(mockToast.show).toHaveBeenCalledWith(enableToast, {
            action: { href: addToGroupToastHref, text: 'View' },
          });
        });
      });
    });

    describe('on deleting the item', () => {
      const forceHardDelete = false;
      const deleteItem = () => findItemActions().props('deleteFn')(forceHardDelete);

      beforeEach(() => {
        createComponent();
      });

      it('calls the correct delete mutation', () => {
        deleteItem();

        expect(primaryDeleteMutationHandler).toHaveBeenCalledWith({
          id: aiCatalogItem.id,
          forceHardDelete,
        });
      });

      describe('when request succeeds', () => {
        it('shows hidden toast', async () => {
          deleteItem();
          await waitForPromises();

          expect(mockToast.show).toHaveBeenCalledWith(softDeletedToast);
        });

        it('shows deleted toast when forceHardDelete is true', async () => {
          findItemActions().props('deleteFn')(true);
          await waitForPromises();

          expect(mockToast.show).toHaveBeenCalledWith(hardDeletedToast);
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows error alert', async () => {
          primaryDeleteMutationHandler.mockResolvedValue(deleteErrorResponse);
          deleteItem();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([deleteErrorMsg]);
        });
      });

      describe('when request fails', () => {
        it('shows error alert and captures exception', async () => {
          primaryDeleteMutationHandler.mockRejectedValue(new Error('custom error'));
          deleteItem();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([deleteRequestErrorMsg]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });

    describe('when deleting a THIRD_PARTY_FLOW item', () => {
      beforeEach(() => {
        createComponent({ props: { aiCatalogItem: mockThirdPartyFlow } });
      });

      it('calls the third-party flow delete mutation, not the primary delete mutation', () => {
        const forceHardDelete = false;
        findItemActions().props('deleteFn')(forceHardDelete);

        expect(primaryDeleteMutationHandler).not.toHaveBeenCalled();
        expect(deleteThirdPartyFlowMutationHandler).toHaveBeenCalledWith({
          id: mockThirdPartyFlow.id,
          forceHardDelete,
        });
      });
    });

    describe('on disabling the item', () => {
      const mockVersionPropWithFn = {
        ...mockVersionProp,
        activeVersionKey: VERSION_PINNED,
        setActiveVersionKey: jest.fn(),
      };

      const disableItem = () => findItemActions().props('disableFn')();

      beforeEach(() => {
        createComponent({ props: { version: mockVersionPropWithFn } });
      });

      it('calls disable mutation', () => {
        disableItem();

        expect(deleteItemConsumerMutationHandler).toHaveBeenCalledWith({
          id: configurationForProject.id,
        });
      });

      describe('when request succeeds', () => {
        it('shows toast', async () => {
          disableItem();
          await waitForPromises();

          expect(mockToast.show).toHaveBeenCalledWith(disableToast);
        });

        it('shows a group-scoped toast in a group namespace', async () => {
          createComponent({
            props: { version: mockVersionPropWithFn },
            provide: { isProjectNamespace: false },
          });
          disableItem();
          await waitForPromises();

          expect(mockToast.show).toHaveBeenCalledWith(disableToastGroup);
        });

        it('clears the active version key to allow parent recomputation', async () => {
          disableItem();
          await waitForPromises();

          expect(mockVersionPropWithFn.setActiveVersionKey).toHaveBeenCalledWith(null);
        });

        it('refetches item data', () => {
          expect(queryHandler).toHaveBeenCalled();
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows error alert', async () => {
          deleteItemConsumerMutationHandler.mockResolvedValue(
            mockAiCatalogItemConsumerDeleteErrorResponse,
          );
          disableItem();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([disableErrorMsg]);
        });
      });

      describe('when request fails', () => {
        it('shows error alert and captures exception', async () => {
          deleteItemConsumerMutationHandler.mockRejectedValue(new Error('custom error'));
          disableItem();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([disableRequestErrorMsg]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });

    describe('when reporting the item', () => {
      const input = { reason: 'SPAM', body: 'This is a test report' };
      const reportItem = () => findItemActions().vm.$emit('report-item', input);

      beforeEach(() => {
        createComponent();
      });

      it('sends a report request', () => {
        reportItem();

        expect(reportItemMock).toHaveBeenCalledWith({ input: { id: aiCatalogItem.id, ...input } });
      });

      describe('when request succeeds', () => {
        it('shows toast', async () => {
          reportItem();
          await waitForPromises();

          expect(mockToast.show).toHaveBeenCalledWith('Report submitted successfully.');
        });
      });

      describe('when request succeeds but returns errors', () => {
        it('shows error alert', async () => {
          reportItemMock.mockResolvedValue(mockReportAiCatalogItemErrorMutation);
          reportItem();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([
            "The resource that you are attempting to access does not exist or you don't have permission to perform this action",
          ]);
        });
      });

      describe('when request fails', () => {
        it('shows error alert and captures exception', async () => {
          reportItemMock.mockRejectedValue(new Error('custom error'));
          reportItem();
          await waitForPromises();

          expect(findErrorsAlert().props('errors')).toEqual([reportErrorMsg]);
          expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
        });
      });
    });
  },
);

describe('AiCatalogItemShow (foundational agent)', () => {
  let wrapper;
  const routeParams = { id: '1' };
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = () => {
    const mockApollo = createMockApollo([[aiCatalogAgentQuery, jest.fn()]]);

    wrapper = shallowMountExtended(AiCatalogItemShow, {
      apolloProvider: mockApollo,
      propsData: {
        aiCatalogItem: mockFoundationalCatalogAgent,
        version: mockVersionProp,
      },
      provide: {
        isGlobalNamespace: true,
        isProjectNamespace: false,
        projectId: null,
        glAbilities: {},
        ...defaultDuoSettings,
      },
      mocks: {
        $route: { params: routeParams },
        $toast: { show: jest.fn() },
      },
    });
  };

  it('tracks the view event with foundational agent properties', () => {
    createComponent();

    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith(
      TRACK_EVENT_VIEW_AI_CATALOG_ITEM,
      {
        label: TRACK_EVENT_TYPE_AGENT,
        item_type: 'foundational_agent',
        item_version: '1.0.0',
        item_schema_version: 'v1',
        flow_name: 'chat',
        component_name: 'orbit_agent',
      },
      undefined,
    );
  });
});
