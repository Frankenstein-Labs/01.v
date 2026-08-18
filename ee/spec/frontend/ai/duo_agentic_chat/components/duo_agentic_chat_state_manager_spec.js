import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { parseDocument } from 'yaml';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';
import ChatLoadingState from 'ee/ai/components/chat_loading_state.vue';
import {
  getInstanceSlots,
  mountExtended,
  shallowMountExtended,
} from 'helpers/vue_test_utils_helper';
import { setAgenticMode } from 'ee/ai/utils';
import { ignoreConsoleMessages } from 'helpers/console_watcher';
import createMockApollo from 'helpers/mock_apollo_helper';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import storeMutations from 'ee/ai/tanuki_bot/store/mutations';
import * as storeActions from 'ee/ai/tanuki_bot/store/actions';
import getUserWorkflows from 'ee/ai/graphql/get_user_workflow.query.graphql';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import getAiChatAvailableModels from 'ee/ai/graphql/get_ai_chat_available_models.query.graphql';
import getConfiguredAgents from 'ee/ai/graphql/get_configured_agents.query.graphql';
import getAgentFlowConfig from 'ee/ai/graphql/get_agent_flow_config.query.graphql';
import getFoundationalChatAgents from 'ee/ai/graphql/get_foundational_chat_agents.graphql';
import getFlowStatus from 'ee/ai/graphql/get_flow_status.query.graphql';
import duoWorkflowMutation from 'ee/ai/graphql/duo_workflow.mutation.graphql';
import deleteAgenticWorkflowMutation from 'ee/ai/graphql/delete_agentic_workflow.mutation.graphql';
import updateWebSearchMutation from 'ee/ai/graphql/update_duo_workflow_web_search.mutation.graphql';
import getWorkflowLatestCheckpointQuery from 'ee/ai/graphql/get_workflow_latest_checkpoint.query.graphql';
import getGitlabCreditsStatusQuery from 'ee/ai/graphql/get_gitlab_credits_status.query.graphql';
import AgenticModeToggle from 'ee/ai/duo_agentic_chat/components/agentic_mode_toggle.vue';
import DuoAgenticChatStateManager from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_state_manager.vue';
import DuoAgenticChatView from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_view.vue';
import DuoChatDeleteThreadModal from 'ee/ai/components/duo_chat_delete_thread_modal.vue';
import NoNamespaceEmptyState from 'ee/ai/duo_agentic_chat/components/no_namespace_empty_state.vue';
import { WorkflowUtils } from 'ee/ai/duo_agentic_chat/utils/workflow_utils';
import { SystemContextManager } from 'ee/ai/duo_agentic_chat/context/system_context_manager';
import { registerExternalContextProvider } from 'ee/ai/duo_agentic_chat/context/external_context_store';
import { runMessageTransformers } from 'ee/ai/duo_agentic_chat/transformers/index';
import {
  getCurrentModel,
  getDefaultModel,
  getModel,
  saveModel,
  isModelSelectionDisabled as checkModelSelectionDisabled,
} from 'ee/ai/duo_agentic_chat/utils/model_selection_utils';
import * as WorkflowSocketUtils from 'ee/ai/duo_agentic_chat/websocket/workflow_utils';
import {
  loadThreadSnapshot,
  clearThreadSnapshot,
} from 'ee/ai/duo_agentic_chat/utils/chat_thread_snapshot';
import CreditsExhaustedAlert from 'ee/ai/duo_agentic_chat/components/credits_exhausted_alert.vue';
import { getSessionStorageValue, saveSessionStorageValue } from '~/lib/utils/local_storage';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
  DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
  DUO_CURRENT_WORKFLOW_STORAGE_KEY,
  DUO_CHAT_VIEWS,
  DUO_WORKFLOW_STATUS_RUNNING,
  DUO_AGENTIC_CHAT_PENDING_USER_MESSAGE_ID,
  DUO_WORKFLOW_CHAT_DEFINITION,
  DUO_WORKFLOW_NEW_CHAT_DEFINITION,
} from 'ee/ai/constants';
import {
  AGENTIC_CHAT_SHOW_ROUTE,
  AGENTIC_CHAT_HISTORY_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import * as streamManager from 'ee/ai/duo_agentic_chat/websocket/stream_manager';
import { getCookie } from '~/lib/utils/common_utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import {
  FEEDBACK_TRACKING_EVENT,
  CHAT_TRACKING_EVENT,
  TRIGGER_SOURCE_WEB_CHAT,
  TRIGGER_SOURCE_WEB_UI,
} from 'ee/ai/duo_agentic_chat/constants';
import { EventsTracker } from 'ee/ai/duo_agentic_chat/observability/events_tracker';
import { catalogAgentsFromResponse } from 'ee/ai/duo_agentic_chat/utils/agent_utils';
import StartFlowToolMessage from 'ee/ai/duo_agentic_chat/components/messages/message_tool_start_flow.vue';
import MessageTierAccessDenied from 'ee/ai/duo_agentic_chat/components/messages/message_tier_access_denied.vue';
import {
  MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE,
  MOCK_MODEL_LIST_ITEMS,
  MOCK_GITLAB_DEFAULT_MODEL_ITEM,
  MOCK_CONFIGURED_AGENTS_RESPONSE,
  MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE,
  MOCK_FLOW_CONFIG_RESPONSE,
  MOCK_FETCHED_FOUNDATIONAL_AGENT,
  MOCK_FLOW_AGENT_CONFIG,
  DUO_CHAT_AGENT_MOCK,
  DUO_FOUNDATIONAL_AGENT_MOCK,
  MOCK_START_FLOW_TOOL_MESSAGE,
} from './mock_data';

jest.mock('~/behaviors/markdown/render_gfm', () => {
  const actual = jest.requireActual('~/behaviors/markdown/render_gfm');
  return { ...actual, renderGFM: jest.fn() };
});

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils');

jest.mock('ee/ai/duo_agentic_chat/utils/agent_utils', () => ({
  ...jest.requireActual('ee/ai/duo_agentic_chat/utils/agent_utils'),
  catalogAgentsFromResponse: jest.fn(
    jest.requireActual('ee/ai/duo_agentic_chat/utils/agent_utils').catalogAgentsFromResponse,
  ),
}));

Vue.config.ignoredElements = ['fe-island-duo-next'];

jest.mock('ee/ai/duo_agentic_chat/websocket/stream_manager', () => ({
  connect: jest.fn(),
  disconnect: jest.fn(),
  send: jest.fn(),
  subscribe: jest.fn().mockImplementation(() => ({ dispose: jest.fn() })),
  getStatus: jest.fn().mockReturnValue({ connected: false, bufferedCount: 0 }),
  terminate: jest.fn(),
}));

jest.mock('ee/ai/duo_agentic_chat/events/event_hub', () => ({
  initDuoAgenticChatEventHub: jest.fn().mockReturnValue({ dispose: jest.fn() }),
  subscribeToEvent: jest.fn().mockReturnValue({ dispose: jest.fn() }),
}));

jest.mock('fe_islands/duo_next/dist/main', () => ({}), {
  virtual: true,
});

jest.mock('yaml');

jest.mock('~/lib/utils/websocket_utils', () => ({
  parseMessage: jest.fn(async (event) => {
    const data = typeof event.data === 'string' ? event.data : await event.data.text();
    return JSON.parse(data);
  }),
}));

jest.mock('ee/ai/duo_agentic_chat/utils/workflow_utils', () => ({
  WorkflowUtils: {
    transformChatMessages: jest.fn(),
    parseWorkflowData: jest.fn(),
    normalizeDuoMessages: jest.fn(),
  },
}));

jest.mock('ee/ai/duo_agentic_chat/utils/model_selection_utils', () => ({
  getCurrentModel: jest.fn(),
  getDefaultModel: jest.fn(),
  getModel: jest.fn(),
  saveModel: jest.fn(),
  isModelSelectionDisabled: jest.fn(),
}));

jest.mock('ee/ai/duo_agentic_chat/utils/chat_thread_snapshot', () => ({
  saveThreadSnapshot: jest.fn(),
  loadThreadSnapshot: jest.fn(),
  clearThreadSnapshot: jest.fn(),
}));

jest.mock('ee/ai/duo_agentic_chat/transformers/index', () => ({
  runMessageTransformers: jest.fn((messages) => messages),
}));

jest.mock('ee/ai/duo_agentic_chat/observability/events_tracker', () => ({
  EventsTracker: {
    updateContext: jest.fn(),
    trackApproveTool: jest.fn(),
    trackDenyTool: jest.fn(),
    trackClickThroughFlowWidget: jest.fn(),
    reset: jest.fn(),
  },
}));

const MOCK_PROJECT_ID = 'gid://gitlab/Project/123';
const MOCK_NAMESPACE_ID = 'gid://gitlab/Group/456';
const MOCK_RESOURCE_ID = 'gid://gitlab/Resource/789';
const MOCK_WORKFLOW_ID = 'gid://gitlab/Ai::DuoWorkflows::Workflow/456';
const MOCK_USER_MESSAGE = {
  content: 'How can I optimize my CI pipeline?',
  role: 'user',
  requestId: `${MOCK_WORKFLOW_ID}-0-user`,
};
const MOCK_CONTEXT_PRESETS_RESPONSE = {
  data: {
    aiChatContextPresets: {
      questions: [
        'How can I optimize my CI pipeline?',
        'What are best practices for merge requests?',
        'How do I set up a workflow for my project?',
        'What are the advantages of using GitLab CI/CD?',
      ],
    },
  },
};
const MOCK_CREATE_WORKFLOW_MUTATION_RESPONSE = {
  data: {
    aiDuoWorkflowCreate: {
      workflow: { id: MOCK_WORKFLOW_ID },
      errors: [],
    },
  },
};
const MOCK_DELETE_WORKFLOW_MUTATION_RESPONSE = {
  data: {
    deleteDuoWorkflowsWorkflow: { success: true, clientMutationId: null, errors: [] },
  },
};
const MOCK_UPDATE_WEB_SEARCH_MUTATION_RESPONSE = {
  data: {
    updateDuoWorkflowWebSearch: {
      workflow: { id: MOCK_WORKFLOW_ID },
      errors: [],
    },
  },
};

const MOCK_USER_WORKFLOWS_RESPONSE = {
  data: {
    duoWorkflowWorkflows: {
      edges: [
        {
          node: {
            id: MOCK_WORKFLOW_ID,
            title: 'Test workflow goal',
            lastUpdatedAt: '2024-01-01T00:00:00Z',
            aiCatalogItemVersionId: null,
            agentName: 'GitLab Duo',
            archived: false,
            stalled: false,
          },
        },
      ],
    },
  },
};

const MOCK_WORKFLOW_EVENTS_RESPONSE = {
  duoWorkflowWorkflows: {
    nodes: [
      {
        id: 'workflow-1',
        status: 'completed',
        aiCatalogItemVersionId: '',
        workflowDefinition: null,
        archived: false,
        stalled: false,
        webSearchEnabled: false,
        latestCheckpoint: {
          workflowGoal: '',
          workflowStatus: 'completed',
          errors: null,
          duoMessages: [],
        },
      },
    ],
  },
};

const MOCK_WORKFLOW_EVENTS_RESPONSE_WITH_FOUNDATIONAL_AGENT = {
  duoWorkflowWorkflows: {
    nodes: [
      {
        id: 'workflow-1',
        status: 'completed',
        aiCatalogItemVersionId: '',
        workflowDefinition: MOCK_FETCHED_FOUNDATIONAL_AGENT.referenceWithVersion,
        archived: false,
        stalled: false,
        webSearchEnabled: false,
        latestCheckpoint: {
          workflowGoal: '',
          workflowStatus: 'completed',
          errors: null,
          duoMessages: [],
        },
      },
    ],
  },
};

const MOCK_TRANSFORMED_MESSAGES = [
  {
    content: 'Hello, how can I help?',
    role: 'assistant',
    requestId: '456-1-agent',
    message_type: 'agent',
  },
];

const MOCK_PARSED_FLOW_CONFIG = { components: [{ name: 'test', type: 'agent' }] };

const MOCK_UTILS_SETUP = () => {
  WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);
  WorkflowUtils.normalizeDuoMessages.mockReturnValue([]);
  WorkflowUtils.parseWorkflowData.mockReturnValue({
    workflowGoal: '',
    workflowStatus: 'completed',
    errors: null,
    duoMessages: [],
  });
  parseDocument.mockReturnValue(MOCK_PARSED_FLOW_CONFIG);

  getCurrentModel.mockReturnValue(MOCK_GITLAB_DEFAULT_MODEL_ITEM);
  getDefaultModel.mockReturnValue(MOCK_GITLAB_DEFAULT_MODEL_ITEM);
  // getModel needs to search arrays by value, simple Array.find helper
  getModel.mockImplementation((models, value) => models?.find((m) => m.value === value));
  saveModel.mockReturnValue(true);
  checkModelSelectionDisabled.mockReturnValue(false);

  jest
    .spyOn(WorkflowSocketUtils, 'buildWebsocketUrl')
    .mockReturnValue('/api/v4/ai/duo_workflows/ws');
  jest.spyOn(WorkflowSocketUtils, 'buildStartRequest').mockReturnValue({
    startRequest: {
      workflowID: '456',
      clientVersion: '1.0',
      workflowDefinition: 'chat',
      goal: '',
      approval: {},
    },
  });
  jest.spyOn(WorkflowSocketUtils, 'processWorkflowMessage');
};

const expectedPageContextItem = {
  id: 'page-context',
  content: `<current_gitlab_page_url>http://test.host/</current_gitlab_page_url>
<current_gitlab_page_title></current_gitlab_page_title>`,
  category: DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
  metadata: JSON.stringify({
    title: 'Current page',
    enabled: true,
    icon: 'link',
    secondaryText: 'Page context /',
    subType: 'open_tab',
    subTypeLabel: 'Current page',
    projectPath: '',
    pagePath: '/',
  }),
};

const orbitContextEnvelope = (orbitEnabled = false) => ({
  category: 'orbit_context',
  content: JSON.stringify({ orbit_enabled: orbitEnabled }),
  metadata: '{}',
});

const expectedAdditionalContext = [expectedPageContextItem];

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/lib/utils/common_utils', () => ({
  getCookie: jest.fn(),
}));

jest.mock('~/lib/utils/local_storage', () => ({
  getStorageValue: jest.fn(() => ({ exists: false })),
  saveStorageValue: jest.fn(),
  getSessionStorageValue: jest.fn(() => ({ exists: false })),
  saveSessionStorageValue: jest.fn(),
  removeSessionStorageValue: jest.fn(),
}));

jest.mock('ee/ai/utils', () => {
  const actualUtils = jest.requireActual('ee/ai/utils');

  return {
    __esModule: true,
    ...actualUtils,
    setAgenticMode: jest.fn(),
  };
});

describe('Duo Agentic Chat State Manager', () => {
  let wrapper;
  let store;

  const actionSpies = {
    addDuoChatMessage: jest.fn((context, message) => {
      // Use the real action implementation
      storeActions.addDuoChatMessage(context, message);
    }),
    setMessages: jest.fn((context, messages = []) => {
      // Directly commit to store instead of async dispatches to avoid timing issues
      context.commit('CLEAN_MESSAGES');
      messages?.forEach((msg) => {
        storeActions.addDuoChatMessage(context, msg);
      });
    }),
    setCurrentAgent: jest.fn((context, agent) => {
      storeActions.setCurrentAgent(context, agent);
    }),
  };

  const mockRefetch = jest.fn().mockResolvedValue({});
  let mockRouter;
  let mockRoute;
  const docsUrlHost = 'docs.gitlab.com';
  const userWorkflowsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_USER_WORKFLOWS_RESPONSE);
  const contextPresetsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_CONTEXT_PRESETS_RESPONSE);
  const availableModelsQueryHandlerMock = jest
    .fn()
    .mockResolvedValue(MOCK_AI_CHAT_AVAILABLE_MODELS_RESPONSE);
  const configuredAgentsQueryMock = jest.fn().mockResolvedValue(MOCK_CONFIGURED_AGENTS_RESPONSE);
  const aiFoundationalChatAgentsQueryMock = jest
    .fn()
    .mockResolvedValue(MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE);
  const agentFlowConfigQueryMock = jest.fn().mockResolvedValue(MOCK_FLOW_CONFIG_RESPONSE);
  const flowStatusQueryMock = jest.fn().mockResolvedValue({
    data: {
      duoWorkflowWorkflows: {
        edges: [
          {
            node: {
              id: '1',
              status: 'completed',
            },
          },
        ],
      },
    },
  });
  const createWorkflowMutationMock = jest
    .fn()
    .mockResolvedValue(MOCK_CREATE_WORKFLOW_MUTATION_RESPONSE);
  const deleteWorkflowMutationMock = jest
    .fn()
    .mockResolvedValue(MOCK_DELETE_WORKFLOW_MUTATION_RESPONSE);
  const updateWebSearchMutationMock = jest
    .fn()
    .mockResolvedValue(MOCK_UPDATE_WEB_SEARCH_MUTATION_RESPONSE);
  const workflowEventsQueryMock = jest
    .fn()
    .mockResolvedValue({ data: MOCK_WORKFLOW_EVENTS_RESPONSE });
  const creditsAvailableQueryMock = jest.fn().mockResolvedValue({
    data: { gitlabCreditsAvailable: true, gitlabCreditsUnavailableReason: null },
  });

  const findDuoChat = () => wrapper.findComponent(DuoAgenticChatView);
  const findDeleteThreadModal = () => wrapper.findComponent(DuoChatDeleteThreadModal);
  const findDuoNext = () => wrapper.find('fe-island-duo-next');
  const findChatLoadingState = () => wrapper.findComponent(ChatLoadingState);
  const findCreditsExhaustedAlert = () => wrapper.findComponent(CreditsExhaustedAlert);

  const triggerStreamEvent = (eventType, data) => {
    const subscribeCalls = streamManager.subscribe.mock.calls;
    subscribeCalls.filter(([type]) => type === eventType).forEach(([, callback]) => callback(data));
  };
  const snapshotMessages = [
    { role: 'user', content: 'Cached user message', ts: 1000 },
    { role: 'assistant', content: 'Cached assistant reply', ts: 2000 },
  ];
  const threadSnapshotWithMessages = {
    v: 1,
    convoId: '456',
    lastTs: 2000,
    messages: snapshotMessages,
  };
  const threadSnapshotEmpty = null;

  const createComponent = ({
    initialState = {},
    propsData = {},
    data = {},
    apolloHandlers = [[getAiChatAvailableModels, availableModelsQueryHandlerMock]],
    provide = {},
    stubs = {},
    mountFn = shallowMountExtended,
    routeName = AGENTIC_CHAT_SHOW_ROUTE,
  } = {}) => {
    store = new Vuex.Store({
      mutations: storeMutations,
      actions: actionSpies,
      state: {
        messages: [],
        toolMessage: '',
        currentAgent: null,
        ...initialState,
      },
    });

    const apolloProvider = createMockApollo([
      [getUserWorkflows, userWorkflowsQueryHandlerMock],
      [getAiChatContextPresets, contextPresetsQueryHandlerMock],
      [getConfiguredAgents, configuredAgentsQueryMock],
      [getFoundationalChatAgents, aiFoundationalChatAgentsQueryMock],
      [getAgentFlowConfig, agentFlowConfigQueryMock],
      [getFlowStatus, flowStatusQueryMock],
      [duoWorkflowMutation, createWorkflowMutationMock],
      [deleteAgenticWorkflowMutation, deleteWorkflowMutationMock],
      [updateWebSearchMutation, updateWebSearchMutationMock],
      [getWorkflowLatestCheckpointQuery, workflowEventsQueryMock],
      [getGitlabCreditsStatusQuery, creditsAvailableQueryMock],
      ...apolloHandlers,
    ]);

    // Mirror real Vue Router: pushing a named location updates the reactive
    // $route so the route-derived multithreadedView computed re-evaluates.
    // eslint-disable-next-line no-restricted-properties
    mockRoute = Vue.observable({ name: routeName });
    mockRouter = {
      push: jest.fn((location) => {
        if (location?.name) {
          mockRoute.name = location.name;
        }
      }),
    };

    const defaultProvide = {
      chatConfiguration: {
        title: 'GitLab Duo Agentic Chat',
        isClassicAvailable: false,
        defaultProps: {
          defaultNamespaceSelected: true,
        },
      },
      activeTabData: {
        props: {
          isClassicAvailable: false,
        },
      },
      duoUiNext: false,
      ...provide,
    };

    wrapper = mountFn(DuoAgenticChatStateManager, {
      store,
      apolloProvider,
      propsData: {
        exploreAiCatalogPath: '/-/ai/catalog',
        ...propsData,
      },
      provide: defaultProvide,
      mocks: {
        $router: mockRouter,
        $route: mockRoute,
      },
      stubs,
      data() {
        return data;
      },
    });

    if (wrapper.vm.$apollo?.queries?.agenticWorkflows) {
      wrapper.vm.$apollo.queries.agenticWorkflows.refetch = mockRefetch;
    }
  };

  beforeEach(() => {
    mockRefetch.mockClear();
    loadThreadSnapshot.mockReturnValue(threadSnapshotEmpty);
    MOCK_UTILS_SETUP();
    // Reset Apollo handler mocks to default values
    createWorkflowMutationMock.mockResolvedValue(MOCK_CREATE_WORKFLOW_MUTATION_RESPONSE);
    deleteWorkflowMutationMock.mockResolvedValue(MOCK_DELETE_WORKFLOW_MUTATION_RESPONSE);
    workflowEventsQueryMock.mockResolvedValue({ data: MOCK_WORKFLOW_EVENTS_RESPONSE });
    creditsAvailableQueryMock.mockResolvedValue({
      data: { gitlabCreditsAvailable: true, gitlabCreditsUnavailableReason: null },
    });
    userWorkflowsQueryHandlerMock.mockResolvedValue(MOCK_USER_WORKFLOWS_RESPONSE);
    // In the default state, there isn't workflowId registered in session storage
    getSessionStorageValue.mockReturnValue({ exists: false, value: null });
  });

  afterEach(() => {
    if (wrapper) {
      wrapper = null;
    }
  });

  describe('clearActiveWorkflow', () => {
    it('clears the thread and resets lastProcessedMessageId', async () => {
      createComponent({
        data: {
          lastProcessedMessageId: 'message-5',
        },
      });
      await waitForPromises();

      wrapper.vm.clearActiveWorkflow();
      expect(findDuoChat().props('messages')).toEqual([]);
      expect(wrapper.vm.lastProcessedMessageId).toBe(null);
    });

    it('clears selectedAlternatives so stale selections do not leak into a new thread', async () => {
      createComponent({
        data: {
          selectedAlternatives: { 'msg-1': 1 },
        },
      });
      await waitForPromises();

      wrapper.vm.clearActiveWorkflow();
      expect(wrapper.vm.selectedAlternatives).toEqual({});
    });
  });

  describe('beforeDestroy', () => {
    it('clears the active thread when destroyed', () => {
      createComponent();

      const clearActiveWorkflowSpy = jest.spyOn(wrapper.vm, 'clearActiveWorkflow');
      wrapper.destroy();

      // Verify clearActiveWorkflow was called (which resets lastProcessedMessageId)
      expect(clearActiveWorkflowSpy).toHaveBeenCalled();
    });

    it('resets the tracker context when destroyed', () => {
      createComponent();

      const resetSpy = jest.spyOn(EventsTracker, 'reset');
      wrapper.destroy();

      expect(resetSpy).toHaveBeenCalled();
    });
  });

  describe('provide', () => {
    // The real DuoChatMessage from duo-ui injects renderGFM and calls it
    // after rendering, which is what hydrates GLQL/Mermaid code blocks
    // into live views. If the state manager stops providing renderGFM, the
    // inject falls back to a duo-ui stub and the hydrate pipeline never runs.
    it('hydrates assistant chat messages via renderGFM', async () => {
      renderGFM.mockClear();
      createComponent({ mountFn: mountExtended });
      await waitForPromises();

      store.dispatch('addDuoChatMessage', {
        role: 'assistant',
        content: 'hello',
        status: 'success',
      });
      await waitForPromises();

      expect(renderGFM).toHaveBeenCalled();
    });
  });

  describe('rendering', () => {
    describe('when Duo Chat is shown', () => {
      beforeEach(() => {
        createComponent({
          propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
        });
        createComponent();
      });

      it('renders the AgenticDuoChat component', () => {
        expect(findDuoChat().exists()).toBe(true);
      });

      it('does not render the loading state if we have an active thread with a snapshot', async () => {
        loadThreadSnapshot.mockReturnValue(threadSnapshotWithMessages);

        let resolvePromise = null;
        const pendingPromise = new Promise((resolve) => {
          resolvePromise = resolve;
        });
        workflowEventsQueryMock
          .mockResolvedValueOnce({ data: MOCK_WORKFLOW_EVENTS_RESPONSE })
          .mockReturnValueOnce(pendingPromise);

        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
        await waitForPromises();

        expect(findChatLoadingState().exists()).toBe(false);
        resolvePromise('');
      });

      it('does not render the loading state when isLoading is true but messages exist', async () => {
        // Set up initial messages
        const existingMessages = [
          { role: 'user', content: 'Hello', requestId: '1' },
          { role: 'assistant', content: 'Hi there!', requestId: '2' },
        ];

        createComponent({
          initialState: {
            messages: existingMessages,
          },
          data: {
            isLoading: true,
          },
        });

        await nextTick();

        // Loading state should not be shown because messages exist
        expect(findChatLoadingState().exists()).toBe(false);
        expect(findDuoChat().exists()).toBe(true);
      });

      it('passes isToolApprovalProcessing prop to AgenticDuoChat component', () => {
        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      });

      it('passes loading-thread-list prop to AgenticDuoChat component', async () => {
        expect(findDuoChat().props('loadingThreadList')).toBe(true);
        await waitForPromises();
        expect(findDuoChat().props('loadingThreadList')).toBe(false);
      });

      it('passes multithreading props to AgenticDuoChat component', async () => {
        await waitForPromises();

        expect(findDuoChat().props('isMultithreaded')).toBe(true);
        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.CHAT);
        expect(findDuoChat().props('threadList')).toEqual([
          {
            id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/456',
            lastUpdatedAt: '2024-01-01T00:00:00Z',
            title: 'Test workflow goal',
            aiCatalogItemVersionId: null,
            agentName: 'GitLab Duo',
            archived: false,
            stalled: false,
          },
        ]);
      });

      it('calls the user workflows GraphQL query', () => {
        expect(userWorkflowsQueryHandlerMock).toHaveBeenCalledWith({
          type: 'foundational_chat_agents',
          first: 99999,
          environment: 'WEB',
        });
      });

      it('calls the context presets GraphQL query', () => {
        expect(contextPresetsQueryHandlerMock).toHaveBeenCalledWith({
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
          url: 'http://test.host/',
          questionCount: 4,
        });
      });

      it('passes context presets to WebAgenticDuoChat component as predefinedPrompts', async () => {
        await waitForPromises();
        expect(findDuoChat().props('predefinedPrompts')).toEqual(
          MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions,
        );
      });

      describe('messageRenderers', () => {
        let matchMessage;

        beforeEach(() => {
          [{ matchMessage }] = findDuoChat().props('messageRenderers');
        });

        it('contains StartFlowToolMessage and MessageTierAccessDenied renderers', () => {
          const messageRenderers = findDuoChat().props('messageRenderers');
          expect(messageRenderers).toHaveLength(2);
          expect(messageRenderers[0].component).toBe(StartFlowToolMessage);
          expect(messageRenderers[1].component).toBe(MessageTierAccessDenied);
        });

        describe('tier_access_denied renderer', () => {
          let matchTierMessage;

          beforeEach(() => {
            matchTierMessage = findDuoChat().props('messageRenderers')[1].matchMessage;
          });

          it('returns true when message_sub_type is "tier_access_denied"', () => {
            expect(matchTierMessage({ message_sub_type: 'tier_access_denied' })).toBe(true);
          });

          it('returns false when message_sub_type is a different value', () => {
            expect(matchTierMessage({ message_sub_type: 'start_flow' })).toBe(false);
          });

          it('returns false when message_sub_type is undefined', () => {
            expect(matchTierMessage({ message_sub_type: undefined })).toBe(false);
          });
        });

        describe('tier_access_denied renderer defaultProps', () => {
          it('forwards the message and the isHandRaiseLeadAvailable prop', () => {
            createComponent({ propsData: { isHandRaiseLeadAvailable: true } });

            const { defaultProps } = findDuoChat().props('messageRenderers')[1];
            const message = { message_sub_type: 'tier_access_denied' };

            expect(defaultProps(message)).toEqual({
              message,
              isHandRaiseLeadAvailable: true,
            });
          });
        });

        const startFlowMessage = (content) => ({
          message_sub_type: 'start_flow',
          tool_info: { tool_response: { content } },
        });

        it('returns true when content is a JSON object with flow_name, status, and workflow_id', () => {
          expect(matchMessage(MOCK_START_FLOW_TOOL_MESSAGE)).toBe(true);
        });

        it('returns false when message_sub_type is not start_flow', () => {
          expect(matchMessage({ message_sub_type: 'other' })).toBe(false);
          expect(matchMessage({ message_sub_type: undefined })).toBe(false);
        });

        it('returns false when content is null', () => {
          expect(matchMessage(startFlowMessage(null))).toBe(false);
        });

        it('returns false when content is not valid JSON', () => {
          expect(matchMessage(startFlowMessage('not json'))).toBe(false);
        });

        it('returns false when content is a JSON primitive, not an object', () => {
          expect(matchMessage(startFlowMessage('"a string"'))).toBe(false);
          expect(matchMessage(startFlowMessage('42'))).toBe(false);
        });

        it('returns false when content is missing flow_name', () => {
          expect(
            matchMessage(startFlowMessage(JSON.stringify({ status: 'started', workflow_id: 1 }))),
          ).toBe(false);
        });

        it('returns false when content is missing status', () => {
          expect(
            matchMessage(startFlowMessage(JSON.stringify({ flow_name: 'fix/v1', workflow_id: 1 }))),
          ).toBe(false);
        });

        it('returns false when content is missing workflow_id', () => {
          expect(
            matchMessage(
              startFlowMessage(JSON.stringify({ flow_name: 'fix/v1', status: 'started' })),
            ),
          ).toBe(false);
        });

        it('returns false when tool_info is absent', () => {
          expect(matchMessage({ message_sub_type: 'start_flow' })).toBe(false);
        });
      });
    });
  });

  describe('chat mode on mount', () => {
    let hydrateActiveWorkflowSpy;
    let onNewChatSpy;

    beforeEach(() => {
      hydrateActiveWorkflowSpy = jest.spyOn(
        DuoAgenticChatStateManager.methods,
        'hydrateActiveWorkflow',
      );
      onNewChatSpy = jest.spyOn(DuoAgenticChatStateManager.methods, 'onNewChat');
    });

    it('loads chat in "active" mode by default', async () => {
      createComponent();
      await waitForPromises();
      expect(wrapper.props('mode')).toBe('active');
    });

    describe('when there is no active thread', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('loads the new chat', () => {
        expect(onNewChatSpy).toHaveBeenCalled();
      });

      it('does not hydrate the active thread', () => {
        expect(hydrateActiveWorkflowSpy).not.toHaveBeenCalled();
      });

      it('does not display old thread messages', () => {
        expect(findDuoChat().props('messages')).toEqual([]);
      });
    });

    describe('when there is an active thread', () => {
      beforeEach(async () => {
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);
        createComponent({
          data: {
            workflowId: MOCK_WORKFLOW_ID,
          },
        });
        await waitForPromises();
      });

      it('hydrates the active thread', () => {
        expect(hydrateActiveWorkflowSpy).toHaveBeenCalled();
      });

      it('does not load a new chat', () => {
        expect(onNewChatSpy).not.toHaveBeenCalled();
      });

      it('sets the last processed message id based on the thread messages', () => {
        expect(wrapper.vm.lastProcessedMessageId).toBe(
          MOCK_TRANSFORMED_MESSAGES[MOCK_TRANSFORMED_MESSAGES.length - 1].message_id,
        );
      });
    });
  });

  describe('Workflow deletion handling', () => {
    it('shows error when sending message to workflow deleted in different instance', async () => {
      createComponent({
        initialState: { messages: [{ role: 'user', content: 'test' }] },
        data: { isInititalLoad: false },
      });
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(wrapper.vm.workflowId).toBe(MOCK_WORKFLOW_ID);

      workflowEventsQueryMock.mockRejectedValue({
        graphQLErrors: [
          { message: 'Workflow not found', extensions: { code: 'WORKFLOW_NOT_FOUND' } },
        ],
      });

      findDuoChat().vm.$emit('send-chat-prompt', 'Follow-up question');
      await waitForPromises();
      expect(findDuoChat().props('isChatAvailable')).toBe(false);
      expect(findDuoChat().props('error')).toBe('This chat was deleted.');
    });

    it('starts new chat when loading with deleted workflow after page reload', async () => {
      getSessionStorageValue.mockReturnValueOnce({
        exists: true,
        value: { workflowId: MOCK_WORKFLOW_ID },
      });

      workflowEventsQueryMock.mockRejectedValue({
        graphQLErrors: [
          { message: 'Workflow not found', extensions: { code: 'WORKFLOW_NOT_FOUND' } },
        ],
      });

      createComponent();
      await waitForPromises();

      expect(findDuoChat().props('messages')).toHaveLength(0);
    });

    it('shows error when navigating to deleted workflow from history in same instance', async () => {
      workflowEventsQueryMock.mockRejectedValue({
        graphQLErrors: [
          { message: 'Workflow not found', extensions: { code: 'WORKFLOW_NOT_FOUND' } },
        ],
      });

      createComponent({ data: { workflowId: MOCK_WORKFLOW_ID } });
      await waitForPromises();

      expect(findDuoChat().props('messages')).toHaveLength(0);
    });

    it('displays generic error for non-deletion errors', async () => {
      getSessionStorageValue.mockReturnValueOnce({
        exists: true,
        value: { workflowId: MOCK_WORKFLOW_ID },
      });

      const errorText = 'Network timeout occurred';
      workflowEventsQueryMock.mockRejectedValue(new Error(errorText));

      createComponent();
      await waitForPromises();

      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });

    it('clears the workflow thread snapshot when workflow is deleted', async () => {
      getSessionStorageValue.mockReturnValueOnce({
        exists: true,
        value: { workflowId: MOCK_WORKFLOW_ID },
      });

      workflowEventsQueryMock.mockRejectedValue({
        graphQLErrors: [
          { message: 'Workflow not found', extensions: { code: 'WORKFLOW_NOT_FOUND' } },
        ],
      });

      createComponent();
      await waitForPromises();

      expect(clearThreadSnapshot).toHaveBeenCalledWith(MOCK_WORKFLOW_ID);
    });

    it('shows no namespace empty state when NO_DEFAULT_NAMESPACE error is returned', async () => {
      workflowEventsQueryMock.mockRejectedValue({
        graphQLErrors: [
          {
            message:
              "You don't have permission to access this workflow. Please select a default namespace.",
            extensions: { code: 'NO_DEFAULT_NAMESPACE' },
          },
        ],
      });

      createComponent({ data: { workflowId: MOCK_WORKFLOW_ID } });
      await waitForPromises();

      expect(wrapper.findComponent(NoNamespaceEmptyState).exists()).toBe(true);
    });
  });

  describe('events handling', () => {
    beforeEach(() => {
      createComponent({
        propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
      });
    });

    describe('@send-chat-prompt', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      it.each([GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'resets chat state when "%s" command is sent',
        async (command) => {
          createComponent();
          wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

          findDuoChat().vm.$emit('send-chat-prompt', command);
          await nextTick();

          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(findChatLoadingState().exists()).toBe(false);
          expect(findDuoChat().props('isLoading')).toBe(false);
        },
      );

      it('creates a new workflow when sending a prompt for the first time with projectId', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(createWorkflowMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            projectId: MOCK_PROJECT_ID,
            goal: MOCK_USER_MESSAGE.content,
          }),
        );

        expect(WorkflowSocketUtils.buildWebsocketUrl).toHaveBeenCalledWith({
          rootNamespaceId: null,
          namespaceId: null,
          projectId: MOCK_PROJECT_ID,
          userModelSelectionEnabled: false,
          currentModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          defaultModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          aiCatalogItemVersionId: '',
          workflowDefinition: undefined,
          workflowId: '456',
        });

        expect(streamManager.connect).toHaveBeenCalledWith(
          '/api/v4/ai/duo_workflows/ws',
          expect.any(Object),
        );

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith({
          workflowId: '456',
          workflowDefinition: undefined,
          goal: MOCK_USER_MESSAGE.content,
          approval: {},
          additionalContext: expectedAdditionalContext,
          agentConfig: null,
          flowConfig: null,
          metadata: null,
          clientCapabilities: ['incremental_streaming', 'web_search'],
          orbitEnabled: false,
          isRetry: false,
          selectedRegenerateMessageId: null,
        });

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
            role: 'user',
            requestId: DUO_AGENTIC_CHAT_PENDING_USER_MESSAGE_ID,
          }),
        );
      });

      it.each([true, false])(
        'creates the workflow with the web search preference the user selected (%s)',
        async (webSearchEnabled) => {
          findDuoChat().vm.$emit('web-search-toggled', webSearchEnabled);
          await waitForPromises();

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(createWorkflowMutationMock).toHaveBeenCalledWith(
            expect.objectContaining({ webSearchEnabled }),
          );
        },
      );

      it('includes orbit_context envelope with orbit_enabled: true when a foundational agent is selected and orbitEnabled is true', async () => {
        createComponent({
          data: { orbitEnabled: true, selectedFoundationalAgent: MOCK_FETCHED_FOUNDATIONAL_AGENT },
          initialState: { currentAgent: MOCK_FETCHED_FOUNDATIONAL_AGENT },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
          expect.objectContaining({
            additionalContext: expect.arrayContaining([
              {
                category: 'orbit_context',
                content: JSON.stringify({ orbit_enabled: true }),
                metadata: '{}',
              },
            ]),
          }),
        );
      });

      it('does not include orbit_context envelope when no foundational agent is selected', async () => {
        createComponent({ data: { orbitEnabled: true } });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        const [call] = WorkflowSocketUtils.buildStartRequest.mock.calls;
        const { additionalContext } = call[0];

        expect(additionalContext.filter((c) => c.category === 'orbit_context')).toHaveLength(0);
      });

      it('replaces a caller-supplied orbit_context envelope with the authoritative value when a foundational agent is selected', async () => {
        createComponent({
          data: { orbitEnabled: true, selectedFoundationalAgent: MOCK_FETCHED_FOUNDATIONAL_AGENT },
          initialState: { currentAgent: MOCK_FETCHED_FOUNDATIONAL_AGENT },
        });
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        wrapper.vm.startWorkflow({
          goal: MOCK_USER_MESSAGE.content,
          approval: {},
          additionalContext: [orbitContextEnvelope(false)],
        });
        await waitForPromises();

        const [call] = WorkflowSocketUtils.buildStartRequest.mock.calls;
        const { additionalContext } = call[0];
        const orbitEnvelopes = additionalContext.filter((c) => c.category === 'orbit_context');

        expect(orbitEnvelopes).toHaveLength(1);
        expect(orbitEnvelopes[0].content).toBe(JSON.stringify({ orbit_enabled: true }));
      });

      it('includes commandAdditionalContext envelopes (e.g. form_context) from openDuoChatWithAgent', async () => {
        const formContextEnvelope = {
          category: 'form_context',
          content: JSON.stringify({ form_id: 'ask-duo-pat' }),
          metadata: '{}',
        };
        duoChatGlobalState.commands = [
          {
            agent: { name: 'Permissions Assistant' },
            resourceId: '1',
            autoSend: false,
            additionalContext: [formContextEnvelope],
          },
        ];
        await waitForPromises();

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        const [call] = WorkflowSocketUtils.buildStartRequest.mock.calls;
        const { additionalContext } = call[0];

        expect(additionalContext).toEqual(expect.arrayContaining([formContextEnvelope]));
      });

      it('commandAdditionalContext takes precedence over caller-supplied envelopes with the same category', async () => {
        const sessionFormContext = {
          category: 'form_context',
          content: JSON.stringify({ form_id: 'session-form' }),
          metadata: '{}',
        };
        const perMessageFormContext = {
          category: 'form_context',
          content: JSON.stringify({ form_id: 'per-message-form' }),
          metadata: '{}',
        };
        // Per-message context is gathered from the system context providers on each send.
        jest
          .spyOn(SystemContextManager.prototype, 'getSystemContextItems')
          .mockResolvedValue([perMessageFormContext]);
        duoChatGlobalState.commands = [
          {
            agent: { name: 'Permissions Assistant' },
            resourceId: '1',
            autoSend: false,
            additionalContext: [sessionFormContext],
          },
        ];
        await waitForPromises();

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        const [call] = WorkflowSocketUtils.buildStartRequest.mock.calls;
        const { additionalContext } = call[0];
        const formEnvelopes = additionalContext.filter((c) => c.category === 'form_context');

        expect(formEnvelopes).toEqual([sessionFormContext]);
      });

      describe('external context providers', () => {
        const EXTERNAL_CATEGORY = 'permissions_form_context';
        let disposeProvider;

        afterEach(() => {
          disposeProvider?.();
        });

        it('injects registered external context, read fresh on each send', async () => {
          let contentObj = { namespace: ['read_project'] };
          disposeProvider = registerExternalContextProvider(EXTERNAL_CATEGORY, () => contentObj);

          createComponent({
            initialState: { currentAgent: MOCK_FETCHED_FOUNDATIONAL_AGENT },
          });

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
            expect.objectContaining({
              additionalContext: expect.arrayContaining([
                {
                  category: EXTERNAL_CATEGORY,
                  content: JSON.stringify(contentObj),
                  metadata: '{}',
                },
              ]),
            }),
          );

          // A later send must reflect the updated state, not the first snapshot.
          contentObj = { namespace: ['read_project', 'write_project'] };
          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          const lastCall = WorkflowSocketUtils.buildStartRequest.mock.calls.at(-1)[0];
          const injected = lastCall.additionalContext.find((c) => c.category === EXTERNAL_CATEGORY);

          expect(injected.content).toBe(JSON.stringify(contentObj));
        });
      });

      describe('agenticChatFlowRegistryMigration feature flag', () => {
        it('passes flowConfig with agentic_chat registry values when flag is enabled', async () => {
          createComponent({
            provide: {
              glFeatures: { agenticChatFlowRegistryMigration: true },
            },
          });

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
            expect.objectContaining({
              flowConfig: {
                flowConfigId: 'agentic_chat',
                flowVersion: '1.0.0',
                flowConfigSchemaVersion: 'v1',
              },
            }),
          );
        });

        it('passes flowConfig as null when flag is disabled', async () => {
          createComponent({
            provide: {
              glFeatures: { agenticChatFlowRegistryMigration: false },
            },
          });

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
            expect.objectContaining({ flowConfig: null }),
          );
        });

        it('passes flowConfig as null when flag is enabled but agentConfig is set', async () => {
          createComponent({
            provide: {
              glFeatures: { agenticChatFlowRegistryMigration: true },
            },
          });
          await waitForPromises();

          wrapper.vm.agentConfig = 'version: v1\nflowConfigId: custom_agent\nflowVersion: 1.0.0';

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
            expect.objectContaining({ flowConfig: null }),
          );
        });

        it('passes the selected agent flowConfig when the migration flag is disabled', async () => {
          createComponent({
            provide: {
              glFeatures: { agenticChatFlowRegistryMigration: false },
            },
          });
          await waitForPromises();

          wrapper.vm.selectedFoundationalAgent = {
            ...DUO_CHAT_AGENT_MOCK,
            flowConfig: {
              flowConfigId: 'chat',
              flowConfigSchemaVersion: null,
              flowVersion: '^1.0.0',
            },
          };

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
            expect.objectContaining({
              flowConfig: {
                flowConfigId: 'chat',
                flowConfigSchemaVersion: null,
                flowVersion: '^1.0.0',
              },
            }),
          );
        });

        it('does not overwrite a non-chat foundational agent flowConfig when the migration flag is enabled', async () => {
          createComponent({
            provide: {
              glFeatures: { agenticChatFlowRegistryMigration: true },
            },
          });
          await waitForPromises();

          wrapper.vm.selectedFoundationalAgent = {
            id: 'gid://gitlab/Ai::FoundationalChatAgent/duo_permissions_assistant-v1',
            name: 'Permissions Assistant',
            referenceWithVersion: 'duo_permissions_assistant/v1',
            flowConfig: {
              flowConfigId: 'duo_permissions_assistant',
              flowConfigSchemaVersion: 'v1',
              flowVersion: '^1.0.0',
            },
          };

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
            expect.objectContaining({
              flowConfig: {
                flowConfigId: 'duo_permissions_assistant',
                flowConfigSchemaVersion: 'v1',
                flowVersion: '^1.0.0',
              },
            }),
          );
        });

        it('keeps an explicitly selected chat agent on its own flow when the migration flag is enabled', async () => {
          createComponent({
            provide: {
              glFeatures: { agenticChatFlowRegistryMigration: true },
            },
          });
          await waitForPromises();

          wrapper.vm.selectedFoundationalAgent = {
            ...DUO_CHAT_AGENT_MOCK,
            flowConfig: {
              flowConfigId: 'chat',
              flowConfigSchemaVersion: null,
              flowVersion: '^1.0.0',
            },
          };

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
            expect.objectContaining({
              flowConfig: {
                flowConfigId: 'chat',
                flowConfigSchemaVersion: null,
                flowVersion: '^1.0.0',
              },
            }),
          );
        });
      });

      it('creates a new workflow when sending a prompt for the first time with namespaceId', async () => {
        createComponent({
          propsData: { namespaceId: MOCK_NAMESPACE_ID, resourceId: MOCK_RESOURCE_ID },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(createWorkflowMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            namespaceId: MOCK_NAMESPACE_ID,
            goal: MOCK_USER_MESSAGE.content,
          }),
        );

        expect(WorkflowSocketUtils.buildWebsocketUrl).toHaveBeenCalledWith({
          rootNamespaceId: null,
          namespaceId: MOCK_NAMESPACE_ID,
          projectId: null,
          userModelSelectionEnabled: false,
          currentModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          defaultModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          aiCatalogItemVersionId: '',
          workflowDefinition: undefined,
          workflowId: '456',
        });

        expect(streamManager.connect).toHaveBeenCalledWith(
          '/api/v4/ai/duo_workflows/ws',
          expect.any(Object),
        );

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
            role: 'user',
            requestId: DUO_AGENTIC_CHAT_PENDING_USER_MESSAGE_ID,
          }),
        );
      });

      it('creates a new workflow when sending a prompt for the first time with both projectId and namespaceId', async () => {
        createComponent({
          propsData: {
            projectId: MOCK_PROJECT_ID,
            namespaceId: MOCK_NAMESPACE_ID,
            resourceId: MOCK_RESOURCE_ID,
          },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(createWorkflowMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            projectId: MOCK_PROJECT_ID,
            namespaceId: MOCK_NAMESPACE_ID,
            goal: MOCK_USER_MESSAGE.content,
          }),
        );
      });

      it('creates a new workflow when sending a prompt for the first time without projectId or namespaceId', async () => {
        createComponent({
          propsData: { resourceId: MOCK_RESOURCE_ID },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(createWorkflowMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            goal: MOCK_USER_MESSAGE.content,
          }),
        );
        expect(createWorkflowMutationMock).toHaveBeenCalledWith(
          expect.not.objectContaining({ projectId: expect.anything() }),
        );
      });

      it('creates a new workflow with aiCatalogItemVersionId when catalog agent is selected', async () => {
        const mockCatalogItemVersionId = 'gid://gitlab/Ai::Catalog::ItemVersion/100';
        createComponent({
          propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
        });
        wrapper.vm.aiCatalogItemVersionId = mockCatalogItemVersionId;

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(createWorkflowMutationMock).toHaveBeenCalledWith(
          expect.objectContaining({
            projectId: MOCK_PROJECT_ID,
            goal: MOCK_USER_MESSAGE.content,
            aiCatalogItemVersionId: mockCatalogItemVersionId,
          }),
        );

        expect(WorkflowSocketUtils.buildWebsocketUrl).toHaveBeenCalledWith({
          rootNamespaceId: null,
          namespaceId: null,
          projectId: MOCK_PROJECT_ID,
          userModelSelectionEnabled: false,
          currentModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          defaultModel: MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          aiCatalogItemVersionId: mockCatalogItemVersionId,
          workflowDefinition: undefined,
          workflowId: '456',
        });
      });

      it('sets waiting on prompt to true when sending a prompt', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await nextTick();

        expect(findDuoChat().props('isLoading')).toBe(true);
      });

      it('does not create a new workflow if one already exists', async () => {
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;
        createWorkflowMutationMock.mockClear();

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(createWorkflowMutationMock).not.toHaveBeenCalled();
        expect(streamManager.connect).toHaveBeenCalled();
      });

      it('connects to WebSocket and sends start request', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(streamManager.connect).toHaveBeenCalled();
      });

      it('adds user message with pending requestId immediately before async operations', async () => {
        findDuoChat().vm.$emit('send-chat-prompt', 'Test question');
        await nextTick();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: 'Test question',
            role: 'user',
            requestId: DUO_AGENTIC_CHAT_PENDING_USER_MESSAGE_ID,
          }),
        );
      });

      it('tracks submit message event with trial label when on trial', async () => {
        createComponent({
          propsData: { trialActive: true, isTrial: true },
        });
        await waitForPromises();

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        findDuoChat().vm.$emit('send-chat-prompt', 'Test question');
        await waitForPromises();

        expect(trackEventSpy).toHaveBeenCalledWith(
          'submit_dap_trial_or_paid_empty_state_message',
          { label: 'trial' },
          undefined,
        );
      });

      it('tracks submit message event with paid label when on paid subscription', async () => {
        createComponent({
          propsData: { subscriptionActive: true, isTrial: false },
        });
        await waitForPromises();

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        findDuoChat().vm.$emit('send-chat-prompt', 'Test question');
        await waitForPromises();

        expect(trackEventSpy).toHaveBeenCalledWith(
          'submit_dap_trial_or_paid_empty_state_message',
          { label: 'paid' },
          undefined,
        );
      });

      it('does not track submit message event when shouldShowActiveTrialOrSubscriptionEmptyState is false', async () => {
        createComponent({
          propsData: { trialActive: false },
        });
        await waitForPromises();

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

        findDuoChat().vm.$emit('send-chat-prompt', 'Test question');
        await waitForPromises();

        expect(trackEventSpy).not.toHaveBeenCalledWith(
          'submit_dap_trial_or_paid_empty_state_message',
        );
      });

      describe('tracks event with the correct properties', () => {
        let trackEventSpy;

        beforeEach(() => {
          createComponent({
            propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
          });
          ({ trackEventSpy } = bindInternalEventDocument(wrapper.element));
        });

        it('tracks event with foundational agent properties when foundational agent is selected', async () => {
          const mockFoundationalAgent = {
            id: 'gid://gitlab/Ai::FoundationalChatAgent/security_analyst',
            name: 'Security Analyst',
            reference: 'security_analyst',
            referenceWithVersion: 'security_analyst/v1',
            version: 'v1',
            foundational: true,
            tools: [{ name: 'create_issue' }, { name: 'get_merge_request' }],
            flowConfig: { flowVersion: '1.2.0' },
          };

          await findDuoChat().vm.$emit('new-chat', mockFoundationalAgent);
          await waitForPromises();

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(trackEventSpy).toHaveBeenCalledWith(
            CHAT_TRACKING_EVENT,
            {
              label: 'foundational_agent',
              property: 'chat',
              value: null,
              foundational_item_ref: 'security_analyst',
              item_type: 'foundational_agent',
              item_version: '1.2.0',
              item_schema_version: 'v1',
              flow_name: 'chat',
              component_name: 'security_analyst',
              tools: 'create_issue,get_merge_request',
            },
            undefined,
          );
        });

        it('tracks event with catalog agent properties when catalog agent is selected', async () => {
          const mockCatalogAgent = {
            id: 'gid://gitlab/Ai::Catalog::Item/1',
            name: 'Test Catalog Agent',
            itemType: 'AGENT',
            foundational: false,
            latestVersion: { versionName: '1.0.0' },
            pinnedItemVersionId: 'gid://gitlab/Ai::Catalog::ItemVersion/100',
            pinnedItemVersion: {
              versionName: '2.0.0',
              tools: { nodes: [{ name: 'read_file' }, { name: 'grep' }] },
              mcpTools: ['search'],
            },
          };

          await findDuoChat().vm.$emit('new-chat', mockCatalogAgent);
          await waitForPromises();

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(trackEventSpy).toHaveBeenCalledWith(
            CHAT_TRACKING_EVENT,
            {
              label: 'agent',
              property: 'chat',
              value: 100,
              foundational_item_ref: null,
              item_type: 'custom_agent',
              custom_item_id: 1,
              item_version: '2.0.0',
              item_schema_version: 'v1',
              tools: 'read_file,grep',
              mcp_tools: 'search',
            },
            undefined,
          );
        });

        it('does not track event when neither foundational nor catalog agent is selected', async () => {
          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          expect(trackEventSpy).not.toHaveBeenCalled();
        });
      });
    });

    describe('WebSocket message handling', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;
        actionSpies.addDuoChatMessage.mockReset();
      });

      it('processes messages from the WebSocket and updates the UI', async () => {
        const checkpointData = {
          requestID: 'request-id-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  { content: 'Hello, how can I help?', message_type: 'agent' },
                  {
                    content: 'I can assist with optimizing your CI pipeline.',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: 'completed',
            goal: 'Test goal for activeThread',
          },
        };
        const mockEvent = { type: 'message', data: JSON.stringify(checkpointData) };

        triggerStreamEvent('message', mockEvent);
        await waitForPromises();

        expect(WorkflowSocketUtils.processWorkflowMessage).toHaveBeenCalledWith(mockEvent, null);

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.any(Object),
          MOCK_TRANSFORMED_MESSAGES.at(-1),
        );
      });

      it('handles tool approval flow', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'I need to run a command.',
                    message_type: 'assistant',
                    tool_info: {
                      name: 'run_command',
                      args: { command: 'ls -la' },
                    },
                  },
                ],
              },
            }),
            status: 'TOOL_CALL_APPROVAL_REQUIRED',
          },
        };

        triggerStreamEvent('message', {
          type: 'message',
          data: JSON.stringify(mockCheckpointData),
        });
        await waitForPromises();
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      });

      it('sets waiting on prompt to false when workflow status is INPUT_REQUIRED', async () => {
        const mockCheckpointData = {
          requestID: 'request-id-4',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Please provide more information',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
          },
        };

        triggerStreamEvent('message', {
          type: 'message',
          data: JSON.stringify(mockCheckpointData),
        });
        await waitForPromises();

        expect(findDuoChat().props('isLoading')).toBe(false);
      });

      it('handles errors from WebSocket', () => {
        triggerStreamEvent('error', { type: 'error', origin: 'decode', message: 'read failed' });

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: ['Error: Unable to connect to workflow service. Please try again.'],
          }),
        );
        expect(captureExceptionForDuoChat).toHaveBeenCalledWith(
          expect.objectContaining({
            message: 'Unable to connect to workflow service. Please try again.',
          }),
          { extra: { type: 'error', origin: 'decode', message: 'read failed' } },
        );
      });
    });

    describe('Race condition prevention in message processing', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;
        actionSpies.addDuoChatMessage.mockReset();
      });

      it('prevents concurrent processing of messages', async () => {
        const createMockEvent = (messageContent) => ({
          type: 'message',
          data: JSON.stringify({
            requestID: 'request-id-race',
            newCheckpoint: {
              checkpoint: JSON.stringify({
                channel_values: {
                  ui_chat_log: [{ content: messageContent, message_type: 'agent' }],
                },
              }),
              status: 'running',
            },
          }),
        });

        // Set up processWorkflowMessage to return proper data
        WorkflowSocketUtils.processWorkflowMessage
          .mockResolvedValueOnce({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-0',
          })
          .mockResolvedValueOnce({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-1',
          });

        // Fire two events rapidly (simulating race condition)
        triggerStreamEvent('message', createMockEvent('First message'));
        triggerStreamEvent('message', createMockEvent('Second message'));

        // Wait for all processing to complete
        await waitForPromises();
        await nextTick();

        // Verify processWorkflowMessage was called sequentially, not concurrently
        // First call should have null, second should have updated message id
        expect(WorkflowSocketUtils.processWorkflowMessage).toHaveBeenNthCalledWith(
          1,
          expect.anything(),
          null,
        );
        expect(WorkflowSocketUtils.processWorkflowMessage).toHaveBeenNthCalledWith(
          2,
          expect.anything(),
          'message-0', // Uses updated lastProcessedMessageId from first call
        );
      });

      it('processes the final event when multiple events arrive rapidly', async () => {
        const createMockEvent = (id, messageContent) => ({
          type: 'message',
          data: JSON.stringify({
            requestID: `request-id-${id}`,
            newCheckpoint: {
              checkpoint: JSON.stringify({
                channel_values: {
                  ui_chat_log: [{ content: messageContent, message_type: 'agent' }],
                },
              }),
              status: 'running',
            },
          }),
        });

        // Mock processWorkflowMessage to resolve with different data
        WorkflowSocketUtils.processWorkflowMessage.mockImplementation(() =>
          Promise.resolve({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-0',
          }),
        );

        // Fire multiple events rapidly - only first and last should be processed
        triggerStreamEvent('message', createMockEvent(1, 'Message 1'));
        triggerStreamEvent('message', createMockEvent(2, 'Message 2'));
        triggerStreamEvent('message', createMockEvent(3, 'Message 3'));
        triggerStreamEvent('message', createMockEvent(4, 'Final message'));

        await waitForPromises();
        await nextTick();

        // Should process at least 2 messages: first one that started immediately,
        // and the last one that was pending
        expect(WorkflowSocketUtils.processWorkflowMessage).toHaveBeenCalled();
        // The final event should have been processed
        const lastCall =
          WorkflowSocketUtils.processWorkflowMessage.mock.calls[
            WorkflowSocketUtils.processWorkflowMessage.mock.calls.length - 1
          ];
        // Verify the last event was processed (request-id-4)
        expect(lastCall[0].data).toBeDefined();
      });

      it('maintains correct lastProcessedMessageId across sequential processing', async () => {
        const createMockEvent = (index) => ({
          type: 'message',
          data: JSON.stringify({
            requestID: `request-id-${index}`,
            newCheckpoint: {
              checkpoint: JSON.stringify({
                channel_values: {
                  ui_chat_log: [
                    {
                      content: `Message ${index}`,
                      message_type: 'agent',
                      message_id: `message-${index}`,
                    },
                  ],
                },
              }),
              status: 'running',
            },
          }),
        });

        // Mock to return incrementing lastProcessedMessageId
        WorkflowSocketUtils.processWorkflowMessage
          .mockResolvedValueOnce({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-0',
          })
          .mockResolvedValueOnce({
            messages: [MOCK_TRANSFORMED_MESSAGES[0]],
            status: 'running',
            lastProcessedMessageId: 'message-1',
          });

        // Send two events
        triggerStreamEvent('message', createMockEvent(1));
        await waitForPromises();

        triggerStreamEvent('message', createMockEvent(2));
        await waitForPromises();

        // Verify the message id was properly updated and passed
        expect(wrapper.vm.lastProcessedMessageId).toBe('message-1');
      });

      it('clears processing state when cleanupState is called', () => {
        const mockEvent = {
          type: 'message',
          data: JSON.stringify({
            requestID: 'request-id-cleanup',
            newCheckpoint: {
              checkpoint: JSON.stringify({
                channel_values: { ui_chat_log: [] },
              }),
              status: 'running',
            },
          }),
        };

        WorkflowSocketUtils.processWorkflowMessage.mockResolvedValue({
          messages: [],
          status: 'running',
          lastProcessedMessageId: 'message-0',
        });

        // Start processing
        triggerStreamEvent('message', mockEvent);
        expect(wrapper.vm.isProcessingMessage).toBe(true);

        // Call cleanup
        wrapper.vm.cleanupState();

        expect(wrapper.vm.isProcessingMessage).toBe(false);
        expect(wrapper.vm.pendingEvent).toBe(null);
      });
    });

    describe('@chat-cancel', () => {
      it('cancels the active connection, does not reset the workflowID', async () => {
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        findDuoChat().vm.$emit('chat-cancel');
        await nextTick();

        expect(streamManager.disconnect).toHaveBeenCalled();

        expect(findChatLoadingState().exists()).toBe(false);
        expect(findDuoChat().props('isLoading')).toBe(false);
        expect(wrapper.vm.workflowId).toBe(MOCK_WORKFLOW_ID);
      });
    });

    describe('@new-chat', () => {
      it('resets chat state for new conversation', async () => {
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(wrapper.vm.workflowId).toBe(null);
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
        expect(findChatLoadingState().exists()).toBe(false);
        expect(findDuoChat().props('isLoading')).toBe(false);
        expect(streamManager.disconnect).toHaveBeenCalled();
      });
      it('clears the active thread', async () => {
        const clearActiveWorkflowSpy = jest.spyOn(wrapper.vm, 'clearActiveWorkflow');

        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(clearActiveWorkflowSpy).toHaveBeenCalled();
      });
      it('clears archived thread state when starting a new chat', async () => {
        findDuoChat().vm.$emit('thread-selected', {
          id: MOCK_WORKFLOW_ID,
          archived: true,
        });
        await nextTick();

        expect(getInstanceSlots(findDuoChat().vm)['custom-empty-state']({})).toBeDefined();

        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(getInstanceSlots(findDuoChat().vm)['custom-empty-state']).toBeUndefined();
      });
    });

    describe('@approve-tool', () => {
      beforeEach(() => {
        createComponent();
      });

      it('handles tool approval via chat component event and updates processing state through workflow', async () => {
        await waitForPromises();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);

        findDuoChat().vm.$emit('approve-tool');
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith({
          workflowId: '456',
          workflowDefinition: undefined,
          goal: '',
          approval: { approval: {} },
          additionalContext: [],
          agentConfig: null,
          flowConfig: null,
          metadata: null,
          clientCapabilities: ['incremental_streaming', 'web_search'],
          orbitEnabled: false,
          isRetry: false,
          selectedRegenerateMessageId: null,
        });

        expect(streamManager.connect).toHaveBeenCalled();

        const mockApprovalRequiredData = {
          requestID: 'request-id-approval-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'I need approval to execute this tool',
                    message_type: 'assistant',
                    tool_info: {
                      name: 'some_tool',
                      args: { param: 'value' },
                    },
                  },
                ],
              },
            }),
            status: 'TOOL_CALL_APPROVAL_REQUIRED',
          },
        };

        triggerStreamEvent('message', {
          type: 'message',
          data: JSON.stringify(mockApprovalRequiredData),
        });
        await waitForPromises();
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);

        const mockCompletedData = {
          requestID: 'request-id-approval-2',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Tool execution completed',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: 'completed',
          },
        };

        triggerStreamEvent('message', {
          type: 'message',
          data: JSON.stringify(mockCompletedData),
        });
        await waitForPromises();
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      });

      it('calls EventsTracker.trackApproveTool with tool name from last message', async () => {
        await waitForPromises();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        store.commit('ADD_MESSAGE', {
          message_type: 'request',
          role: 'assistant',
          requestId: 'req-tracking-1',
          tool_info: { name: 'some_tool', args: {} },
          content: 'Tool requires approval',
        });

        findDuoChat().vm.$emit('approve-tool');
        await nextTick();

        expect(EventsTracker.trackApproveTool).toHaveBeenCalledWith({
          toolName: 'some_tool',
        });
      });
    });

    describe('@deny-tool', () => {
      beforeEach(() => {
        createComponent();
      });

      it('handles tool denial via chat component event with message and updates processing state', async () => {
        await waitForPromises();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;
        const denyMessage = 'I do not approve this action';

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);

        findDuoChat().vm.$emit('deny-tool', denyMessage);
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith({
          workflowId: '456',
          workflowDefinition: undefined,
          goal: '',
          approval: {
            approval: undefined,
            rejection: { message: denyMessage },
          },
          additionalContext: [],
          agentConfig: null,
          flowConfig: null,
          metadata: null,
          clientCapabilities: ['incremental_streaming', 'web_search'],
          orbitEnabled: false,
          isRetry: false,
          selectedRegenerateMessageId: null,
        });

        expect(streamManager.connect).toHaveBeenCalled();

        const mockApprovalRequiredData = {
          requestID: 'request-id-denial-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Tool approval was required',
                    message_type: 'assistant',
                    tool_info: {
                      name: 'some_tool',
                      args: { param: 'value' },
                    },
                  },
                ],
              },
            }),
            status: 'TOOL_CALL_APPROVAL_REQUIRED',
          },
        };

        triggerStreamEvent('message', {
          type: 'message',
          data: JSON.stringify(mockApprovalRequiredData),
        });
        await waitForPromises();
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);

        const mockDenialProcessedData = {
          requestID: 'request-id-denial-2',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [
                  {
                    content: 'Tool execution denied, proceeding with alternative approach',
                    message_type: 'agent',
                  },
                ],
              },
            }),
            status: 'processing',
          },
        };

        triggerStreamEvent('message', {
          type: 'message',
          data: JSON.stringify(mockDenialProcessedData),
        });
        await waitForPromises();
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      });

      it('handles tool denial via chat component event with event object and updates processing state', async () => {
        await waitForPromises();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;
        const eventObject = { message: 'I do not approve this action' };

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);

        findDuoChat().vm.$emit('deny-tool', eventObject);
        await nextTick();

        expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

        expect(streamManager.connect).toHaveBeenCalled();
      });

      it('calls EventsTracker.trackDenyTool with tool name from last message', async () => {
        await waitForPromises();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        store.commit('ADD_MESSAGE', {
          message_type: 'request',
          role: 'assistant',
          requestId: 'req-tracking-2',
          tool_info: { name: 'some_tool', args: {} },
          content: 'Tool requires approval',
        });

        findDuoChat().vm.$emit('deny-tool', 'I do not approve');
        await nextTick();

        expect(EventsTracker.trackDenyTool).toHaveBeenCalledWith({
          toolName: 'some_tool',
        });
      });
    });

    describe('@retry-message', () => {
      const retryUserPrompt = 'What is GitLab?';
      const seedRetryMessages = (messages) => {
        messages.forEach((m) => store.commit('ADD_MESSAGE', m));
        // The component mount calls setMessages([]) via onNewChat, so reset
        // the spy after seeding so per-test assertions start from zero calls.
        actionSpies.addDuoChatMessage.mockClear();
        createWorkflowMutationMock.mockClear();
      };
      const baseRetryMessages = [
        { id: 'user-1', role: 'user', content: retryUserPrompt },
        { id: 'assistant-1', role: 'assistant', content: 'Original (failed) response' },
      ];

      describe('when the feature flag is enabled', () => {
        beforeEach(async () => {
          createComponent({
            provide: {
              glFeatures: {
                agenticManualRetryForDuoChatResponses: true,
              },
            },
          });
          await waitForPromises();
        });

        it('forwards is-retry-enabled=true to the chat view', () => {
          expect(findDuoChat().props('isRetryEnabled')).toBe(true);
        });

        it('resubmits the preceding user prompt when retry-message is emitted', async () => {
          seedRetryMessages(baseRetryMessages);

          findDuoChat().vm.$emit('retry-message', { id: 'assistant-1' });
          await waitForPromises();

          expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
            expect.anything(),
            expect.objectContaining({
              content: retryUserPrompt,
              role: 'user',
            }),
          );
          expect(createWorkflowMutationMock).toHaveBeenCalledWith(
            expect.objectContaining({ goal: retryUserPrompt }),
          );
        });

        it('passes isRetry: true to buildStartRequest when retry-message is emitted', async () => {
          seedRetryMessages(baseRetryMessages);
          WorkflowSocketUtils.buildStartRequest.mockClear();

          findDuoChat().vm.$emit('retry-message', { id: 'assistant-1' });
          await waitForPromises();

          expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
            expect.objectContaining({
              goal: retryUserPrompt,
              isRetry: true,
            }),
          );
        });

        it('walks past intervening non-user messages to find the most recent user prompt', async () => {
          seedRetryMessages([
            { id: 'user-0', role: 'user', content: 'first prompt' },
            { id: 'assistant-0', role: 'assistant', content: 'first reply' },
            { id: 'user-1', role: 'user', content: retryUserPrompt },
            { id: 'tool-1', role: 'tool', content: 'some tool output' },
            { id: 'assistant-1', role: 'assistant', content: 'failed reply' },
          ]);

          findDuoChat().vm.$emit('retry-message', { id: 'assistant-1' });
          await waitForPromises();

          expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
            expect.anything(),
            expect.objectContaining({
              content: retryUserPrompt,
              role: 'user',
            }),
          );
        });

        it('is a no-op when no preceding user message exists', async () => {
          seedRetryMessages([{ id: 'assistant-only', role: 'assistant', content: 'orphan reply' }]);

          findDuoChat().vm.$emit('retry-message', { id: 'assistant-only' });
          await waitForPromises();

          expect(createWorkflowMutationMock).not.toHaveBeenCalled();
        });

        it('is a no-op when the message id is unknown', async () => {
          seedRetryMessages(baseRetryMessages);

          findDuoChat().vm.$emit('retry-message', { id: 'does-not-exist' });
          await waitForPromises();

          expect(createWorkflowMutationMock).not.toHaveBeenCalled();
        });

        it('is a no-op when all preceding user messages are clarification answers', async () => {
          // When all user messages before the target are clarification answers (JSON payloads),
          // the retry should no-op to avoid resubmitting invalid prompts.
          const clarificationAnswerContent = JSON.stringify({
            message_sub_type: 'clarification_answer',
            selected_option: 'option-1',
            message_id: 'orphan-tool-id',
          });

          seedRetryMessages([
            { id: 'user-1', role: 'user', content: clarificationAnswerContent },
            { id: 'assistant-1', role: 'assistant', content: 'failed reply' },
          ]);

          findDuoChat().vm.$emit('retry-message', { id: 'assistant-1' });
          await waitForPromises();

          expect(createWorkflowMutationMock).not.toHaveBeenCalled();
        });

        it('is a no-op when target message is not an assistant message', async () => {
          seedRetryMessages([
            { id: 'user-0', role: 'user', content: 'first prompt' },
            { id: 'user-1', role: 'user', content: 'second prompt' },
          ]);

          findDuoChat().vm.$emit('retry-message', { id: 'user-1' });
          await waitForPromises();

          expect(createWorkflowMutationMock).not.toHaveBeenCalled();
        });
      });

      describe('when the feature flag is disabled', () => {
        beforeEach(async () => {
          createComponent();
          await waitForPromises();
        });

        it('forwards is-retry-enabled=false to the chat view', () => {
          expect(findDuoChat().props('isRetryEnabled')).toBe(false);
        });

        it('does not resubmit when retry-message is emitted', async () => {
          seedRetryMessages(baseRetryMessages);

          findDuoChat().vm.$emit('retry-message', { id: 'assistant-1' });
          await waitForPromises();

          expect(createWorkflowMutationMock).not.toHaveBeenCalled();
        });
      });
    });

    describe('@select-alternative', () => {
      beforeEach(async () => {
        createComponent({
          provide: {
            glFeatures: {
              aiAgenticWorkflows: true,
              duoChatRetry: true,
            },
          },
        });
        await waitForPromises();
      });

      it('passes selectedAlternatives prop to the chat view', () => {
        expect(findDuoChat().props('selectedAlternatives')).toEqual({});
      });

      it('updates selectedAlternatives when select-alternative is emitted', async () => {
        findDuoChat().vm.$emit('select-alternative', { messageId: 'msg-1', index: 1 });
        await nextTick();

        expect(findDuoChat().props('selectedAlternatives')).toEqual({ 'msg-1': 1 });
      });

      it('tracks multiple message selections independently', async () => {
        findDuoChat().vm.$emit('select-alternative', { messageId: 'msg-1', index: 1 });
        findDuoChat().vm.$emit('select-alternative', { messageId: 'msg-2', index: 2 });
        await nextTick();

        expect(findDuoChat().props('selectedAlternatives')).toEqual({
          'msg-1': 1,
          'msg-2': 2,
        });
      });

      it('updates existing selection when same messageId is selected again', async () => {
        findDuoChat().vm.$emit('select-alternative', { messageId: 'msg-1', index: 1 });
        await nextTick();

        findDuoChat().vm.$emit('select-alternative', { messageId: 'msg-1', index: 0 });
        await nextTick();

        expect(findDuoChat().props('selectedAlternatives')).toEqual({ 'msg-1': 0 });
      });
    });
  });

  describe('tool approval state management', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('keeps buttons disabled while tool is running after approval', async () => {
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      findDuoChat().vm.$emit('approve-tool');
      await nextTick();

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);

      triggerStreamEvent('message', {
        type: 'message',
        data: JSON.stringify({
          requestID: 'request-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [{ content: 'Running', message_type: 'agent' }],
              },
            }),
            status: DUO_WORKFLOW_STATUS_RUNNING,
          },
        }),
      });
      await waitForPromises();
      await nextTick();

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);
    });

    it('re-enables buttons when tool finishes running', async () => {
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      findDuoChat().vm.$emit('approve-tool');
      await nextTick();

      triggerStreamEvent('message', {
        type: 'message',
        data: JSON.stringify({
          requestID: 'request-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: { ui_chat_log: [{ content: 'Done', message_type: 'agent' }] },
            }),
            status: DUO_WORKFLOW_STATUS_INPUT_REQUIRED,
          },
        }),
      });
      await waitForPromises();
      await nextTick();

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
    });
  });

  describe('workflowId watcher', () => {
    beforeEach(async () => {
      createComponent();

      await waitForPromises();
    });

    it('stores workflowId and active thread when workflowId changes', async () => {
      await findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });

      await nextTick();

      expect(saveSessionStorageValue).toHaveBeenCalledWith(DUO_CURRENT_WORKFLOW_STORAGE_KEY, {
        workflowId: MOCK_WORKFLOW_ID,
      });
    });

    it('emits session-id-changed when workflowId changes', async () => {
      await findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });

      await nextTick();

      expect(wrapper.emitted('session-id-changed')).toBeDefined();
      expect(wrapper.emitted('session-id-changed')[0]).toEqual(['456']);
    });
  });

  describe('mode watcher', () => {
    let onNewChatSpy;
    let hydrateActiveWorkflowSpy;
    let onBackToListSpy;

    const bootstrapWithProps = async (props = {}) => {
      hydrateActiveWorkflowSpy = jest.spyOn(
        DuoAgenticChatStateManager.methods,
        'hydrateActiveWorkflow',
      );
      onNewChatSpy = jest.spyOn(DuoAgenticChatStateManager.methods, 'onNewChat');
      onBackToListSpy = jest.spyOn(DuoAgenticChatStateManager.methods, 'onBackToList');

      createComponent(props);
      await waitForPromises();
      hydrateActiveWorkflowSpy.mockClear();
      onNewChatSpy.mockClear();
      onBackToListSpy.mockClear();
    };

    describe('when mode changes to "new"', () => {
      it('calls onNewChat', async () => {
        await bootstrapWithProps();
        wrapper.setProps({ mode: 'new' });
        await nextTick();

        expect(onNewChatSpy).toHaveBeenCalledTimes(1);
      });
    });

    describe('when mode changes to "history"', () => {
      beforeEach(async () => {
        await bootstrapWithProps();
        wrapper.setProps({ mode: 'history' });
      });

      it('calls onBackToList', async () => {
        await nextTick();
        expect(onBackToListSpy).toHaveBeenCalledTimes(1);
      });

      it('emits change-title with empty string', () => {
        const emittedEvents = wrapper.emitted('change-title');
        expect(emittedEvents.at(-1)).toEqual(['']);
      });

      it('switches to LIST view', async () => {
        await nextTick();
        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.LIST);
      });
      it('removes any current messages', async () => {
        await bootstrapWithProps({
          inititalState: {
            messages: [{ id: '1', content: 'test', role: 'user' }],
          },
          data: {
            workflowId: MOCK_WORKFLOW_ID,
          },
        });
        await nextTick();
        expect(findDuoChat().props('messages')).toHaveLength(1);

        wrapper.setProps({ mode: 'history' });
        await nextTick();
        expect(findDuoChat().props('messages')).toHaveLength(0);
      });
    });

    describe('when mode changes to "active"', () => {
      describe('no active thread', () => {
        beforeEach(async () => {
          await bootstrapWithProps({ propsData: { mode: 'history' } });
        });

        it('starts a new chat', async () => {
          wrapper.setProps({ mode: 'active' });
          await nextTick();

          expect(onNewChatSpy).toHaveBeenCalledTimes(1);
          expect(hydrateActiveWorkflowSpy).not.toHaveBeenCalled();
        });
      });
      describe('active thread is set', () => {
        beforeEach(async () => {
          await bootstrapWithProps({
            data: {
              workflowId: MOCK_WORKFLOW_ID,
            },
            propsData: { mode: 'history' },
          });
        });

        it('should hydrate, and not run onNewChat', async () => {
          wrapper.setProps({ mode: 'active' });
          await nextTick();

          expect(onNewChatSpy).not.toHaveBeenCalled();
          expect(hydrateActiveWorkflowSpy).toHaveBeenCalledTimes(1);
        });
      });
      describe('when isLoading is true', () => {
        it('does not start a new chat or hydrate when switching to active mode', async () => {
          let resolvePromise = null;
          const pendingPromise = new Promise((resolve) => {
            resolvePromise = resolve;
          });

          workflowEventsQueryMock.mockReturnValue(pendingPromise);

          onNewChatSpy = jest.spyOn(DuoAgenticChatStateManager.methods, 'onNewChat');
          hydrateActiveWorkflowSpy = jest.spyOn(
            DuoAgenticChatStateManager.methods,
            'hydrateActiveWorkflow',
          );

          createComponent({
            data: {
              workflowId: MOCK_WORKFLOW_ID,
              isLoading: true,
            },
            propsData: { mode: 'history' },
          });

          await nextTick();

          hydrateActiveWorkflowSpy.mockClear();
          onNewChatSpy.mockClear();

          wrapper.setProps({ mode: 'active' });
          await nextTick();

          expect(onNewChatSpy).not.toHaveBeenCalled();
          expect(hydrateActiveWorkflowSpy).not.toHaveBeenCalled();

          resolvePromise(MOCK_WORKFLOW_EVENTS_RESPONSE);
        });
      });
    });
  });

  describe('Error conditions', () => {
    const errorText = 'Failed to fetch resources';

    it('handles errors from the context presets query', async () => {
      contextPresetsQueryHandlerMock.mockRejectedValueOnce(new Error(errorText));
      createComponent();
      await waitForPromises();

      expect(findDuoChat().exists()).toBe(true);
      expect(findDuoChat().props('predefinedPrompts')).toEqual([]);
    });

    it('handles workflow creation errors', async () => {
      createWorkflowMutationMock.mockRejectedValue(new Error(errorText));
      createComponent();
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });
  });

  describe('Global state watchers', () => {
    describe('duoChatGlobalState.commands', () => {
      beforeEach(() => {
        createComponent({
          propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
        });
      });

      describe('when commands are added', () => {
        it('starts a new chat and sends the command question', async () => {
          const testQuestion = 'What is GitLab CI/CD?';

          // Trigger the watcher by adding a command to the global state
          duoChatGlobalState.commands = [{ question: testQuestion }];
          await waitForPromises();

          // Assert that onNewChat() side effects occurred
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
          expect(findChatLoadingState().exists()).toBe(false);

          // Assert that onSendChatPrompt() side effects occurred
          expect(findDuoChat().props('isLoading')).toBe(true);
          expect(createWorkflowMutationMock).toHaveBeenCalledWith(
            expect.objectContaining({
              projectId: MOCK_PROJECT_ID,
              goal: testQuestion,
            }),
          );
          expect(streamManager.connect).toHaveBeenCalled();
          expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
            expect.any(Object),
            expect.objectContaining({
              content: testQuestion,
              role: 'user',
              requestId: DUO_AGENTIC_CHAT_PENDING_USER_MESSAGE_ID,
            }),
          );
        });

        it('does not trigger chat when commands array is empty', async () => {
          jest.clearAllMocks();

          duoChatGlobalState.commands = [];
          await nextTick();

          expect(actionSpies.setMessages).not.toHaveBeenCalled();
          expect(createWorkflowMutationMock).not.toHaveBeenCalled();
          expect(streamManager.connect).not.toHaveBeenCalled();
        });
      });

      describe('when a command has autoSend: false', () => {
        it('resets the thread but does not send a prompt or create a workflow', async () => {
          duoChatGlobalState.commands = [
            { agent: { name: 'Permissions Assistant' }, resourceId: '1', autoSend: false },
          ];
          await waitForPromises();

          // onNewChat() side effects should have run
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);

          // onSendChatPrompt() should NOT have been called
          expect(createWorkflowMutationMock).not.toHaveBeenCalled();
          expect(streamManager.connect).not.toHaveBeenCalled();
        });

        it('passes currentWelcomeMessage to WebAgenticDuoChat as emptyStateTitle', async () => {
          const welcomeMessage = 'Tell me what you need.';
          duoChatGlobalState.commands = [
            {
              agent: { name: 'Permissions Assistant' },
              resourceId: '1',
              autoSend: false,
              welcomeMessage,
            },
          ];
          await waitForPromises();

          expect(findDuoChat().props('emptyStateTitle')).toBe(welcomeMessage);
        });

        it('passes currentPredefinedPrompts to WebAgenticDuoChat as predefinedPrompts', async () => {
          const predefinedPrompts = ['How do I fork?', 'What is a pipeline?'];
          duoChatGlobalState.commands = [
            {
              agent: { name: 'Permissions Assistant' },
              resourceId: '1',
              autoSend: false,
              predefinedPrompts,
            },
          ];
          await waitForPromises();

          expect(findDuoChat().props('predefinedPrompts')).toEqual(predefinedPrompts);
        });

        it('clears welcomeMessage and predefinedPrompts when onNewChat is called again', async () => {
          duoChatGlobalState.commands = [
            {
              agent: { name: 'Permissions Assistant' },
              resourceId: '1',
              autoSend: false,
              welcomeMessage: 'Hello!',
              predefinedPrompts: ['Prompt A'],
            },
          ];
          await waitForPromises();

          await findDuoChat().vm.$emit('new-chat');

          expect(findDuoChat().props('emptyStateTitle')).toBeNull();
          expect(findDuoChat().props('predefinedPrompts')).toEqual(
            MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions,
          );
        });

        it('does not send command-scoped context once onNewChat is called again', async () => {
          const formContextEnvelope = {
            category: 'form_context',
            content: '{"form_id":"ask-duo-pat"}',
            metadata: '{}',
          };
          duoChatGlobalState.commands = [
            {
              agent: { name: 'Permissions Assistant' },
              resourceId: '1',
              autoSend: false,
              additionalContext: [formContextEnvelope],
            },
          ];
          await waitForPromises();

          await findDuoChat().vm.$emit('new-chat');

          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
          await waitForPromises();

          const [call] = WorkflowSocketUtils.buildStartRequest.mock.calls;
          const { additionalContext } = call[0];

          expect(additionalContext.filter((c) => c.category === 'form_context')).toHaveLength(0);
        });
      });
    });
  });

  describe('onNewChat', () => {
    it.each`
      referenceWithVersion
      ${DUO_WORKFLOW_CHAT_DEFINITION}
      ${DUO_WORKFLOW_NEW_CHAT_DEFINITION}
    `(
      'clears selectedFoundationalAgent when referenceWithVersion is $referenceWithVersion',
      async ({ referenceWithVersion }) => {
        createComponent();
        await waitForPromises();

        wrapper.vm.selectedFoundationalAgent = { referenceWithVersion };

        await findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(wrapper.vm.selectedFoundationalAgent).toBeNull();
      },
    );
  });

  describe('when socket connection terminates', () => {
    beforeEach(async () => {
      flowStatusQueryMock.mockResolvedValueOnce({
        data: {
          duoWorkflowWorkflows: {
            edges: [
              {
                node: {
                  id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/456',
                  status: 'running',
                },
              },
            ],
          },
        },
      });
      createComponent();
      wrapper.vm.workflowId = MOCK_WORKFLOW_ID;
      wrapper.vm.workflowStatus = 'running';

      // Trigger a workflow to create the WebSocket connection
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();
    });

    describe('and the code is 1013 (close and try again)', () => {
      beforeEach(async () => {
        // Suppress expected vue-apollo error for workflowStatus query
        // triggered when isFlowLocked becomes true and starts polling
        const errSpy = jest.spyOn(console, 'error').mockImplementation(() => {});
        triggerStreamEvent('close', { type: 'close', code: 1013 });
        await waitForPromises();
        await nextTick();
        errSpy.mockRestore();
      });

      it('disables the chat and passes reason text', () => {
        expect(findDuoChat().props('chatState')).toMatchObject({
          isEnabled: false,
          reason:
            'GitLab Duo is already responding to this chat in another tab or location. Start a new chat, or wait for GitLab Duo to finish before sending a new message.',
        });
      });

      it('starts polling for workflow status', () => {
        expect(flowStatusQueryMock).toHaveBeenCalledWith({
          id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/456',
        });
      });

      it('does not poll for workflow status when workflowId is null', async () => {
        flowStatusQueryMock.mockClear();

        // Simulate stale localStorage scenario: isFlowLocked is true but workflowId is null
        wrapper.vm.workflowId = null;
        await nextTick();

        jest.advanceTimersByTime(3000);
        await waitForPromises();

        expect(flowStatusQueryMock).not.toHaveBeenCalled();
      });
    });

    describe('when status changes', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        triggerStreamEvent('close', { type: 'close', code: 1013 });
        await waitForPromises();
        await nextTick();
      });

      it('re-enables the chat', async () => {
        expect(findDuoChat().props('chatState')).toMatchObject({
          isEnabled: false,
          reason:
            'GitLab Duo is already responding to this chat in another tab or location. Start a new chat, or wait for GitLab Duo to finish before sending a new message.',
        });

        // Next poll will give us an updated status
        flowStatusQueryMock.mockResolvedValueOnce({
          data: {
            duoWorkflowWorkflows: {
              edges: [
                {
                  node: {
                    id: 'gid://gitlab/Ai::DuoWorkflows::Workflow/456',
                    status: 'input_required',
                  },
                },
              ],
            },
          },
        });

        jest.advanceTimersByTime(3000);
        await waitForPromises();
        await nextTick();

        expect(findDuoChat().props('chatState')).toMatchObject({ isEnabled: true });
      });

      it('hydrates the active thread to reconnect', async () => {
        workflowEventsQueryMock.mockClear();

        jest.advanceTimersByTime(3000);
        await waitForPromises();
        await nextTick();

        expect(workflowEventsQueryMock).toHaveBeenCalledWith({ workflowId: MOCK_WORKFLOW_ID });
      });
    });
  });

  describe('Socket cleanup', () => {
    it('clears state on component destroy when stream is not active', () => {
      createComponent();

      wrapper.destroy();

      expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
    });

    it('emits "change-title" event in beforeDestroy hook', () => {
      expect(wrapper?.emitted('change-title')).toBeUndefined();

      createComponent();

      let changeTitleEmitted = false;
      wrapper.vm.$on('change-title', () => {
        changeTitleEmitted = true;
      });

      wrapper.destroy();

      expect(changeTitleEmitted).toBe(true);
    });

    it('sets isProcessingToolApproval to false on socket close when not waiting for approval', async () => {
      createComponent();
      await waitForPromises();

      wrapper.vm.isProcessingToolApproval = true;
      wrapper.vm.workflowStatus = 'completed';
      wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

      wrapper.vm.startWorkflow({
        goal: 'test question',
        additionalContext: wrapper.vm.additionalContext,
      });

      expect(streamManager.connect).toHaveBeenCalled();

      triggerStreamEvent('close', { type: 'close' });

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(false);
      expect(findDuoChat().props('isLoading')).toBe(false);
    });

    it('keeps isProcessingToolApproval true on socket close when workflow is RUNNING', async () => {
      createComponent();
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      findDuoChat().vm.$emit('approve-tool');
      await nextTick();

      triggerStreamEvent('message', {
        type: 'message',
        data: JSON.stringify({
          requestID: 'request-1',
          newCheckpoint: {
            checkpoint: JSON.stringify({
              channel_values: {
                ui_chat_log: [{ content: 'Running', message_type: 'agent' }],
              },
            }),
            status: DUO_WORKFLOW_STATUS_RUNNING,
          },
        }),
      });
      await waitForPromises();
      await nextTick();

      triggerStreamEvent('close', { type: 'close' });
      await nextTick();

      expect(findDuoChat().props('isToolApprovalProcessing')).toBe(true);
    });
  });

  describe('toggle position based on chatMode', () => {
    const findAgenticModeToggle = () => wrapper.findComponent(AgenticModeToggle);

    beforeEach(() => {
      jest.clearAllMocks();
    });

    it('shows toggle as checked when in agentic mode', () => {
      duoChatGlobalState.chatMode = 'agentic';
      createComponent({
        propsData: { forceAgenticModeForCoreDuoUsers: false },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              isClassicAvailable: true,
            },
          },
        },
      });

      expect(findAgenticModeToggle().props('value')).toBe(true);
    });

    it('shows toggle as unchecked when in classic mode', () => {
      duoChatGlobalState.chatMode = 'classic';
      createComponent({
        propsData: { forceAgenticModeForCoreDuoUsers: false },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              isClassicAvailable: true,
            },
          },
        },
      });

      expect(findAgenticModeToggle().props('value')).toBe(false);
    });
  });

  describe('multiThreadedView route derivation', () => {
    it('derives CHAT from the show route even while a load is in flight', async () => {
      createComponent({
        routeName: AGENTIC_CHAT_SHOW_ROUTE,
        initialState: {
          messages: [{ role: 'user', content: 'Hello', requestId: '1' }],
        },
        data: { isLoading: true },
      });
      await nextTick();

      expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.CHAT);
    });

    it('derives LIST from the history route', async () => {
      // mode mirrors the route: the panel sits on the history list. Without a
      // matching mode the mount-time switchMode('active')/onNewChat would push
      // the show route and clobber the initial route, so this pins the real
      // route-driven derivation rather than a stale pre-navigation render.
      createComponent({
        routeName: AGENTIC_CHAT_HISTORY_ROUTE,
        propsData: { mode: 'history' },
      });
      await waitForPromises();

      expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.LIST);
    });
  });

  describe('Multithreading features', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('@thread-selected', () => {
      it('switches to selected thread and emits switch-to-active-tab', async () => {
        const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };

        findDuoChat().vm.$emit('thread-selected', mockThread);
        await waitForPromises();

        expect(wrapper.emitted('switch-to-active-tab')).toBeDefined();
        expect(wrapper.emitted('switch-to-active-tab')[0]).toEqual([DUO_CHAT_VIEWS.CHAT]);
      });

      it('resets the current thread before selecting new thread', async () => {
        const clearActiveWorkflowSpy = jest.spyOn(wrapper.vm, 'clearActiveWorkflow');

        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID });
        await waitForPromises();

        expect(clearActiveWorkflowSpy).toHaveBeenCalled();
      });

      it('disables chat with archived message when workflow is archived', async () => {
        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, archived: true });
        await waitForPromises();

        expect(findDuoChat().props('chatState')).toMatchObject({
          isEnabled: false,
          reason: expect.stringContaining('archived'),
        });
      });

      it('re-enables chat when starting a new chat after an archived workflow', async () => {
        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, archived: true });
        await waitForPromises();

        expect(findDuoChat().props('chatState')).toMatchObject({ isEnabled: false });

        findDuoChat().vm.$emit('new-chat');
        await waitForPromises();

        expect(findDuoChat().props('chatState')).toMatchObject({ isEnabled: true });
      });

      describe.each([
        ['archived', { archived: true }],
        ['stalled', { stalled: true }],
      ])('when thread is %s', (_, threadFlags) => {
        it('shows inactive empty state and disables chat', async () => {
          const mockThread = { id: MOCK_WORKFLOW_ID, ...threadFlags };

          findDuoChat().vm.$emit('thread-selected', mockThread);
          await nextTick();

          expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.CHAT);
          expect(findDuoChat().props('chatState')).toMatchObject({
            isEnabled: false,
            reason: expect.stringContaining('archived'),
          });
          expect(workflowEventsQueryMock).not.toHaveBeenCalled();
        });

        it('does not keep the previous thread web search preference', async () => {
          wrapper.vm.webSearchEnabled = true;

          findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, ...threadFlags });
          await nextTick();

          expect(findDuoChat().props('webSearchEnabled')).toBe(false);
        });

        it('does not clear messages when selected', async () => {
          await waitForPromises();
          await store.dispatch('addDuoChatMessage', MOCK_TRANSFORMED_MESSAGES[0]);
          await nextTick();
          const messagesBefore = findDuoChat().props('messages');

          findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, ...threadFlags });
          await nextTick();

          expect(findDuoChat().props('messages')).toEqual(messagesBefore);
        });

        it('renders ThreadInactiveEmptyState in custom-empty-state slot', async () => {
          findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, ...threadFlags });
          await nextTick();

          const customEmptyState = getInstanceSlots(findDuoChat().vm)['custom-empty-state']({});

          expect(customEmptyState).toBeDefined();
        });
      });

      it('re-enables chat when switching from an archived thread to a non-archived thread', async () => {
        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, archived: true });
        await waitForPromises();

        expect(findDuoChat().props('chatState')).toMatchObject({
          isEnabled: false,
          reason: expect.stringContaining('archived'),
        });

        findDuoChat().vm.$emit('thread-selected', { id: 'workflow-2' });
        await waitForPromises();

        expect(findDuoChat().props('chatState')).toMatchObject({ isEnabled: true });
      });

      it('disables chat with archived message when workflow is stalled', async () => {
        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, stalled: true });
        await waitForPromises();

        expect(findDuoChat().props('chatState')).toMatchObject({
          isEnabled: false,
          reason: expect.stringContaining('archived'),
        });
        const duoChat = findDuoChat();
        const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state']({});
        expect(customEmptyState).toBeDefined();
      });

      it('re-enables chat when starting a new chat after a stalled workflow', async () => {
        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, stalled: true });
        await nextTick();

        expect(findDuoChat().props('chatState')).toMatchObject({ isEnabled: false });

        findDuoChat().vm.$emit('new-chat');
        await waitForPromises();

        expect(findDuoChat().props('chatState')).toMatchObject({ isEnabled: true });
      });
    });

    describe('@back-to-list', () => {
      it('switches back to list view and refetches workflows', async () => {
        await waitForPromises();

        findDuoChat().vm.$emit('back-to-list');
        await nextTick();

        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.LIST);
        expect(mockRefetch).toHaveBeenCalled();
      });
      it('pushes the history route', async () => {
        await waitForPromises();

        findDuoChat().vm.$emit('back-to-list');
        await nextTick();

        expect(mockRouter.push).toHaveBeenCalledWith({ name: AGENTIC_CHAT_HISTORY_ROUTE });
      });
      it('clears the active thread', async () => {
        const clearActiveWorkflowSpy = jest.spyOn(wrapper.vm, 'clearActiveWorkflow');

        findDuoChat().vm.$emit('back-to-list');
        await nextTick();

        expect(clearActiveWorkflowSpy).toHaveBeenCalled();
      });
      it('clears inactive thread state when going back to list', async () => {
        findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, archived: true });
        await nextTick();

        expect(getInstanceSlots(findDuoChat().vm)['custom-empty-state']({})).toBeDefined();

        findDuoChat().vm.$emit('back-to-list');
        await nextTick();

        expect(getInstanceSlots(findDuoChat().vm)['custom-empty-state']).toBeUndefined();
      });
    });

    describe('@web-search-toggled', () => {
      it('calls updateWebSearchMutation when workflowId exists', async () => {
        createComponent();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        findDuoChat().vm.$emit('web-search-toggled', true);
        await waitForPromises();

        expect(updateWebSearchMutationMock).toHaveBeenCalledWith({
          workflowId: MOCK_WORKFLOW_ID,
          webSearchEnabled: true,
        });
      });

      it('does not call mutation when workflowId is not set', async () => {
        createComponent();

        findDuoChat().vm.$emit('web-search-toggled', true);
        await waitForPromises();

        expect(updateWebSearchMutationMock).not.toHaveBeenCalled();
      });

      // The flow service reads web_search_enabled off the workflow record when the
      // turn starts, so the turn must not outrun the write.
      it('does not start the turn until the preference write has landed', async () => {
        createComponent();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;
        streamManager.connect.mockClear();

        let resolveUpdate;
        updateWebSearchMutationMock.mockReturnValueOnce(
          new Promise((resolve) => {
            resolveUpdate = resolve;
          }),
        );

        findDuoChat().vm.$emit('web-search-toggled', true);
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(streamManager.connect).not.toHaveBeenCalled();

        resolveUpdate(MOCK_UPDATE_WEB_SEARCH_MUTATION_RESPONSE);
        await waitForPromises();

        expect(streamManager.connect).toHaveBeenCalled();
      });

      it('keeps the toggled value when the mutation succeeds', async () => {
        createComponent();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        findDuoChat().vm.$emit('web-search-toggled', true);
        await waitForPromises();

        expect(wrapper.vm.webSearchEnabled).toBe(true);
      });

      it('persists rapid toggles in click order', async () => {
        createComponent();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        findDuoChat().vm.$emit('web-search-toggled', true);
        findDuoChat().vm.$emit('web-search-toggled', false);
        await waitForPromises();

        expect(updateWebSearchMutationMock.mock.calls.map(([variables]) => variables)).toEqual([
          { workflowId: MOCK_WORKFLOW_ID, webSearchEnabled: true },
          { workflowId: MOCK_WORKFLOW_ID, webSearchEnabled: false },
        ]);
      });

      describe.each`
        description         | mockFailure
        ${'rejects'}        | ${() => updateWebSearchMutationMock.mockRejectedValueOnce(new Error('mutation failed'))}
        ${'returns errors'} | ${() => updateWebSearchMutationMock.mockResolvedValueOnce({ data: { updateDuoWorkflowWebSearch: { workflow: null, errors: ['Workflow not found'] } } })}
      `('when the mutation $description', ({ mockFailure }) => {
        // Switch web search on successfully first, so the failing click below has a
        // non-default value to fall back to.
        beforeEach(async () => {
          createComponent();
          wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

          findDuoChat().vm.$emit('web-search-toggled', true);
          await waitForPromises();

          mockFailure();
        });

        it('restores the value the user saw before the click', async () => {
          findDuoChat().vm.$emit('web-search-toggled', false);
          await waitForPromises();

          expect(wrapper.vm.webSearchEnabled).toBe(true);
        });

        it('reports the failure to Sentry without adding a message to the conversation', async () => {
          actionSpies.addDuoChatMessage.mockClear();

          findDuoChat().vm.$emit('web-search-toggled', false);
          await waitForPromises();

          expect(captureExceptionForDuoChat).toHaveBeenCalled();
          expect(actionSpies.addDuoChatMessage).not.toHaveBeenCalled();
        });

        it('leaves the newly selected thread alone when the user switches threads mid-flight', async () => {
          findDuoChat().vm.$emit('web-search-toggled', false);
          wrapper.vm.workflowId = 'gid://gitlab/Ai::DuoWorkflows::Workflow/999';
          await waitForPromises();

          expect(wrapper.vm.webSearchEnabled).toBe(false);
        });
      });
    });

    describe('restoring the web search preference', () => {
      const [MOCK_WORKFLOW_NODE] = MOCK_WORKFLOW_EVENTS_RESPONSE.duoWorkflowWorkflows.nodes;
      const workflowEventsResponseWith = (webSearchEnabled) => ({
        data: {
          duoWorkflowWorkflows: {
            nodes: [{ ...MOCK_WORKFLOW_NODE, webSearchEnabled }],
          },
        },
      });

      it('applies the value stored on the workflow record', async () => {
        workflowEventsQueryMock.mockResolvedValueOnce(workflowEventsResponseWith(true));
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        await wrapper.vm.loadActiveWorkflow();
        await nextTick();

        expect(findDuoChat().props('webSearchEnabled')).toBe(true);
      });

      it('ignores a response for a thread the user has already navigated away from', async () => {
        let resolveWorkflowEvents;
        workflowEventsQueryMock.mockReturnValueOnce(
          new Promise((resolve) => {
            resolveWorkflowEvents = resolve;
          }),
        );
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        const loaded = wrapper.vm.loadActiveWorkflow();
        wrapper.vm.workflowId = 'gid://gitlab/Ai::DuoWorkflows::Workflow/999';
        resolveWorkflowEvents(workflowEventsResponseWith(true));
        await loaded;

        expect(wrapper.vm.webSearchEnabled).toBe(false);
      });
    });

    describe('@delete-thread', () => {
      beforeEach(async () => {
        jest.clearAllMocks();
        deleteWorkflowMutationMock.mockResolvedValue(MOCK_DELETE_WORKFLOW_MUTATION_RESPONSE);
        await waitForPromises();
      });

      it('opens the confirmation modal without deleting when delete is requested', async () => {
        expect(findDeleteThreadModal().props('visible')).toBe(false);

        findDuoChat().vm.$emit('delete-thread', MOCK_WORKFLOW_ID);
        await nextTick();

        expect(findDeleteThreadModal().props('visible')).toBe(true);
        expect(deleteWorkflowMutationMock).not.toHaveBeenCalled();
      });

      it('calls deleteWorkflow and removes the thread from the list when confirmed', async () => {
        const mockThreadId = MOCK_WORKFLOW_ID;

        expect(findDuoChat().props('threadList')).toHaveLength(1);

        findDuoChat().vm.$emit('delete-thread', mockThreadId);
        await nextTick();

        findDeleteThreadModal().vm.$emit('confirm');
        await waitForPromises();

        expect(deleteWorkflowMutationMock).toHaveBeenCalledWith({
          input: { workflowId: mockThreadId },
        });
        // The list is updated locally instead of refetching.
        expect(mockRefetch).not.toHaveBeenCalled();
        expect(findDuoChat().props('threadList')).toEqual([]);
        expect(findDeleteThreadModal().props('visible')).toBe(false);
      });

      it(`clears the thread's snapshot when confirmed`, async () => {
        findDuoChat().vm.$emit('delete-thread', MOCK_WORKFLOW_ID);
        await nextTick();

        findDeleteThreadModal().vm.$emit('confirm');
        await waitForPromises();

        expect(clearThreadSnapshot).toHaveBeenCalledWith(
          'gid://gitlab/Ai::DuoWorkflows::Workflow/456',
        );
      });

      it('shows a loading state on the modal while the mutation is in flight', async () => {
        let resolveMutation;
        deleteWorkflowMutationMock.mockReturnValue(
          new Promise((resolve) => {
            resolveMutation = resolve;
          }),
        );

        findDuoChat().vm.$emit('delete-thread', MOCK_WORKFLOW_ID);
        await nextTick();

        findDeleteThreadModal().vm.$emit('confirm');
        await nextTick();

        expect(findDeleteThreadModal().props('loading')).toBe(true);

        resolveMutation(MOCK_DELETE_WORKFLOW_MUTATION_RESPONSE);
        await waitForPromises();

        expect(findDeleteThreadModal().props('loading')).toBe(false);
        expect(findDeleteThreadModal().props('visible')).toBe(false);
      });
    });
  });

  describe('Agentic Toggle', () => {
    const findAgenticModeToggle = () => wrapper.findComponent(AgenticModeToggle);

    beforeEach(() => {
      duoChatGlobalState.chatMode = 'classic';
      jest.clearAllMocks();
      createComponent({
        propsData: { forceAgenticModeForCoreDuoUsers: false },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              isClassicAvailable: true,
            },
          },
        },
      });
    });

    it('calls setAgenticMode with the toggle value when toggle changes', async () => {
      const toggle = findAgenticModeToggle();

      // Toggle directly controls agentic mode - false means agentic mode is disabled
      toggle.vm.$emit('change', false);
      await nextTick();

      expect(setAgenticMode).toHaveBeenCalledWith({
        agenticMode: false,
        saveCookie: true,
      });
    });

    it('is enabled by default', () => {
      expect(findAgenticModeToggle().props('disabled')).toBe(false);
    });

    it('is disabled when the selected thread is archived', async () => {
      findDuoChat().vm.$emit('thread-selected', { id: MOCK_WORKFLOW_ID, archived: true });
      await nextTick();

      expect(findAgenticModeToggle().props('disabled')).toBe(true);
    });

    it.each([false, true])(
      'when forceAgenticModeForCoreDuoUsers is %s',
      (forceAgenticModeForCoreDuoUsers) => {
        createComponent({
          propsData: { forceAgenticModeForCoreDuoUsers },
          provide: {
            chatConfiguration: {
              title: 'GitLab Duo Agentic Chat',
              defaultProps: {
                isClassicAvailable: true,
              },
            },
          },
        });
        expect(findAgenticModeToggle().exists()).toBe(!forceAgenticModeForCoreDuoUsers);
      },
    );
  });

  describe('Agentic chat user model selection', () => {
    const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);

    describe('when user model selection is enabled', () => {
      beforeEach(async () => {
        createComponent({
          propsData: { userModelSelectionEnabled: true, rootNamespaceId: MOCK_NAMESPACE_ID },
        });
        await waitForPromises();
      });

      it('renders `ModelSelectDropdown` in the correct slot', () => {
        expect(findModelSelectDropdown().exists()).toBe(true);
        const slot = findDuoChat().vm.$slots['agentic-model'];
        const vnode = typeof slot === 'function' ? slot()[0] : slot[0];

        const testId = vnode.props
          ? vnode.props['data-testid'] // Vue 3
          : vnode.data.attrs['data-testid']; // Vue 2

        expect(testId).toBe('model-dropdown-container');
      });

      describe('when availableModels query is loading', () => {
        it('triggers a loading state', async () => {
          // Use a never-resolving handler so models stay in loading state
          const pendingModelsHandler = jest.fn().mockReturnValue(new Promise(() => {}));
          createComponent({
            propsData: { userModelSelectionEnabled: true, rootNamespaceId: MOCK_NAMESPACE_ID },
            apolloHandlers: [[getAiChatAvailableModels, pendingModelsHandler]],
          });
          getCurrentModel.mockClear();
          await waitForPromises();

          expect(findModelSelectDropdown().props('isLoading')).toBe(true);
          expect(findModelSelectDropdown().props('selectedOption')).toBe(null);
          expect(getCurrentModel).not.toHaveBeenCalled();
        });
      });

      describe('when availableModels query has loaded', () => {
        it('invokes `getCurrentModel()` with the correct arguments', async () => {
          await waitForPromises();

          expect(getCurrentModel).toHaveBeenCalledWith({
            availableModels: MOCK_MODEL_LIST_ITEMS,
            pinnedModel: null,
            selectedModel: null,
          });
        });

        it('passes the correct props to `ModelSelectDropdown`', async () => {
          await waitForPromises();

          expect(findModelSelectDropdown().props('isLoading')).toBe(false);
          expect(findModelSelectDropdown().props('disabled')).toBe(false);
          expect(findModelSelectDropdown().props('placeholderDropdownText')).toBe('Select a model');
          expect(findModelSelectDropdown().props('items')).toMatchObject(MOCK_MODEL_LIST_ITEMS);
          expect(findModelSelectDropdown().props('selectedOption')).toMatchObject(
            MOCK_GITLAB_DEFAULT_MODEL_ITEM,
          );
        });
      });

      it('calls saveModel utility and starts new chat when model is selected', async () => {
        await waitForPromises();

        const selectedModel = MOCK_MODEL_LIST_ITEMS[1];
        const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');

        await findModelSelectDropdown().vm.$emit('select', selectedModel.value);

        expect(saveModel).toHaveBeenCalledWith(selectedModel);
        expect(onNewChatSpy).toHaveBeenCalledWith(true);
      });

      it('disables dropdown when pinned model is set', async () => {
        const pinnedModel = { text: 'Pinned Model', value: 'pinned/model' };
        checkModelSelectionDisabled.mockReturnValue(true);

        createComponent({
          propsData: { userModelSelectionEnabled: true, rootNamespaceId: MOCK_NAMESPACE_ID },
          data: { pinnedModel },
        });
        await waitForPromises();

        expect(findModelSelectDropdown().props('disabled')).toBe(true);
      });
    });

    describe('when user model selection is disabled', () => {
      beforeEach(() => {
        createComponent({ propsData: { userModelSelectionEnabled: false } });
      });

      it('does not render `ModelSelectDropdown`', () => {
        expect(findModelSelectDropdown().exists()).toBe(false);
      });
    });
  });

  describe('availableModels query skip and variables', () => {
    beforeEach(() => {
      availableModelsQueryHandlerMock.mockClear();
    });

    describe('skip behavior', () => {
      it('skips the query when userModelSelectionEnabled is false', async () => {
        createComponent({
          propsData: { userModelSelectionEnabled: false, rootNamespaceId: MOCK_NAMESPACE_ID },
        });
        await waitForPromises();

        expect(availableModelsQueryHandlerMock).not.toHaveBeenCalled();
      });

      it('skips the query when none of projectId, namespaceId, or rootNamespaceId are provided', async () => {
        createComponent({ propsData: { userModelSelectionEnabled: true } });
        await waitForPromises();

        expect(availableModelsQueryHandlerMock).not.toHaveBeenCalled();
      });

      it('calls the query when at least one ID is provided', async () => {
        createComponent({
          propsData: { userModelSelectionEnabled: true, projectId: MOCK_PROJECT_ID },
        });
        await waitForPromises();

        expect(availableModelsQueryHandlerMock).toHaveBeenCalled();
      });
    });

    describe('variables prioritization', () => {
      it.each([
        [
          'sends only projectId when projectId is provided',
          {
            projectId: MOCK_PROJECT_ID,
            namespaceId: MOCK_NAMESPACE_ID,
            rootNamespaceId: 'gid://gitlab/Group/789',
          },
          { projectId: MOCK_PROJECT_ID },
        ],
        [
          'sends only namespaceId when projectId is not provided',
          { namespaceId: MOCK_NAMESPACE_ID, rootNamespaceId: 'gid://gitlab/Group/789' },
          { namespaceId: MOCK_NAMESPACE_ID },
        ],
        [
          'sends only rootNamespaceId when neither projectId nor namespaceId are provided',
          { rootNamespaceId: 'gid://gitlab/Group/789' },
          { rootNamespaceId: 'gid://gitlab/Group/789' },
        ],
      ])('%s', async (_, propsData, expectedVariables) => {
        createComponent({ propsData: { userModelSelectionEnabled: true, ...propsData } });
        await waitForPromises();

        expect(availableModelsQueryHandlerMock).toHaveBeenCalledWith(expectedVariables);
      });
    });
  });

  describe('catalogAgents query variables', () => {
    it('passes only projectId when both projectId and namespaceId are provided', async () => {
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          namespaceId: MOCK_NAMESPACE_ID,
          resourceId: MOCK_RESOURCE_ID,
        },
      });
      await waitForPromises();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        includeFoundationalConsumers: false,
        first: 20,
        projectId: MOCK_PROJECT_ID,
      });
    });

    it('passes only projectId when only projectId is provided', async () => {
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
        },
      });
      await waitForPromises();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        includeFoundationalConsumers: false,
        first: 20,
        projectId: MOCK_PROJECT_ID,
      });
    });

    it('passes only groupId when only namespaceId is provided', async () => {
      createComponent({
        propsData: {
          namespaceId: MOCK_NAMESPACE_ID,
          resourceId: MOCK_RESOURCE_ID,
        },
      });
      await waitForPromises();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        includeFoundationalConsumers: false,
        first: 20,
        groupId: MOCK_NAMESPACE_ID,
      });
    });

    it('passes groupId when neither projectId nor namespaceId are provided', async () => {
      createComponent({
        propsData: {
          resourceId: MOCK_RESOURCE_ID,
        },
      });
      await waitForPromises();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        includeFoundationalConsumers: false,
        first: 20,
        groupId: null,
      });
    });
  });

  describe('Fetching foundational agents', () => {
    describe('when project and namespace are available', () => {
      it('passes project_id and namespace_id', async () => {
        createComponent({
          propsData: { projectId: MOCK_PROJECT_ID, namespaceId: MOCK_NAMESPACE_ID },
        });

        await waitForPromises();

        expect(aiFoundationalChatAgentsQueryMock).toHaveBeenCalledWith({
          namespaceId: MOCK_NAMESPACE_ID,
          projectId: MOCK_PROJECT_ID,
        });
      });
    });

    describe('when project and namespace are not available', () => {
      it('does not pass project_id and namespace_id', async () => {
        createComponent({ propsData: {} });

        await waitForPromises();

        expect(aiFoundationalChatAgentsQueryMock).toHaveBeenCalledWith({
          namespaceId: null,
          projectId: null,
        });
      });
    });
  });

  describe('agent selection', () => {
    let agent;

    beforeEach(async () => {
      createComponent();
      await waitForPromises();

      const agentResponse = MOCK_CONFIGURED_AGENTS_RESPONSE.data.aiCatalogConfiguredItems.nodes[0];
      agent = {
        ...agentResponse.item,
        pinnedItemVersionId: agentResponse.pinnedItemVersion.id,
        text: agentResponse.item.name,
      };
    });

    it('uses catalogAgentsFromResponse to transform the Apollo response', () => {
      expect(catalogAgentsFromResponse).toHaveBeenCalled();
    });

    it('uses the agentConfig from Apollo query when start workflow is called', async () => {
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
        agentVersionId: agent.pinnedItemVersionId,
      });

      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          agentConfig: MOCK_FLOW_AGENT_CONFIG,
          clientCapabilities: ['incremental_streaming', 'web_search'],
        }),
      );

      expect(streamManager.connect).toHaveBeenCalled();
    });

    it('uses workflow definition when foundational chat is selected', async () => {
      await findDuoChat().vm.$emit('new-chat', MOCK_FETCHED_FOUNDATIONAL_AGENT);
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(agentFlowConfigQueryMock).not.toHaveBeenCalled();
      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          workflowDefinition: 'agent/v1',
          agentConfig: null,
          clientCapabilities: ['incremental_streaming', 'web_search'],
        }),
      );

      expect(streamManager.connect).toHaveBeenCalled();
    });

    describe('switching from a foundational agent to a catalog agent', () => {
      it('fetches agent flow config and sends agent version id', async () => {
        findDuoChat().vm.$emit('new-chat', MOCK_FETCHED_FOUNDATIONAL_AGENT);
        await waitForPromises();

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenLastCalledWith(
          expect.objectContaining({
            workflowDefinition: 'agent/v1',
            agentConfig: null,
            clientCapabilities: ['incremental_streaming', 'web_search'],
          }),
        );

        await findDuoChat().vm.$emit('new-chat', agent);
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await waitForPromises();

        expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
          agentVersionId: agent.pinnedItemVersionId,
        });

        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenLastCalledWith(
          expect.objectContaining({
            workflowDefinition: undefined,
            clientCapabilities: ['incremental_streaming', 'web_search'],
          }),
        );

        expect(streamManager.connect).toHaveBeenCalled();
      });
    });

    it('re-uses the selected flow config when /new is used to start a new thread', async () => {
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', '/new');
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(streamManager.connect).toHaveBeenCalled();
    });

    it('preserves agentConfig when selecting the same custom agent multiple times', async () => {
      // Select custom agent first time
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      // Send first message to ensure agentConfig is populated
      findDuoChat().vm.$emit('send-chat-prompt', 'First message');
      await waitForPromises();

      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          agentConfig: MOCK_FLOW_AGENT_CONFIG,
          clientCapabilities: ['incremental_streaming', 'web_search'],
        }),
      );

      // Clear mocks to verify next call
      WorkflowSocketUtils.buildStartRequest.mockClear();

      // Select the SAME custom agent again (new chat with same agent)
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      // Send another message
      findDuoChat().vm.$emit('send-chat-prompt', 'Second message');
      await waitForPromises();

      // Verify agentConfig is still present (not null)
      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          agentConfig: MOCK_FLOW_AGENT_CONFIG,
          clientCapabilities: ['incremental_streaming', 'web_search'],
        }),
      );
    });

    it('resets agentConfig when default agent follows a custom agent chat', async () => {
      // Select custom agent first
      await findDuoChat().vm.$emit('new-chat', agent);
      await waitForPromises();

      // Send message with custom agent
      findDuoChat().vm.$emit('send-chat-prompt', 'Custom agent message');
      await waitForPromises();

      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          agentConfig: MOCK_FLOW_AGENT_CONFIG,
          clientCapabilities: ['incremental_streaming', 'web_search'],
        }),
      );

      // Clear mocks to verify next call
      WorkflowSocketUtils.buildStartRequest.mockClear();

      // Switch to foundational agent
      await findDuoChat().vm.$emit('new-chat', MOCK_FETCHED_FOUNDATIONAL_AGENT);
      await waitForPromises();

      // Send message with foundational agent
      findDuoChat().vm.$emit('send-chat-prompt', 'Foundational agent message');
      await waitForPromises();

      // Verify agentConfig is null and workflowDefinition is used instead
      expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalledWith(
        expect.objectContaining({
          workflowDefinition: MOCK_FETCHED_FOUNDATIONAL_AGENT.referenceWithVersion,
          agentConfig: null,
          clientCapabilities: ['incremental_streaming', 'web_search'],
        }),
      );
    });

    it('sends no config when the default agent is selected (no id on selection)', async () => {
      await findDuoChat().vm.$emit('new-chat', { name: 'default duo' });

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await waitForPromises();

      expect(streamManager.connect).toHaveBeenCalled();
    });

    describe('when chat is triggered via duoChatGlobalState.commands with an agent', () => {
      it('sets the selected agent from the command by id and displays it', async () => {
        duoChatGlobalState.commands = [
          ...duoChatGlobalState.commands,
          {
            question: 'Analyze this code for vulnerabilities',
            resourceId: MOCK_RESOURCE_ID,
            variables: {},
            agent: { id: DUO_FOUNDATIONAL_AGENT_MOCK.id },
          },
        ];
        await nextTick();

        expect(actionSpies.setCurrentAgent).toHaveBeenCalledWith(
          expect.anything(),
          MOCK_FETCHED_FOUNDATIONAL_AGENT,
        );
        expect(findDuoChat().props('title')).toBe(DUO_FOUNDATIONAL_AGENT_MOCK.name);
      });

      it('sets the selected agent from the command by name and displays it', async () => {
        duoChatGlobalState.commands = [
          ...duoChatGlobalState.commands,
          {
            question: 'Analyze this code for vulnerabilities',
            resourceId: MOCK_RESOURCE_ID,
            variables: {},
            agent: { name: DUO_FOUNDATIONAL_AGENT_MOCK.name },
          },
        ];
        await nextTick();

        expect(actionSpies.setCurrentAgent).toHaveBeenCalledWith(
          expect.anything(),
          MOCK_FETCHED_FOUNDATIONAL_AGENT,
        );
        expect(findDuoChat().props('title')).toBe(DUO_FOUNDATIONAL_AGENT_MOCK.name);
      });
    });
  });

  describe('Agent deletion handling', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('disables chat when agent is deleted', async () => {
      // Mock thread with deleted agent
      workflowEventsQueryMock.mockResolvedValue({
        data: {
          ...MOCK_WORKFLOW_EVENTS_RESPONSE,
          duoWorkflowWorkflows: {
            nodes: [
              {
                id: 'workflow-1',
                status: 'completed',
                aiCatalogItemVersionId: 'AgentVersion 999',
                workflowDefinition: null,
                archived: false,
                stalled: false,
                webSearchEnabled: false,
                latestCheckpoint: null,
              },
            ],
          },
        },
      });

      createComponent({ data: { workflowId: MOCK_WORKFLOW_ID } });
      await waitForPromises();

      expect(findDuoChat().props('isChatAvailable')).toBe(false);
      expect(findDuoChat().props('error')).toBe(
        'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
      );
    });

    it('hides error in history view', async () => {
      createComponent({
        routeName: AGENTIC_CHAT_HISTORY_ROUTE,
        propsData: { mode: 'history' },
        data: { agentOrWorkflowDeletedError: 'Error' },
      });
      await waitForPromises();

      expect(findDuoChat().props('error')).toBe('');
    });

    it('re-enables chat when starting new chat after viewing deleted agent thread', async () => {
      // Mock thread with deleted agent
      workflowEventsQueryMock.mockResolvedValue({
        data: {
          ...MOCK_WORKFLOW_EVENTS_RESPONSE,
          duoWorkflowWorkflows: {
            nodes: [
              {
                id: 'workflow-1',
                status: 'completed',
                aiCatalogItemVersionId: 'AgentVersion 999',
                workflowDefinition: null,
                archived: false,
                stalled: false,
                webSearchEnabled: false,
                latestCheckpoint: null,
              },
            ],
          },
        },
      });

      // Create component with workflowId to trigger hydration on mount
      createComponent({ data: { workflowId: MOCK_WORKFLOW_ID } });
      await waitForPromises();

      // Verify chat is disabled
      expect(findDuoChat().props('isChatAvailable')).toBe(false);
      expect(findDuoChat().props('error')).toBe(
        'The agent associated with this conversation is no longer available. You can view the conversation history but cannot send new messages.',
      );

      // Start a new chat with default agent
      findDuoChat().vm.$emit('new-chat', { name: 'GitLab Duo Agent' });
      await nextTick();

      // Verify chat is re-enabled and error is cleared
      expect(findDuoChat().props('isChatAvailable')).toBe(true);
      expect(findDuoChat().props('error')).toBe('');
    });
  });

  describe('showErrorBannerMessage computed property', () => {
    const PREFERENCES_PATH = '/-/profile/preferences';

    const createComponentWithNamespaceConfig = ({
      defaultNamespaceSelected,
      preferencesPath = PREFERENCES_PATH,
      routeName = AGENTIC_CHAT_SHOW_ROUTE,
      agentOrWorkflowDeletedError = '',
    }) => {
      createComponent({
        routeName,
        // Keep mode consistent with the route so a history mount doesn't get
        // navigated to the show route by switchMode/onNewChat during mount.
        propsData: { mode: routeName === AGENTIC_CHAT_HISTORY_ROUTE ? 'history' : 'active' },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              defaultNamespaceSelected,
              preferencesPath,
            },
          },
        },
        data: { agentOrWorkflowDeletedError },
      });
    };

    describe.each`
      defaultNamespaceSelected | routeName                     | agentOrWorkflowDeletedError | expectedError          | description
      ${false}                 | ${AGENTIC_CHAT_SHOW_ROUTE}    | ${''}                       | ${''}                  | ${'returns empty string when namespace not selected (now handled by empty state)'}
      ${false}                 | ${AGENTIC_CHAT_HISTORY_ROUTE} | ${''}                       | ${''}                  | ${'returns empty string in LIST view'}
      ${true}                  | ${AGENTIC_CHAT_SHOW_ROUTE}    | ${''}                       | ${''}                  | ${'returns empty string when namespace is selected'}
      ${false}                 | ${AGENTIC_CHAT_SHOW_ROUTE}    | ${'Agent was deleted'}      | ${'Agent was deleted'} | ${'shows agentOrWorkflowDeletedError'}
      ${true}                  | ${AGENTIC_CHAT_SHOW_ROUTE}    | ${'Agent was deleted'}      | ${'Agent was deleted'} | ${'shows agentOrWorkflowDeletedError when namespace is selected'}
    `(
      '$description',
      ({ defaultNamespaceSelected, routeName, agentOrWorkflowDeletedError, expectedError }) => {
        it('returns correct error', () => {
          createComponentWithNamespaceConfig({
            defaultNamespaceSelected,
            routeName,
            agentOrWorkflowDeletedError,
          });

          const errorProp = findDuoChat().props('error');
          expect(errorProp).toBe(expectedError);
        });
      },
    );
  });

  describe('showNoNamespaceEmptyState computed property', () => {
    const PREFERENCES_PATH = '/-/profile/preferences';

    const createComponentWithNamespaceConfig = ({
      defaultNamespaceSelected,
      preferencesPath = PREFERENCES_PATH,
      routeName = AGENTIC_CHAT_SHOW_ROUTE,
    }) => {
      createComponent({
        routeName,
        // Keep mode consistent with the route so the mount doesn't navigate to
        // the show route (via switchMode/onNewChat) and clobber a history mount.
        propsData: { mode: routeName === AGENTIC_CHAT_HISTORY_ROUTE ? 'history' : 'active' },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              defaultNamespaceSelected,
              preferencesPath,
            },
          },
        },
      });
    };

    describe('when namespace is not selected', () => {
      it('renders no-namespace empty state in CHAT view', () => {
        createComponentWithNamespaceConfig({
          defaultNamespaceSelected: false,
          routeName: AGENTIC_CHAT_SHOW_ROUTE,
        });

        const duoChat = findDuoChat();
        const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state']({});

        expect(customEmptyState).toBeDefined();
      });

      it('disables the chat input', async () => {
        createComponentWithNamespaceConfig({
          defaultNamespaceSelected: false,
          routeName: AGENTIC_CHAT_SHOW_ROUTE,
        });

        await nextTick();

        const duoChat = findDuoChat();

        expect(duoChat.props('chatState')).toMatchObject({
          isEnabled: false,
        });
      });

      it('does not render empty state in LIST view', async () => {
        createComponentWithNamespaceConfig({
          defaultNamespaceSelected: false,
          routeName: AGENTIC_CHAT_HISTORY_ROUTE,
        });
        await waitForPromises();

        const duoChat = findDuoChat();
        const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state'];

        expect(customEmptyState).toBeUndefined();
      });
    });

    describe('when namespace is selected', () => {
      it('does not render no-namespace empty state', () => {
        createComponentWithNamespaceConfig({
          defaultNamespaceSelected: true,
          routeName: AGENTIC_CHAT_SHOW_ROUTE,
        });

        const duoChat = findDuoChat();
        const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state'];

        expect(customEmptyState).toBeUndefined();
      });
    });
  });

  describe('empty state priority', () => {
    const PREFERENCES_PATH = '/-/profile/preferences';

    it('shows no-namespace empty state over no-credits when both conditions are true', async () => {
      creditsAvailableQueryMock.mockResolvedValue({
        data: { gitlabCreditsAvailable: false, gitlabCreditsUnavailableReason: null },
      });

      createComponent({
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              defaultNamespaceSelected: false,
              preferencesPath: PREFERENCES_PATH,
            },
          },
        },
      });
      await waitForPromises();

      const duoChat = findDuoChat();
      const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state']({});

      expect(customEmptyState).toBeDefined();
    });

    it('shows no-credits empty state when namespace is selected but credits exhausted', async () => {
      creditsAvailableQueryMock.mockResolvedValue({
        data: { gitlabCreditsAvailable: false, gitlabCreditsUnavailableReason: null },
      });

      createComponent({
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              defaultNamespaceSelected: true,
              preferencesPath: PREFERENCES_PATH,
            },
          },
        },
      });
      await waitForPromises();

      const duoChat = findDuoChat();
      const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state']({});

      expect(customEmptyState).toBeDefined();
    });

    it('shows no-namespace empty state over trial/subscription when both conditions are true', () => {
      createComponent({
        propsData: { trialActive: true },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              defaultNamespaceSelected: false,
              preferencesPath: PREFERENCES_PATH,
            },
          },
        },
      });

      const duoChat = findDuoChat();
      const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state']({});

      expect(customEmptyState).toBeDefined();
    });

    it('shows no-credits empty state over trial/subscription when both conditions are true', async () => {
      creditsAvailableQueryMock.mockResolvedValue({
        data: { gitlabCreditsAvailable: false, gitlabCreditsUnavailableReason: null },
      });

      createComponent({
        propsData: { trialActive: true },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              defaultNamespaceSelected: true,
              preferencesPath: PREFERENCES_PATH,
            },
          },
        },
      });
      await waitForPromises();

      const duoChat = findDuoChat();
      const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state']({});

      expect(customEmptyState).toBeDefined();
    });

    // Messages are set via direct store mutation because clearActiveWorkflow()
    // wipes messages set via initialState during mount (no stream is connected
    // in tests). Mutating after mount ensures messages survive the wipe.
    describe('credits exhausted banner', () => {
      it('shows the credits exhausted alert when out of credits and messages exist', async () => {
        creditsAvailableQueryMock.mockResolvedValue({
          data: { gitlabCreditsAvailable: false, gitlabCreditsUnavailableReason: null },
        });
        createComponent();
        await waitForPromises();
        store.state.messages = [{ role: 'user', content: 'Hello' }];
        await nextTick();

        expect(findCreditsExhaustedAlert().exists()).toBe(true);
      });

      it('does not show the credits exhausted alert when out of credits but no messages exist', () => {
        createComponent({ data: { hasCredits: false } });

        expect(findCreditsExhaustedAlert().exists()).toBe(false);
      });

      it('does not show the credits exhausted alert when credits are available', async () => {
        createComponent();
        store.state.messages = [{ role: 'user', content: 'Hello' }];
        await nextTick();

        expect(findCreditsExhaustedAlert().exists()).toBe(false);
      });

      it('passes props to the alert', async () => {
        creditsAvailableQueryMock.mockResolvedValue({
          data: { gitlabCreditsAvailable: false, gitlabCreditsUnavailableReason: null },
        });
        createComponent({
          propsData: {
            isTrial: true,
            isFreeAddonCreditsUser: true,
            purchaseCreditsPath: '/buy',
            canBuyAddon: true,
          },
        });
        await waitForPromises();
        store.state.messages = [{ role: 'user', content: 'Hello' }];
        await nextTick();

        const alert = findCreditsExhaustedAlert();
        expect(alert.props('isTrial')).toBe(true);
        expect(alert.props('isFreeAddonCreditsUser')).toBe(true);
        expect(alert.props('hasAgenticToggle')).toBe(false);
        expect(alert.props('purchaseCreditsPath')).toBe('/buy');
        expect(alert.props('canBuyAddon')).toBe(true);
      });
    });

    it('shows trial/subscription empty state when namespace selected and credits available', () => {
      createComponent({
        propsData: { trialActive: true },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              defaultNamespaceSelected: true,
              preferencesPath: PREFERENCES_PATH,
            },
          },
        },
      });

      const duoChat = findDuoChat();
      const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state']({});

      expect(customEmptyState).toBeDefined();
    });
  });

  describe('dynamicTitle', () => {
    it('passes the base title when no custom agent is selected', async () => {
      createComponent();
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe('GitLab Duo');
    });

    it('passes the agent name as title when a custom agent is selected', async () => {
      const mockCatalogAgent = {
        id: 'Agent 5',
        name: 'My Custom Agent',
        description: 'This is my custom agent',
        pinnedItemVersionId: 'AgentVersion 5',
      };

      createComponent({
        propsData: {
          mode: 'default',
        },
        data: {
          aiCatalogItemVersionId: 'AgentVersion 5',
          catalogAgents: [mockCatalogAgent],
        },
        initialState: {
          currentAgent: mockCatalogAgent,
        },
      });
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe('My Custom Agent');
    });

    it('passes the agent name as title when a foundational agent is selected', async () => {
      createComponent({
        initialState: {
          currentAgent: MOCK_FETCHED_FOUNDATIONAL_AGENT,
        },
      });

      await findDuoChat().vm.$emit('new-chat', MOCK_FETCHED_FOUNDATIONAL_AGENT);
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe(MOCK_FETCHED_FOUNDATIONAL_AGENT.name);
    });

    it('uses currentAgent from Vuex store for title when available', async () => {
      const mockAgent = {
        id: 'Agent 123',
        name: 'Store Agent Name',
      };

      createComponent({
        initialState: {
          currentAgent: mockAgent,
        },
      });
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe('Store Agent Name');
    });

    it('falls back to duoChatTitle when currentAgent is null in store', async () => {
      createComponent({
        initialState: {
          currentAgent: null,
        },
      });
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe('GitLab Duo');
    });
  });

  describe('agent switching via Vuex integration', () => {
    it('updates title when currentAgent changes in store', async () => {
      createComponent({
        initialState: {
          currentAgent: null,
        },
      });
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe('GitLab Duo');

      await wrapper.vm.$store.dispatch('setCurrentAgent', {
        id: 'agent-1',
        name: 'New Agent',
      });
      await nextTick();

      expect(findDuoChat().props('title')).toBe('New Agent');
    });

    it('reverts to default title when currentAgent is set to null', async () => {
      createComponent({
        initialState: {
          currentAgent: { id: 'agent-1', name: 'Some Agent' },
        },
      });
      await waitForPromises();

      expect(findDuoChat().props('title')).toBe('Some Agent');

      await wrapper.vm.$store.dispatch('setCurrentAgent', null);
      await nextTick();

      expect(findDuoChat().props('title')).toBe('GitLab Duo');
    });
  });

  describe('flowConfig Apollo query integration', () => {
    beforeEach(() => {
      createWorkflowMutationMock.mockResolvedValue({
        data: { aiDuoWorkflowCreate: { workflow: { id: '456' }, errors: [] } },
      });
    });

    it('queries agentConfig when aiCatalogItemVersionId is set', async () => {
      agentFlowConfigQueryMock.mockClear();

      createComponent({
        data: {
          aiCatalogItemVersionId: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
        },
      });

      await waitForPromises();

      expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
        agentVersionId: 'gid://gitlab/Ai::Catalog::ItemVersion/1',
      });
    });

    it('fetches fresh agent config when switching agents', async () => {
      const agent2 = {
        id: 'Agent 2',
        name: 'Test Agent',
        pinnedItemVersionId: 'version-2',
      };

      agentFlowConfigQueryMock.mockClear();

      createComponent({
        data: {
          aiCatalogItemVersionId: 'version-1',
        },
      });
      await waitForPromises();

      // Switch to agent2
      await findDuoChat().vm.$emit('new-chat', agent2);
      await waitForPromises();

      // Verify query was called with the new agent version id
      expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
        agentVersionId: 'version-2',
      });
    });

    describe('when switching from custom agent to default agent', () => {
      beforeEach(async () => {
        createComponent({
          data: {
            aiCatalogItemVersionId: 'version-1',
          },
        });
        await waitForPromises();
      });

      it('stops querying agent config', async () => {
        // Verify config query was called for the custom agent
        expect(agentFlowConfigQueryMock).toHaveBeenCalledWith({
          agentVersionId: 'version-1',
        });

        agentFlowConfigQueryMock.mockClear();

        // Switch to default agent (no agent.id)
        findDuoChat().vm.$emit('new-chat', { name: 'default duo' });
        await waitForPromises();

        // Verify no config is sent when starting workflow with default agent
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(streamManager.connect).toHaveBeenCalled();
        expect(agentFlowConfigQueryMock).not.toHaveBeenCalled();
      });
    });
  });

  describe('initialization and layout', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            isClassicAvailable: true,
            defaultProps: {},
          },
          activeTabData: {
            props: {
              isClassicAvailable: true,
            },
          },
        },
      });
    });

    it('shows header', () => {
      expect(findDuoChat().props('showHeader')).toBe(true);
    });

    it('does not set up window resize listeners on mount', () => {
      const addEventListenerSpy = jest.spyOn(window, 'addEventListener');
      createComponent({
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            isClassicAvailable: true,
            defaultProps: {},
          },
          activeTabData: {
            props: {
              isClassicAvailable: true,
            },
          },
        },
      });

      const resizeCalls = addEventListenerSpy.mock.calls.filter(([event]) => event === 'resize');
      expect(resizeCalls).toHaveLength(0);
      addEventListenerSpy.mockRestore();
    });

    it('does not try to clean up resize listeners on destroy', () => {
      const removeEventListenerSpy = jest.spyOn(window, 'removeEventListener');
      wrapper.destroy();

      const resizeCalls = removeEventListenerSpy.mock.calls.filter(([event]) => event === 'resize');
      expect(resizeCalls).toHaveLength(0);
      removeEventListenerSpy.mockRestore();
    });

    it('calls setAgenticMode when toggling classic mode', async () => {
      getCookie.mockReturnValue('false');

      // Recreate component to show Classic toggle
      createComponent({
        propsData: { forceAgenticModeForCoreDuoUsers: false },
        provide: {
          chatConfiguration: {
            title: 'GitLab Duo Agentic Chat',
            defaultProps: {
              isClassicAvailable: true,
            },
          },
          activeTabData: {
            props: {
              isClassicAvailable: true,
            },
          },
        },
      });

      const findAgenticModeToggle = () => wrapper.findComponent(AgenticModeToggle);

      // Toggle directly controls agentic mode - false means agentic mode is disabled
      findAgenticModeToggle().vm.$emit('change', false);
      await nextTick();

      expect(setAgenticMode).toHaveBeenCalledWith({
        agenticMode: false,
        saveCookie: true,
      });
    });

    it('does not hydrate the active thread when a thread is selected', async () => {
      const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };
      const mockParsedData = {
        checkpoint: { channel_values: { ui_chat_log: [] } },
      };

      WorkflowUtils.parseWorkflowData.mockReturnValue(mockParsedData);
      WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

      findDuoChat().vm.$emit('thread-selected', mockThread);
      await waitForPromises();

      expect(findDuoChat().props('messages')).toEqual([]);
    });

    describe('Apollo queries', () => {
      beforeEach(async () => {
        createComponent({
          propsData: {
            userModelSelectionEnabled: true,
            rootNamespaceId: MOCK_NAMESPACE_ID,
          },
          provide: {
            chatConfiguration: {
              title: 'GitLab Duo Agentic Chat',
              isClassicAvailable: true,
              defaultProps: {},
            },
            activeTabData: {
              props: {
                isClassicAvailable: true,
              },
            },
          },
        });
        await waitForPromises();
      });

      it('runs agenticWorkflows GraphQL query on mount', () => {
        expect(userWorkflowsQueryHandlerMock).toHaveBeenCalled();
      });

      it('runs contextPresets GraphQL query on mount', () => {
        expect(contextPresetsQueryHandlerMock).toHaveBeenCalled();
      });

      it('runs availableModels GraphQL query on mount', () => {
        expect(availableModelsQueryHandlerMock).toHaveBeenCalled();
      });

      it('runs catalogAgents GraphQL query on mount', () => {
        expect(configuredAgentsQueryMock).toHaveBeenCalled();
      });
    });

    describe('@thread-selected event', () => {
      it('navigates to agentic chat route when thread is selected', async () => {
        // A thread is selected from the history list, so start on that route.
        createComponent({ routeName: AGENTIC_CHAT_HISTORY_ROUTE });
        await waitForPromises();

        const mockThread = { id: MOCK_WORKFLOW_ID, aiCatalogItemVersionId: null };
        const mockParsedData = { checkpoint: { channel_values: { ui_chat_log: [] } } };

        WorkflowUtils.parseWorkflowData.mockReturnValue(mockParsedData);
        WorkflowUtils.transformChatMessages.mockReturnValue(MOCK_TRANSFORMED_MESSAGES);

        findDuoChat().vm.$emit('thread-selected', mockThread);
        await waitForPromises();

        expect(mockRouter.push).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
      });
    });
  });

  describe('Chat snapshot caching', () => {
    beforeEach(() => {
      MOCK_UTILS_SETUP();
      jest.clearAllMocks();
    });

    describe('hydrateActiveWorkflow', () => {
      describe('when cached messages exist', () => {
        beforeEach(() => {
          loadThreadSnapshot.mockReturnValue(threadSnapshotWithMessages);

          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: { workflowId: MOCK_WORKFLOW_ID },
          });
          createComponent();
        });

        it('loads cached messages once the workflow status is confirmed active', async () => {
          await waitForPromises();
          expect(loadThreadSnapshot).toHaveBeenCalledWith(MOCK_WORKFLOW_ID);
          expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), snapshotMessages);
        });

        it('updates with fresh messages from API after cache is loaded', async () => {
          await waitForPromises();

          // First call: cached messages
          expect(actionSpies.setMessages).toHaveBeenNthCalledWith(
            1,
            expect.anything(),
            snapshotMessages,
          );

          // Second call: fresh messages from API
          expect(actionSpies.setMessages).toHaveBeenNthCalledWith(
            2,
            expect.anything(),
            MOCK_TRANSFORMED_MESSAGES,
          );
        });
      });

      describe('when no cached messages exist', () => {
        beforeEach(() => {
          loadThreadSnapshot.mockReturnValue(threadSnapshotEmpty);

          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: { workflowId: MOCK_WORKFLOW_ID },
          });

          createComponent();
        });

        it('does not set messages from cache', async () => {
          await waitForPromises();

          expect(loadThreadSnapshot).toHaveBeenCalledWith(MOCK_WORKFLOW_ID);
          // Only called once with API data, not with cache
          expect(actionSpies.setMessages).toHaveBeenCalledTimes(1);
          expect(actionSpies.setMessages).toHaveBeenCalledWith(
            expect.anything(),
            MOCK_TRANSFORMED_MESSAGES,
          );
        });

        it('still fetches messages from API', async () => {
          await waitForPromises();
          expect(workflowEventsQueryMock).toHaveBeenCalled();
        });
      });

      describe('when active workflow thread is archived', () => {
        beforeEach(async () => {
          loadThreadSnapshot.mockReturnValue(threadSnapshotEmpty);

          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: { workflowId: MOCK_WORKFLOW_ID },
          });

          userWorkflowsQueryHandlerMock.mockResolvedValue({
            data: {
              duoWorkflowWorkflows: {
                edges: [
                  {
                    node: {
                      id: MOCK_WORKFLOW_ID,
                      title: 'Test workflow goal',
                      lastUpdatedAt: '2024-01-01T00:00:00Z',
                      aiCatalogItemVersionId: null,
                      agentName: 'GitLab Duo',
                      archived: true,
                      stalled: false,
                    },
                  },
                ],
              },
            },
          });

          createComponent();
          await waitForPromises();
        });

        it('shows archived empty state instead of loading thread', () => {
          const duoChat = findDuoChat();
          const customEmptyState = getInstanceSlots(duoChat.vm)['custom-empty-state']({});

          expect(customEmptyState).toBeDefined();
        });

        it('disables chat input', () => {
          expect(findDuoChat().props('chatState')).toMatchObject({
            isEnabled: false,
            reason: expect.stringContaining('archived'),
          });
        });

        it('does not fetch workflow events', () => {
          expect(workflowEventsQueryMock).not.toHaveBeenCalled();
        });

        it('clears the stored snapshot so a stale cache is not painted later', () => {
          expect(clearThreadSnapshot).toHaveBeenCalledWith(MOCK_WORKFLOW_ID);
        });
      });

      describe('when the persisted workflow is missing from the user workflow list', () => {
        beforeEach(async () => {
          loadThreadSnapshot.mockReturnValue(threadSnapshotWithMessages);

          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: { workflowId: MOCK_WORKFLOW_ID },
          });

          userWorkflowsQueryHandlerMock.mockResolvedValue({
            data: { duoWorkflowWorkflows: { edges: [] } },
          });

          createComponent();
          await waitForPromises();
        });

        it('clears the stored snapshot', () => {
          expect(clearThreadSnapshot).toHaveBeenCalledWith(MOCK_WORKFLOW_ID);
        });

        it('does not fetch workflow events', () => {
          expect(workflowEventsQueryMock).not.toHaveBeenCalled();
        });
      });

      describe('when server reports credits exhausted', () => {
        beforeEach(async () => {
          loadThreadSnapshot.mockReturnValue(threadSnapshotEmpty);

          creditsAvailableQueryMock.mockResolvedValue({
            data: { gitlabCreditsAvailable: false, gitlabCreditsUnavailableReason: null },
          });

          WorkflowUtils.transformChatMessages.mockReturnValue([]);
          WorkflowUtils.parseWorkflowData.mockReturnValue({
            checkpoint: { channel_values: { ui_chat_log: [] } },
          });

          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: { workflowId: MOCK_WORKFLOW_ID },
          });

          createComponent();

          await waitForPromises();
        });

        it('disables chat due to credit exhaustion', () => {
          expect(findDuoChat().props('chatState')).toMatchObject({
            isEnabled: false,
            reason: '',
          });
        });

        it('resets loading, waiting, and processing state', async () => {
          wrapper.vm.isLoading = true;
          wrapper.vm.isWaitingOnPrompt = true;
          wrapper.vm.isProcessingMessage = true;

          wrapper.vm.setOutOfCredits();
          await nextTick();

          expect(wrapper.vm.isLoading).toBe(false);
          expect(wrapper.vm.isWaitingOnPrompt).toBe(false);
          expect(wrapper.vm.isProcessingMessage).toBe(false);
        });
      });

      describe('when server reports billing forbidden', () => {
        beforeEach(async () => {
          loadThreadSnapshot.mockReturnValue(threadSnapshotEmpty);

          creditsAvailableQueryMock.mockResolvedValue({
            data: {
              gitlabCreditsAvailable: false,
              gitlabCreditsUnavailableReason: 'USAGE_BILLING_FORBIDDEN',
            },
          });

          WorkflowUtils.transformChatMessages.mockReturnValue([]);
          WorkflowUtils.parseWorkflowData.mockReturnValue({
            checkpoint: { channel_values: { ui_chat_log: [] } },
          });

          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: { workflowId: MOCK_WORKFLOW_ID },
          });

          duoChatGlobalState.isAgenticChatShown = true;

          createComponent();

          await waitForPromises();
        });

        it('disables chat with billing forbidden message', () => {
          expect(findDuoChat().props('chatState')).toMatchObject({
            isEnabled: false,
            reason: expect.stringContaining('contact your administrator'),
          });
        });
      });
    });

    describe('when workflow definition is agentic_chat/v1 and agenticChatFlowRegistryMigration is disabled', () => {
      let onNewChatSpy;

      beforeEach(async () => {
        onNewChatSpy = jest.spyOn(DuoAgenticChatStateManager.methods, 'onNewChat');

        workflowEventsQueryMock.mockResolvedValue({
          data: {
            duoWorkflowWorkflows: {
              nodes: [
                {
                  id: 'workflow-1',
                  status: 'completed',
                  aiCatalogItemVersionId: null,
                  workflowDefinition: DUO_WORKFLOW_NEW_CHAT_DEFINITION,
                  archived: false,
                  stalled: false,
                  webSearchEnabled: false,
                  latestCheckpoint: {
                    workflowGoal: '',
                    workflowStatus: 'completed',
                    errors: null,
                    duoMessages: [],
                  },
                },
              ],
            },
          },
        });

        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent({
          provide: { glFeatures: { agenticChatFlowRegistryMigration: false } },
        });
        await waitForPromises();
      });

      it('calls onNewChat instead of loading the thread', () => {
        expect(onNewChatSpy).toHaveBeenCalled();
      });
    });

    describe('setCurrentAgent action', () => {
      beforeEach(() => {
        actionSpies.setCurrentAgent.mockClear();
      });

      it('calls setCurrentAgent with catalog agent after loading thread', async () => {
        const mockCatalogAgent = {
          id: 'Agent 5',
          name: 'My Custom Agent',
          description: 'This is my custom agent',
          itemType: 'AGENT',
          foundational: false,
          latestVersion: { id: 'AgentVersion 5', versionName: '1.0.0' },
          pinnedItemVersionId: 'AgentVersion 5',
          pinnedItemVersion: { id: 'AgentVersion 5', versionName: '1.0.0' },
        };

        workflowEventsQueryMock.mockResolvedValue({
          data: {
            duoWorkflowWorkflows: {
              nodes: [
                {
                  id: 'workflow-1',
                  status: 'completed',
                  aiCatalogItemVersionId: 'AgentVersion 5',
                  workflowDefinition: null,
                  archived: false,
                  stalled: false,
                  webSearchEnabled: false,
                  latestCheckpoint: null,
                },
              ],
            },
          },
        });

        WorkflowUtils.transformChatMessages.mockReturnValue([]);
        WorkflowUtils.parseWorkflowData.mockReturnValue({
          workflowGoal: '',
          workflowStatus: 'completed',
          errors: null,
          duoMessages: [],
        });

        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent({
          data: {
            catalogAgents: [mockCatalogAgent],
          },
        });

        await waitForPromises();

        expect(actionSpies.setCurrentAgent).toHaveBeenCalledWith(
          expect.anything(),
          mockCatalogAgent,
        );
      });

      it('calls setCurrentAgent with foundational agent after loading thread', async () => {
        workflowEventsQueryMock.mockResolvedValue({
          data: MOCK_WORKFLOW_EVENTS_RESPONSE_WITH_FOUNDATIONAL_AGENT,
        });

        WorkflowUtils.transformChatMessages.mockReturnValue([]);
        WorkflowUtils.parseWorkflowData.mockReturnValue({
          checkpoint: { channel_values: { ui_chat_log: [] } },
          workflowStatus: 'completed',
        });

        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent();

        await waitForPromises();

        expect(actionSpies.setCurrentAgent).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            referenceWithVersion: MOCK_FETCHED_FOUNDATIONAL_AGENT.referenceWithVersion,
          }),
        );
      });

      it('calls setCurrentAgent(null) when no agent is associated with thread', async () => {
        workflowEventsQueryMock.mockResolvedValue({
          data: {
            duoWorkflowWorkflows: {
              nodes: [
                {
                  id: 'workflow-1',
                  status: 'completed',
                  aiCatalogItemVersionId: '',
                  workflowDefinition: null,
                  archived: false,
                  stalled: false,
                  webSearchEnabled: false,
                  latestCheckpoint: null,
                },
              ],
            },
          },
        });

        WorkflowUtils.transformChatMessages.mockReturnValue([]);
        WorkflowUtils.parseWorkflowData.mockReturnValue({
          workflowGoal: '',
          workflowStatus: 'completed',
          errors: null,
          duoMessages: [],
        });

        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent();

        await waitForPromises();

        expect(actionSpies.setCurrentAgent).toHaveBeenCalledWith(expect.anything(), null);
      });
    });

    describe('reconnection with custom agent', () => {
      const MOCK_CUSTOM_AGENT_VERSION_ID = 'AgentVersion 5';

      afterEach(() => {
        streamManager.getStatus.mockReturnValue({ connected: false, bufferedCount: 0 });
      });

      beforeEach(() => {
        actionSpies.setCurrentAgent.mockClear();

        workflowEventsQueryMock.mockResolvedValue({
          data: {
            duoWorkflowWorkflows: {
              nodes: [
                {
                  id: 'workflow-1',
                  status: 'running',
                  aiCatalogItemVersionId: MOCK_CUSTOM_AGENT_VERSION_ID,
                  workflowDefinition: null,
                  archived: false,
                  stalled: false,
                  webSearchEnabled: false,
                  latestCheckpoint: {
                    workflowGoal: '',
                    workflowStatus: DUO_WORKFLOW_STATUS_RUNNING,
                    errors: null,
                    duoMessages: [],
                  },
                },
              ],
            },
          },
        });

        WorkflowUtils.transformChatMessages.mockReturnValue([]);
        WorkflowUtils.parseWorkflowData.mockReturnValue({
          workflowGoal: '',
          workflowStatus: DUO_WORKFLOW_STATUS_RUNNING,
          errors: null,
          duoMessages: [],
        });
      });

      it('reconnects to a running custom agent workflow', async () => {
        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent({
          data: {
            catalogAgents: [
              {
                id: 'Agent 5',
                name: 'My Custom Agent',
                pinnedItemVersionId: MOCK_CUSTOM_AGENT_VERSION_ID,
              },
            ],
          },
        });

        await waitForPromises();

        expect(streamManager.connect).toHaveBeenCalled();
      });

      it('sets aiCatalogItemVersionId before calling startWorkflow on reconnect', async () => {
        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent({
          data: {
            catalogAgents: [
              {
                id: 'Agent 5',
                name: 'My Custom Agent',
                pinnedItemVersionId: MOCK_CUSTOM_AGENT_VERSION_ID,
              },
            ],
          },
        });

        await waitForPromises();

        expect(wrapper.vm.aiCatalogItemVersionId).toBe(MOCK_CUSTOM_AGENT_VERSION_ID);
        expect(WorkflowSocketUtils.buildStartRequest).toHaveBeenCalled();
      });

      it('does not reconnect when workflow status is not RUNNING', async () => {
        WorkflowUtils.parseWorkflowData.mockReturnValue({
          checkpoint: { channel_values: { ui_chat_log: [] } },
          workflowStatus: 'completed',
        });

        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent({
          data: {
            catalogAgents: [
              {
                id: 'Agent 5',
                name: 'My Custom Agent',
                pinnedItemVersionId: MOCK_CUSTOM_AGENT_VERSION_ID,
              },
            ],
          },
        });

        await waitForPromises();

        expect(streamManager.connect).not.toHaveBeenCalled();
      });

      it('does not reconnect when stream is already connected', async () => {
        streamManager.getStatus.mockReturnValue({ connected: true, bufferedCount: 0 });

        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent({
          data: {
            catalogAgents: [
              {
                id: 'Agent 5',
                name: 'My Custom Agent',
                pinnedItemVersionId: MOCK_CUSTOM_AGENT_VERSION_ID,
              },
            ],
          },
        });

        await waitForPromises();

        expect(streamManager.connect).not.toHaveBeenCalled();
      });
    });

    describe('connectToStream', () => {
      afterEach(() => {
        streamManager.getStatus.mockReturnValue({ connected: false, bufferedCount: 0 });
      });

      it('does not force the chat view when a stream is already active', async () => {
        streamManager.getStatus.mockReturnValue({ connected: true, bufferedCount: 0 });

        createComponent({ routeName: AGENTIC_CHAT_HISTORY_ROUTE });
        await waitForPromises();

        wrapper.vm.connectToStream();
        await nextTick();

        expect(findDuoChat().props('multiThreadedView')).toBe(DUO_CHAT_VIEWS.LIST);
      });
    });

    describe('messages watcher', () => {
      it('has debounced watcher for messages', () => {
        createComponent();

        // Verify the watcher exists by checking component options
        const watchers = wrapper.vm.$options.watch;
        expect(watchers.messages).toBeDefined();
        expect(watchers.messages.deep).toBe(true);
      });
    });

    describe('default agent avatar on initial load', () => {
      it('passes the default foundational agent id and avatar to the chat view when no agent is selected', async () => {
        createComponent();
        await waitForPromises();

        const { id, avatarUrl } =
          MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE.data.aiFoundationalChatAgents.nodes[0];

        expect(findDuoChat().props('agentId')).toBe(id);
        expect(findDuoChat().props('agentAvatarUrl')).toBe(avatarUrl);
      });
    });

    describe('transformedMessages', () => {
      it('passes the transformer pipeline output to duo-agentic-chat-view', async () => {
        const rawMessages = [{ content: 'hello', role: 'user', requestId: 'r1' }];
        const transformedOutput = [
          { content: 'hello (transformed)', role: 'user', requestId: 'r1' },
        ];
        runMessageTransformers.mockReturnValue(transformedOutput);

        createComponent();
        await store.dispatch('setMessages', rawMessages);
        await nextTick();

        expect(runMessageTransformers).toHaveBeenCalledWith(rawMessages, expect.any(Array));
        expect(findDuoChat().props('messages')).toEqual(transformedOutput);
      });
    });

    describe('integration scenarios', () => {
      it('loads cached messages on mount when available', async () => {
        loadThreadSnapshot.mockReturnValue(threadSnapshotWithMessages);

        getSessionStorageValue.mockReturnValue({
          exists: true,
          value: { workflowId: MOCK_WORKFLOW_ID },
        });

        createComponent();
        await waitForPromises();

        // Cache was loaded
        expect(loadThreadSnapshot).toHaveBeenCalledWith(MOCK_WORKFLOW_ID);
        // Messages were set from cache
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), snapshotMessages);
      });

      it('does not clear cache when starting new conversation', () => {
        createComponent();
        wrapper.vm.workflowId = MOCK_WORKFLOW_ID;

        findDuoChat().vm.$emit('new-chat');

        // Cache was cleared for the workflow
        expect(clearThreadSnapshot).not.toHaveBeenCalled();
        // Messages were reset
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
      });
    });
  });

  describe('Duo UI Next', () => {
    describe('when the feature flag is disabled', () => {
      it('does not render the DuoNext component by default', () => {
        createComponent();
        expect(findDuoNext().exists()).toBe(false);
      });
    });

    describe('when the feature flag is enabled', () => {
      beforeEach(() => {
        createComponent({
          provide: {
            glFeatures: {
              duoUiNext: true,
            },
          },
        });
      });

      it('renders the DuoNext component if the flag is enabled', () => {
        expect(findDuoNext().exists()).toBe(true);
        expect(findDuoChat().exists()).toBe(false);
      });
    });
  });

  describe('Credit limitation', () => {
    describe('when credits are unavailable on load', () => {
      beforeEach(async () => {
        creditsAvailableQueryMock.mockResolvedValue({
          data: { gitlabCreditsAvailable: false, gitlabCreditsUnavailableReason: null },
        });

        createComponent();
        await waitForPromises();
      });

      it('disables chat when credits are exhausted', () => {
        const duoChat = findDuoChat();

        expect(duoChat.props('chatState')).toMatchObject({
          isEnabled: false,
          reason: '',
        });
      });

      it('hides model selector when userModelSelectionEnabled is true', async () => {
        creditsAvailableQueryMock.mockResolvedValue({
          data: { gitlabCreditsAvailable: false, gitlabCreditsUnavailableReason: null },
        });

        createComponent({
          propsData: {
            userModelSelectionEnabled: true,
          },
        });
        await waitForPromises();

        const modelSelector = wrapper.findComponent(ModelSelectDropdown);
        expect(modelSelector.exists()).toBe(false);
      });

      it('renders custom empty state in duo chat', () => {
        const duoChat = findDuoChat();
        const customEmptyStateSlot = getInstanceSlots(duoChat.vm)['custom-empty-state'];

        expect(customEmptyStateSlot).toBeDefined();
        expect(typeof customEmptyStateSlot).toBe('function');

        const customEmptyState = customEmptyStateSlot({});
        expect(customEmptyState).toBeDefined();
      });
    });

    describe('when credits are available on load', () => {
      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('passes enabled chatState to duo chat component', () => {
        const duoChat = findDuoChat();

        expect(duoChat.props('chatState')).toMatchObject({
          isEnabled: true,
        });
      });

      it('shows model selector when userModelSelectionEnabled is true', async () => {
        createComponent({
          propsData: {
            userModelSelectionEnabled: true,
          },
        });
        await waitForPromises();

        const modelSelector = wrapper.findComponent(ModelSelectDropdown);
        expect(modelSelector.exists()).toBe(true);
      });
    });

    describe('runtime credit exhaustion', () => {
      describe('and the code is 1008 (insufficient credits)', () => {
        beforeEach(async () => {
          createComponent({
            propsData: {
              userModelSelectionEnabled: true,
            },
          });
          findDuoChat().vm.$emit('send-chat-prompt', 'test message');
          await waitForPromises();

          triggerStreamEvent('close', {
            type: 'close',
            code: 1008,
            reason: 'Insufficient credits: quota exceeded',
          });
          await waitForPromises();
          await nextTick();
        });

        it('disables chat when credits are exhausted', () => {
          const duoChat = findDuoChat();

          expect(duoChat.props('chatState')).toMatchObject({
            isEnabled: false,
            reason: '',
          });
        });

        it('hides model selector', () => {
          const modelSelector = wrapper.findComponent(ModelSelectDropdown);
          expect(modelSelector.exists()).toBe(false);
        });
      });

      describe('and the code is 1008 with USAGE_BILLING_FORBIDDEN reason', () => {
        beforeEach(async () => {
          createComponent({
            propsData: {
              userModelSelectionEnabled: true,
            },
          });
          findDuoChat().vm.$emit('send-chat-prompt', 'test message');
          await waitForPromises();

          triggerStreamEvent('close', {
            type: 'close',
            code: 1008,
            reason: 'USAGE_BILLING_FORBIDDEN: Usage billing not available',
          });
          await waitForPromises();
          await nextTick();
        });

        it('disables chat with billing forbidden message', () => {
          expect(findDuoChat().props('chatState')).toMatchObject({
            isEnabled: false,
            reason: expect.stringContaining('contact your administrator'),
          });
        });
      });
    });
  });

  describe('trackBinaryFeedbackEvent', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('calls trackEvent with correct parameters when track-feedback is emitted', async () => {
      getSessionStorageValue.mockReturnValueOnce({
        exists: true,
        value: { workflowId: MOCK_WORKFLOW_ID },
      });
      createComponent();
      await waitForPromises();

      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      const feedbackEvent = { feedbackType: 'thumbs_up', feedbackReason: 'accurate' };
      findDuoChat().vm.$emit('track-feedback', feedbackEvent);

      expect(trackEventSpy).toHaveBeenCalledWith(
        FEEDBACK_TRACKING_EVENT,
        expect.objectContaining({
          label: 'thumbs_up',
          value: 456,
          property: 'accurate',
        }),
        undefined,
      );
    });
  });

  describe('computedTrustedUrls', () => {
    beforeEach(() => {
      window.gon = {};
    });

    afterEach(() => {
      delete window.gon;
    });

    it('includes default trusted URLs (gitlab.com and docs URL)', () => {
      createComponent();
      const trustedUrls = wrapper.vm.computedTrustedUrls;

      expect(trustedUrls).toContain('gitlab.com');
      expect(trustedUrls).toContain(docsUrlHost);
    });

    it('includes instance hostname from gon.gitlab_url when available', () => {
      window.gon.gitlab_url = 'https://gitlab.example.com';
      createComponent();
      const trustedUrls = wrapper.vm.computedTrustedUrls;

      expect(trustedUrls).toContain('gitlab.example.com');
    });

    it('does not include instance hostname when gon.gitlab_url is not set', () => {
      createComponent();
      const trustedUrls = wrapper.vm.computedTrustedUrls;

      expect(trustedUrls).not.toContain('my-gitlab.example.com');
    });

    it('includes additional URLs passed as props', () => {
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
          trustedUrls: ['custom1.example.com', 'custom2.example.com'],
        },
      });
      const trustedUrls = wrapper.vm.computedTrustedUrls;

      expect(trustedUrls).toContain('custom1.example.com');
      expect(trustedUrls).toContain('custom2.example.com');
    });

    it('removes duplicate URLs', () => {
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
          trustedUrls: ['gitlab.com', `https://${docsUrlHost}`],
        },
      });
      const trustedUrls = wrapper.vm.computedTrustedUrls;

      const gitlabComCount = trustedUrls.filter((url) => url === 'gitlab.com').length;
      const docsUrlCount = trustedUrls.filter((url) => url === docsUrlHost).length;

      expect(gitlabComCount).toBe(1);
      expect(docsUrlCount).toBe(1);
    });

    it('returns an array of unique hostnames', () => {
      window.gon.gitlab_url = 'https://my-gitlab.example.com';
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
          trustedUrls: ['https://custom.example.com'],
        },
      });
      const trustedUrls = wrapper.vm.computedTrustedUrls;

      expect(Array.isArray(trustedUrls)).toBe(true);
      expect(new Set(trustedUrls).size).toBe(trustedUrls.length);
    });

    it('handles empty trustedUrls prop gracefully', () => {
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
          trustedUrls: [],
        },
      });
      const trustedUrls = wrapper.vm.computedTrustedUrls;

      expect(trustedUrls).toContain('gitlab.com');
      expect(trustedUrls).toContain(docsUrlHost);
    });

    it('handles null trustedUrls prop gracefully', () => {
      createComponent({
        propsData: {
          projectId: MOCK_PROJECT_ID,
          resourceId: MOCK_RESOURCE_ID,
          trustedUrls: null,
        },
      });
      const trustedUrls = wrapper.vm.computedTrustedUrls;

      expect(trustedUrls).toContain('gitlab.com');
      expect(trustedUrls).toContain(docsUrlHost);
    });
  });

  describe('deferred agent selection', () => {
    let resolveFoundationalAgents;
    let resolveCatalogAgents;

    const pendingFoundationalAgentsMocks = () => {
      aiFoundationalChatAgentsQueryMock.mockReturnValueOnce(
        new Promise((resolve) => {
          resolveFoundationalAgents = resolve;
        }),
      );
      configuredAgentsQueryMock.mockResolvedValueOnce({
        data: {
          aiCatalogConfiguredItems: {
            nodes: [],
            pageInfo: { hasNextPage: false, endCursor: null },
            __typename: 'AiCatalogItemConsumerConnection',
          },
        },
      });
    };

    const pendingCatalogAgentsMocks = () => {
      aiFoundationalChatAgentsQueryMock.mockResolvedValueOnce(
        MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE,
      );
      configuredAgentsQueryMock.mockReturnValueOnce(
        new Promise((resolve) => {
          resolveCatalogAgents = resolve;
        }),
      );
    };

    const pushAgentCommand = async (agentName) => {
      duoChatGlobalState.commands = [{ agent: { name: agentName }, autoSend: false }];
      await nextTick();
    };

    const resolveFoundational = async (response = MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE) => {
      resolveFoundationalAgents(response);
      await waitForPromises();
    };

    const resolveCatalog = async () => {
      resolveCatalogAgents({
        data: {
          aiCatalogConfiguredItems: {
            nodes: [],
            pageInfo: { hasNextPage: false, endCursor: null },
            __typename: 'AiCatalogItemConsumerConnection',
          },
        },
      });
      await waitForPromises();
    };

    it('does not process agent command while foundationalAgents are loading', async () => {
      pendingFoundationalAgentsMocks();
      createComponent({
        propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
      });

      await pushAgentCommand(DUO_FOUNDATIONAL_AGENT_MOCK.name);

      expect(actionSpies.setCurrentAgent).not.toHaveBeenCalled();
      // Command should still be in the queue (not consumed)
      expect(duoChatGlobalState.commands).toHaveLength(1);
    });

    it('does not process agent command while catalogAgents are loading', async () => {
      pendingCatalogAgentsMocks();
      createComponent({
        propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
      });

      await pushAgentCommand(DUO_FOUNDATIONAL_AGENT_MOCK.name);

      expect(actionSpies.setCurrentAgent).not.toHaveBeenCalled();
      expect(duoChatGlobalState.commands).toHaveLength(1);
    });

    it('selects the agent when agents finish loading', async () => {
      pendingFoundationalAgentsMocks();
      createComponent({
        propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
      });

      await pushAgentCommand(DUO_FOUNDATIONAL_AGENT_MOCK.name);
      await resolveFoundational();

      expect(actionSpies.setCurrentAgent).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ name: DUO_FOUNDATIONAL_AGENT_MOCK.name }),
      );
    });

    it('selects the agent when catalogAgents finish loading', async () => {
      pendingCatalogAgentsMocks();
      createComponent({
        propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
      });

      await pushAgentCommand(DUO_FOUNDATIONAL_AGENT_MOCK.name);
      await resolveCatalog();

      expect(actionSpies.setCurrentAgent).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ name: DUO_FOUNDATIONAL_AGENT_MOCK.name }),
      );
    });

    it('uses the correct agent definition when creating a workflow', async () => {
      pendingFoundationalAgentsMocks();
      createComponent({
        propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
      });

      await pushAgentCommand(DUO_FOUNDATIONAL_AGENT_MOCK.name);
      await resolveFoundational();

      findDuoChat().vm.$emit('send-chat-prompt', 'test question');
      await waitForPromises();

      expect(createWorkflowMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          workflowDefinition: DUO_FOUNDATIONAL_AGENT_MOCK.referenceWithVersion,
        }),
      );
    });

    it('does not select the agent when it is not in the loaded list', async () => {
      pendingFoundationalAgentsMocks();
      createComponent({
        propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
      });

      await pushAgentCommand('Non-existent Agent');
      await resolveFoundational();

      expect(actionSpies.setCurrentAgent).not.toHaveBeenCalled();
    });
  });

  describe('processPendingCommands integration', () => {
    it('does not process commands when isLoading is true', async () => {
      let resolvePromise = null;
      const pendingPromise = new Promise((resolve) => {
        resolvePromise = resolve;
      });
      workflowEventsQueryMock.mockReturnValue(pendingPromise);

      getSessionStorageValue.mockReturnValue({
        exists: true,
        value: { workflowId: MOCK_WORKFLOW_ID },
      });
      createComponent({
        propsData: { projectId: MOCK_PROJECT_ID, resourceId: MOCK_RESOURCE_ID },
      });

      await nextTick();

      const testQuestion = 'What is GitLab CI/CD?';

      duoChatGlobalState.commands = [{ question: testQuestion }];

      await nextTick();

      expect(createWorkflowMutationMock).not.toHaveBeenCalled();

      resolvePromise({ data: MOCK_WORKFLOW_EVENTS_RESPONSE });

      await waitForPromises();

      await nextTick();

      // Commands should be processed after hydration completes
      expect(createWorkflowMutationMock).toHaveBeenCalledWith(
        expect.objectContaining({
          goal: testQuestion,
        }),
      );
    });
  });

  describe('triggerSource', () => {
    it('is set to web_chat when user sends a prompt', async () => {
      createComponent();
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', 'some question');

      findDuoChat().vm.$emit('approve-tool');
      await nextTick();

      expect(EventsTracker.updateContext).toHaveBeenCalledWith(
        expect.objectContaining({ triggerSource: TRIGGER_SOURCE_WEB_CHAT }),
      );
    });

    it('is set to web_ui when processing commands and passed to tracked events', async () => {
      createComponent();
      await waitForPromises();

      duoChatGlobalState.commands = [{ question: 'Deploy my app' }];
      await nextTick();
      await waitForPromises();

      findDuoChat().vm.$emit('approve-tool');
      await nextTick();

      expect(EventsTracker.updateContext).toHaveBeenCalledWith(
        expect.objectContaining({ triggerSource: TRIGGER_SOURCE_WEB_UI }),
      );
    });
  });

  describe('errorCaptured', () => {
    ignoreConsoleMessages([
      /^\[Vue warn\]: Error in mounted hook: "Error: child component exploded"/,
      /^Error: child component exploded/,
    ]);

    it('reports the error and component info to Sentry', () => {
      const error = new Error('child component exploded');

      try {
        createComponent({
          stubs: {
            DuoAgenticChatView: stubComponent(DuoAgenticChatView, {
              mounted() {
                throw error;
              },
            }),
          },
        });
      } catch {
        expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error, {
          extra: { info: 'mounted hook', component: 'DuoAgenticChatView' },
        });
      }
    });
  });
});
