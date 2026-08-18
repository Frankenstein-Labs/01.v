import { waitFor } from '@testing-library/vue';
import { SkipReason, itSkipVue3 } from 'helpers/vue3_conditional';
import { getText } from '../test_helpers';
import { installAgenticChatFlowHandlers, seedWorkflow } from '../handlers/duo_agentic_chat';
import {
  agentLogEntry,
  getSockets,
  pushCheckpoint,
  userLogEntry,
  waitForSocket,
} from './websocket_mock';
import {
  buildChatConfiguration,
  findButton,
  findChatComponent,
  findChatMessages,
  findChatToggle,
  findDuoAgenticChatPanel,
  findEmptyState,
  findHistoryToggle,
  findMessages,
  findSessionsToggle,
  findSubmitButton,
  findThreadBoxWithText,
  findThreadBoxes,
  mountAISidebar,
  openChatTab,
  openHistoryTab,
  sendPrompt,
  setupDuoChatTest,
  teardownDuoChatTest,
} from './test_setup';

// Replaces the "allows basic UI interactions" and "shows session ID dropdown
// during active chat" examples from
// ee/spec/support/shared_examples/ai/agentic_chat_shared_example.rb.
//
// Mounts the whole panel because the navigation rail, the history round-trip and
// the session-id dropdown (gated on `$route.name`) all need the real router.

const QUESTION = 'dummy-question';
const ANSWER = 'mock answer';
const SECOND_QUESTION = 'dummy-question-2';
const SECOND_ANSWER = 'second mock answer';

const OLDER_WORKFLOW_ID = 'gid://gitlab/Ai::DuoWorkflows::Workflow/11';
const NEWER_WORKFLOW_ID = 'gid://gitlab/Ai::DuoWorkflows::Workflow/12';
const OLDER_QUESTION = 'first-thread-question';
const OLDER_ANSWER = 'first-thread-answer';
const NEWER_QUESTION = 'second-thread-question';
const NEWER_ANSWER = 'second-thread-answer';

const firstExchange = () => [
  userLogEntry({ id: 'user-1', content: QUESTION }),
  agentLogEntry({ id: 'agent-1', content: ANSWER }),
];

const secondExchange = () => [
  ...firstExchange(),
  userLogEntry({ id: 'user-2', content: SECOND_QUESTION }),
  agentLogEntry({ id: 'agent-2', content: SECOND_ANSWER }),
];

describe('Duo Agentic Chat | conversation lifecycle in the AI panel', () => {
  const mountPanel = () => mountAISidebar({ chatConfiguration: buildChatConfiguration() });

  const openChatAndWaitForComposer = async () => {
    await waitFor(() => {
      expect(findChatToggle()).not.toBe(null);
    });

    openChatTab();

    await waitFor(() => {
      expect(findSubmitButton()).not.toBe(null);
    });
  };

  const askAndAnswer = async ({ prompt, uiChatLog }) => {
    const socketsBefore = getSockets().length;

    sendPrompt(prompt);

    // Each startWorkflow opens a fresh socket; wait for this prompt's.
    await waitFor(() => {
      expect(getSockets()).toHaveLength(socketsBefore + 1);
    });
    await waitForSocket();

    return pushCheckpoint(uiChatLog(), { goal: prompt });
  };

  beforeEach(() => {
    setupDuoChatTest();
    installAgenticChatFlowHandlers();
  });

  afterEach(() => teardownDuoChatTest());

  it('exposes the navigation rail with the panel closed', async () => {
    mountPanel();

    await waitFor(() => {
      expect(findChatToggle()).not.toBe(null);
    });

    expect(findHistoryToggle()).not.toBe(null);
    expect(findSessionsToggle()).not.toBe(null);

    // Nothing is mounted into the panel until a tab is opened.
    expect(findDuoAgenticChatPanel()).toBe(null);
    expect(findChatComponent()).toBe(null);
  });

  it('opens the chat on the empty state and streams a full exchange', async () => {
    mountPanel();
    await openChatAndWaitForComposer();

    // The chat opens on its empty state. (The Capybara original asserted
    // "GitLab Duo Agent Platform" here, which is the SaaS trial/subscription
    // empty state rather than the chat's own -- those specs ran with `:saas`.)
    expect(findEmptyState()).not.toBe(null);
    expect(getText(findEmptyState())).toContain('I am GitLab Duo Agentic Chat');

    await askAndAnswer({ prompt: QUESTION, uiChatLog: firstExchange });

    await waitFor(() => {
      expect(getText(findChatMessages())).toContain(ANSWER);
    });

    expect(getText(findChatMessages())).toContain(QUESTION);

    // A follow-up appends to the same conversation rather than replacing it.
    await askAndAnswer({ prompt: SECOND_QUESTION, uiChatLog: secondExchange });

    await waitFor(() => {
      expect(getText(findChatMessages())).toContain(SECOND_ANSWER);
    });

    expect(findMessages()).toHaveLength(4);
  });

  // The dropdown this asserts on is passed to `<router-view>` as a named slot,
  // and the session id that gates it arrives through a listener on the same
  // element. vue-router 4 forwards neither, so under Vue 3 the feature itself is
  // missing rather than the test being wrong.
  const sessionIdSkipReason = new SkipReason({
    name: 'offers the session ID once a workflow is active',
    reason: 'vue-router 4 drops the router-view listeners and named slot ai_panel.vue relies on',
    issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/613325',
  });

  itSkipVue3(sessionIdSkipReason, async () => {
    mountPanel();
    await openChatAndWaitForComposer();

    // The dropdown only renders once a session id has been emitted, which
    // happens after the workflow is created.
    await askAndAnswer({ prompt: QUESTION, uiChatLog: firstExchange });

    const moreOptions = await waitFor(() => {
      const button = findButton('More options');
      expect(button).not.toBe(null);
      return button;
    });

    // The items are in the DOM whether or not the dropdown is open, so assert on
    // the toggle's own state as well as on the menu it controls -- otherwise this
    // passes without the click.
    expect(moreOptions.getAttribute('aria-expanded')).toBe('false');

    moreOptions.click();

    await waitFor(() => {
      expect(moreOptions.getAttribute('aria-expanded')).toBe('true');
    });

    const menu = document.getElementById(moreOptions.getAttribute('aria-controls'));
    expect(getText(menu)).toContain('Copy Chat Session ID');
  });

  it('lists the conversation in history and re-hydrates it on the way back', async () => {
    mountPanel();
    await openChatAndWaitForComposer();
    await askAndAnswer({ prompt: QUESTION, uiChatLog: firstExchange });

    await waitFor(() => {
      expect(getText(findChatMessages())).toContain(ANSWER);
    });

    openHistoryTab();

    // The thread the prompt created shows up in the history list, titled with
    // the goal it was created from.
    await waitFor(() => {
      expect(findThreadBoxes().length).toBeGreaterThan(0);
    });

    expect(findThreadBoxWithText(QUESTION)).not.toBe(null);

    openChatTab();

    // Going back re-reads the checkpoint over GraphQL, so both messages return.
    await waitFor(() => {
      expect(getText(findChatMessages())).toContain(ANSWER);
    });

    expect(getText(findChatMessages())).toContain(QUESTION);
  });

  it('hydrates the thread picked from history rather than the other one', async () => {
    // Two conversations already exist; only the older one's content should
    // appear after selecting it.
    seedWorkflow({
      id: OLDER_WORKFLOW_ID,
      title: OLDER_QUESTION,
      uiChatLog: [
        userLogEntry({ id: 'older-user', content: OLDER_QUESTION }),
        agentLogEntry({ id: 'older-agent', content: OLDER_ANSWER }),
      ],
    });
    seedWorkflow({
      id: NEWER_WORKFLOW_ID,
      title: NEWER_QUESTION,
      uiChatLog: [
        userLogEntry({ id: 'newer-user', content: NEWER_QUESTION }),
        agentLogEntry({ id: 'newer-agent', content: NEWER_ANSWER }),
      ],
    });

    mountPanel();

    await waitFor(() => {
      expect(findHistoryToggle()).not.toBe(null);
    });

    openHistoryTab();

    await waitFor(() => {
      expect(findThreadBoxes()).toHaveLength(2);
    });

    findThreadBoxWithText(OLDER_QUESTION).click();

    await waitFor(() => {
      expect(findDuoAgenticChatPanel()).not.toBe(null);
    });

    await waitFor(() => {
      expect(getText(findChatMessages())).toContain(OLDER_ANSWER);
    });

    expect(getText(findChatMessages())).not.toContain(NEWER_ANSWER);

    openHistoryTab();

    await waitFor(() => {
      expect(findThreadBoxes()).toHaveLength(2);
    });

    findThreadBoxWithText(NEWER_QUESTION).click();

    await waitFor(() => {
      expect(findDuoAgenticChatPanel()).not.toBe(null);
    });

    await waitFor(() => {
      expect(getText(findChatMessages())).toContain(NEWER_ANSWER);
    });
  });
});
