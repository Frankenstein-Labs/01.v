import { waitFor } from '@testing-library/vue';
import { waitForElement } from 'ee_jest/msw_integration/test_helpers';
import {
  buildChatConfiguration,
  findAgentSessionsPanel,
  findChatToggle,
  findDuoAgenticChatPanel,
  findHistoryToggle,
  findSessionsToggle,
  findThreadListPanel,
  mountAISidebar,
  setupDuoChatTest,
  teardownDuoChatTest,
} from '../duo_agentic_chat/test_setup';

// Replaces the "user can navigate AI panel using navigation rail" shared example
// that used to live in ee/spec/support/shared_examples/ai/agentic_chat_shared_example.rb.

// The real stream_manager and stream_worker run; only the websocket transport
// is faked. Neither spec sends a prompt, so no socket is ever opened.

describe('AI panel navigation rail', () => {
  const mountPanel = () => mountAISidebar({ chatConfiguration: buildChatConfiguration() });

  beforeEach(setupDuoChatTest);

  afterEach(() => teardownDuoChatTest());

  describe('tab navigation', () => {
    it('opens the chat panel when the chat toggle is clicked', async () => {
      mountPanel();

      await waitForElement(findChatToggle);
      expect(findDuoAgenticChatPanel()).toBe(null);

      findChatToggle().click();

      await waitFor(() => {
        expect(findDuoAgenticChatPanel()).not.toBe(null);
      });
    });

    it('closes the panel when the active chat tab is clicked again', async () => {
      mountPanel();

      await waitForElement(findChatToggle);

      findChatToggle().click();
      await waitFor(() => {
        expect(findDuoAgenticChatPanel()).not.toBe(null);
      });

      findChatToggle().click();
      await waitFor(() => {
        expect(findDuoAgenticChatPanel()).toBe(null);
      });
    });

    it('navigates to the history tab when the history toggle is clicked', async () => {
      mountPanel();

      await waitForElement(findChatToggle);

      // Open the panel first via the chat tab
      findChatToggle().click();
      await waitFor(() => {
        expect(findDuoAgenticChatPanel()).not.toBe(null);
      });

      // Navigate to history
      const historyToggle = await waitForElement(findHistoryToggle);
      historyToggle.click();

      // The history tab renders the thread list in place of the message list.
      // Assert on that, not on `chat-history` -- that testid is the inner wrapper
      // of `chat-component` and is already present in chat mode, so waiting for
      // it would pass even if the toggle did nothing.
      await waitFor(() => {
        expect(findThreadListPanel()).not.toBe(null);
      });
    });

    it('navigates to the sessions tab when the sessions toggle is clicked', async () => {
      mountPanel();

      await waitForElement(findChatToggle);

      // Open the panel first via the chat tab
      findChatToggle().click();
      await waitFor(() => {
        expect(findDuoAgenticChatPanel()).not.toBe(null);
      });

      // Navigate to sessions
      const sessionsToggle = await waitForElement(findSessionsToggle);
      sessionsToggle.click();

      await waitFor(() => {
        expect(findAgentSessionsPanel()).not.toBe(null);
      });

      // Sessions is a different route, so the chat must have been torn down.
      expect(findDuoAgenticChatPanel()).toBe(null);
    });

    it('navigates back to chat from history', async () => {
      mountPanel();

      await waitForElement(findChatToggle);

      // Open chat
      findChatToggle().click();
      await waitFor(() => {
        expect(findDuoAgenticChatPanel()).not.toBe(null);
      });

      // Navigate to history and confirm the thread list actually rendered --
      // otherwise the assertion that it is gone below would be satisfied by
      // history never having opened in the first place.
      const historyToggle = await waitForElement(findHistoryToggle);
      historyToggle.click();
      await waitForElement(findThreadListPanel);

      // Navigate back to chat
      const chatToggle = await waitForElement(findChatToggle);
      chatToggle.click();

      await waitFor(() => {
        expect(findDuoAgenticChatPanel()).not.toBe(null);
        // History list should no longer be the active view
        expect(findThreadListPanel()).toBe(null);
      });
    });

    it('settles on the last tab clicked when tabs are switched rapidly', async () => {
      mountPanel();

      await waitForElement(findChatToggle);
      await waitForElement(findHistoryToggle);
      await waitForElement(findSessionsToggle);

      // Cycle the tabs without awaiting in between, so several route
      // transitions are in flight at once.
      for (let i = 0; i < 5; i += 1) {
        findChatToggle().click();
        findHistoryToggle().click();
        findSessionsToggle().click();
      }

      await waitFor(() => {
        expect(findAgentSessionsPanel()).not.toBe(null);
      });

      expect(findDuoAgenticChatPanel()).toBe(null);
      expect(findThreadListPanel()).toBe(null);
    });
  });
});
