import { waitFor } from '@testing-library/vue';
import { getText } from '../test_helpers';
import { installAgenticChatFlowHandlers } from '../handlers/duo_agentic_chat';
import {
  agentLogEntry,
  getCloseCount,
  pushCheckpoint,
  userLogEntry,
  waitForSocket,
} from './websocket_mock';
import {
  PROJECT_ID,
  cancelPrompt,
  findCancelButton,
  findChatMessages,
  findMessages,
  findSubmitButton,
  mountDuoAgenticChatStateManager,
  sendPrompt,
  setupDuoChatTest,
  teardownDuoChatTest,
} from './test_setup';

// Replaces the two cancel/retry examples from
// ee/spec/support/shared_examples/ai/agentic_chat_shared_example.rb.
//
// Those examples relied on wall-clock timing — the Capybara version asked the
// AI gateway mock for a 10-second stream and raced to click Cancel mid-flight,
// which is the flake behind
// https://gitlab.com/gitlab-org/quality/test-failure-issues/-/work_items/42787
// ("expected to find text \"workflow retried\""). Here the stream is driven
// explicitly, so "mid-stream" and "before the response arrives" are exact
// states rather than timing windows.

const FIRST_PROMPT = 'count to ten slowly';
const RETRY_PROMPT = 'workflow retried';

describe('Duo Agentic Chat | cancelling a response and retrying', () => {
  const mountAndSend = async (prompt) => {
    mountDuoAgenticChatStateManager({ propsData: { projectId: PROJECT_ID } });

    await waitFor(() => {
      expect(findSubmitButton()).not.toBe(null);
    });

    sendPrompt(prompt);

    // The worker opens the socket only once startWorkflow calls connect().
    await waitForSocket();

    // The cancel button replaces the submit button once a response is awaited.
    await waitFor(() => {
      expect(findCancelButton()).not.toBe(null);
    });
  };

  const cancelAndExpectRecovery = async () => {
    const closesBeforeCancel = getCloseCount();

    cancelPrompt();

    // Cancelling tears down the socket and re-enables the composer.
    await waitFor(() => {
      expect(getCloseCount()).toBeGreaterThan(closesBeforeCancel);
      expect(findSubmitButton()).not.toBe(null);
    });
  };

  beforeEach(() => {
    setupDuoChatTest();
    installAgenticChatFlowHandlers();
  });

  afterEach(() => teardownDuoChatTest());

  it('recovers when the user cancels mid-stream', async () => {
    await mountAndSend(FIRST_PROMPT);

    // A partial response has begun streaming: the user message and an
    // in-progress agent message are both on screen.
    await pushCheckpoint(
      [
        userLogEntry({ id: 'user-1', content: FIRST_PROMPT }),
        agentLogEntry({ id: 'agent-1', content: '1 2 3', status: 'running' }),
      ],
      { status: 'RUNNING', goal: FIRST_PROMPT },
    );

    await waitFor(() => {
      expect(findMessages()).toHaveLength(2);
    });

    await cancelAndExpectRecovery();

    // Chat is still functional: a follow-up prompt streams a full response.
    sendPrompt(RETRY_PROMPT);

    await pushCheckpoint(
      [
        userLogEntry({ id: 'user-1', content: FIRST_PROMPT }),
        agentLogEntry({ id: 'agent-1', content: '1 2 3', status: 'running' }),
        userLogEntry({ id: 'user-2', content: RETRY_PROMPT }),
        agentLogEntry({ id: 'agent-2', content: 'Retried and answered' }),
      ],
      { goal: RETRY_PROMPT },
    );

    // Message content renders through markdown asynchronously, so wait on the
    // answer text rather than the element count.
    await waitFor(() => {
      expect(getText(findChatMessages())).toContain('Retried and answered');
    });

    // Original prompt, cancelled response, retry prompt, retried response.
    expect(findMessages()).toHaveLength(4);
    expect(getText(findChatMessages())).toContain(RETRY_PROMPT);
  });

  it('recovers when the user cancels before any response arrives', async () => {
    await mountAndSend(FIRST_PROMPT);

    // No checkpoint has been pushed at all — the socket is open and silent.
    await cancelAndExpectRecovery();

    sendPrompt(RETRY_PROMPT);

    await pushCheckpoint(
      [
        userLogEntry({ id: 'user-2', content: RETRY_PROMPT }),
        agentLogEntry({ id: 'agent-2', content: 'Retried and answered' }),
      ],
      { goal: RETRY_PROMPT },
    );

    await waitFor(() => {
      expect(getText(findChatMessages())).toContain('Retried and answered');
    });

    expect(getText(findChatMessages())).toContain(RETRY_PROMPT);
  });
});
