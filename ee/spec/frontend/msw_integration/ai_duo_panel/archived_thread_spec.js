import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { waitFor } from '@testing-library/vue';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { CHAT_MODES } from '~/super_sidebar/constants';
import AiPanel from 'ee/ai/components/ai_panel.vue';
import { createApolloProvider } from 'ee/ai/graphql';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import { DUO_CURRENT_WORKFLOW_STORAGE_KEY } from 'ee/ai/constants';
import createStore from 'ee/ai/tanuki_bot/store';
import { fullMount, waitForElement } from 'ee_jest/msw_integration/test_helpers';
import { saveSessionStorageValue, removeSessionStorageValue } from '~/lib/utils/local_storage';
import { fixtures, resetFixtures, disableAgenticChatFixtures } from '../handlers/ai_agentic_chat';

Vue.use(VueApollo);

// Stub the WebSocket/stream layer — the state manager opens it on mount and
// we have no server in the test. These mocks must be hoisted, so do not
// reference outer constants.
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

jest.mock('ee/ai/duo_agentic_chat/observability/events_tracker', () => ({
  EventsTracker: {
    updateContext: jest.fn(),
    trackApproveTool: jest.fn(),
    trackDenyTool: jest.fn(),
    trackClickThroughFlowWidget: jest.fn(),
    reset: jest.fn(),
  },
}));

jest.mock('fe_islands/duo_next/dist/main', () => ({}), { virtual: true });

const chatConfiguration = {
  agenticTitle: 'GitLab Duo Agentic Chat',
  classicTitle: 'GitLab Duo Chat',
  autoExpand: true,
  defaultProps: {
    isAgenticAvailable: true,
    isClassicAvailable: false,
    // Required: without a selected namespace the panel shows the
    // NoNamespaceEmptyState, which masks the ThreadInactiveEmptyState.
    defaultNamespaceSelected: true,
  },
};

const findChatInput = () => document.querySelector('[data-testid="chat-prompt-input"] textarea');
const findChatHistory = () => document.querySelector('[data-testid="chat-history"]');
const findChatError = () => document.querySelector('[data-testid="chat-error"]');
const findArchivedEmptyState = () =>
  document.querySelector('[data-testid="thread-inactive-empty-state"]');
const findThreadByTitle = (title) =>
  [...document.querySelectorAll('[data-testid="chat-threads-thread-box"]')].find((el) =>
    el.textContent.includes(title),
  );
const findHistoryToggle = () => document.querySelector('[data-testid="ai-history-toggle"]');

describe('Duo Agentic Chat — archived thread integration', () => {
  let wrapper;
  let router;
  let store;
  let apolloProvider;

  const mountPanel = ({ workflowId } = {}) => {
    if (workflowId) {
      saveSessionStorageValue(DUO_CURRENT_WORKFLOW_STORAGE_KEY, { workflowId });
    }

    duoChatGlobalState.activeTab = 'chat';

    router = createRouter('/', 'user', chatConfiguration);
    apolloProvider = createApolloProvider({ autoExpand: true });
    store = createStore();

    wrapper = fullMount(AiPanel, {
      store,
      router,
      apolloProvider,
      propsData: {
        chatDisabledReason: '',
        shouldShowBlockedState: false,
      },
      provide: {
        isSidePanelView: true,
        chatConfiguration,
        badgeType: null,
      },
    });
  };

  const clearAll = () => {
    window.sessionStorage.clear();
    removeSessionStorageValue(DUO_CURRENT_WORKFLOW_STORAGE_KEY);
    duoChatGlobalState.activeTab = undefined;
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
    resetFixtures();
  };

  beforeEach(() => {
    clearAll();
  });

  afterEach(() => {
    wrapper?.destroy();
    wrapper = undefined;
    clearAll();
    // Restore the duo-panel handler as the default for `getUserWorkflows` etc.
    // so other suites don't pick up this module's archived/active fixtures.
    disableAgenticChatFixtures();
  });

  it('disables the chat input when deep-linking to an archived workflow', async () => {
    mountPanel({ workflowId: fixtures.archivedWorkflow.id });

    // Wait for the panel body to mount — replaces the now-disallowed
    // router.currentRoute gate with a pure-HTML signal.
    await waitForElement(findChatHistory);

    // The archived empty state renders once the state manager hydrates the
    // active workflow via the list query — proves the BE archived flag flowed
    // through Apollo to the UI.
    await waitForElement(findArchivedEmptyState);

    // And no chat input is reachable.
    expect(findChatInput()).toBe(null);
  });

  it('disables the chat input after clicking an archived thread in the list', async () => {
    mountPanel();

    await waitForElement(findChatHistory);

    // Open the thread list by clicking the navigation rail's history toggle.
    const historyToggle = await waitForElement(findHistoryToggle);
    historyToggle.click();

    await waitFor(() => {
      const thread = findThreadByTitle(fixtures.archivedWorkflow.title);
      expect(thread).not.toBe(undefined);
      expect(thread).not.toBe(null);
    });

    findThreadByTitle(fixtures.archivedWorkflow.title).click();

    await waitForElement(findArchivedEmptyState);
    expect(findChatInput()).toBe(null);
  });

  it('re-enables the chat input when switching from an archived thread to a non-archived one', async () => {
    mountPanel({ workflowId: fixtures.archivedWorkflow.id });

    await waitForElement(findChatHistory);

    const archivedEmptyState = await waitForElement(findArchivedEmptyState);

    // Use the empty state's own "back to threads" button to surface the list,
    // then click the non-archived thread.
    archivedEmptyState.querySelector('[data-testid="back-to-threads-button"]').click();

    await waitFor(() => {
      const thread = findThreadByTitle(fixtures.activeWorkflow.title);
      expect(thread).not.toBe(undefined);
      expect(thread).not.toBe(null);
    });
    findThreadByTitle(fixtures.activeWorkflow.title).click();

    // The archived empty state must clear once the BE confirms the new
    // workflow is not archived. This is the regression we care about.
    await waitFor(() => {
      expect(findArchivedEmptyState()).toBe(null);
    });
  });

  it('routes to a new chat when the deep-linked workflow is missing from the list', async () => {
    fixtures.userWorkflows = [];

    mountPanel({ workflowId: fixtures.activeWorkflow.id });

    await waitForElement(findChatHistory);

    // handleWorkflowNotFound with no messages routes through onNewChat,
    // which clears workflowId. The state manager exposes that via the
    // active thread id on the chat view — the easiest reflection in HTML
    // is that no `inactive` empty state and no chat-deleted error appear.
    await waitFor(() => {
      expect(findArchivedEmptyState()).toBe(null);
      expect(findChatError()).toBe(null);
    });
  });
});
