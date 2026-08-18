import { waitFor } from '@testing-library/vue';
import { CHAT_MODES } from '~/super_sidebar/constants';
import { getText, waitAndClick, waitForElement } from 'ee_jest/msw_integration/test_helpers';
import {
  buildClassicChatConfiguration,
  findChatComponent,
  findMessages,
  findHistoryToggle,
  findThreadBoxWithText,
  isShowingClassicChatView,
  isShowingClassicListView,
  mountAISidebar,
  panelHeadingText,
  setupDuoChatTest,
  teardownDuoChatTest,
} from '../duo_agentic_chat/test_setup';
import { fixtures as aiDuoPanelFixtures } from '../handlers/ai_duo_panel';

const chatConfiguration = buildClassicChatConfiguration();

// The thread that has messages is the one with a non-null title; the MSW
// handler returns its message fixture for that thread id only.
const threadWithMessages = aiDuoPanelFixtures.threads.find((thread) => thread.title !== null);
const assistantMessage = aiDuoPanelFixtures.messagesForFirstThread.find(
  (message) => message.role === 'ASSISTANT',
);

describe('Duo classic chat panel navigation and reload-from-history', () => {
  let wrapper;

  // Joined rather than checked per-element so a failure prints the conversation
  // that did render.
  const renderedMessagesText = () => [...findMessages()].map(getText).join('\n');

  // The classic DuoChat state manager declares a String userId; without one Vue
  // logs a prop-type warning on every re-render.
  const mountPanel = () => {
    wrapper = mountAISidebar({
      chatConfiguration,
      propsData: { userId: 'gid://gitlab/User/1' },
    });
  };

  beforeEach(() => {
    setupDuoChatTest({ chatMode: CHAT_MODES.CLASSIC });
    // The history-stack replay path is still flag-gated at this commit (the FF
    // removal lands in the next commit). Turn it on so this guard proves the
    // reload behaviour is safe with the flag enabled, which is what justifies
    // removing the flag.
    window.gon = { ...window.gon, features: { duoPanelHistoryStackPersistence: true } };
  });

  afterEach(() => {
    // Destroys the mounted wrappers too, so `simulateReload` is the only place
    // this spec has to destroy one itself.
    teardownDuoChatTest();
    window.gon = { ...window.gon, features: {} };
  });

  // Reload = tear down the DOM and re-create the router. The persisted
  // sessionStorage (history stack + last route) survives, so a fresh
  // `createRouter` replays it via `restoreLastRoute` exactly as a page
  // reload would.
  const simulateReload = () => {
    wrapper.destroy();
    document.body.innerHTML = '';
    mountPanel();
  };

  // Drives history-list -> open-thread and waits until the chat view is shown.
  const openThreadFromHistory = async () => {
    mountPanel();

    await waitAndClick(findHistoryToggle);
    await waitAndClick(() => findThreadBoxWithText(threadWithMessages.title));

    await waitFor(() => {
      expect(isShowingClassicChatView()).toBe(true);
    });
  };

  describe('reloading while a conversation is open', () => {
    beforeEach(async () => {
      await openThreadFromHistory();
      simulateReload();
      await waitForElement(findChatComponent);
    });

    it('restores the conversation, not the history list', async () => {
      // Route and view must agree after replay, and the conversation itself
      // comes back: the restored assistant message renders in the body. The
      // thread id now travels in the route, so it survives the heap wipe.
      await waitFor(() => {
        expect(isShowingClassicChatView()).toBe(true);
        expect(isShowingClassicListView()).toBe(false);
        expect(renderedMessagesText()).toContain(assistantMessage.content);
      });
    });

    it('shows the classic chat heading, not the history heading', async () => {
      // The classic surface derives its heading from the route: the show route
      // reads the classic chat title, never "History". (Unlike agent sessions,
      // classic chat does not surface a per-conversation title.)
      await waitFor(() => {
        expect(isShowingClassicChatView()).toBe(true);
        expect(panelHeadingText()).toBe(chatConfiguration.classicTitle);
      });
    });

    it('reads "History" on the heading after returning to the list', async () => {
      await waitFor(() => {
        expect(isShowingClassicChatView()).toBe(true);
      });

      await waitAndClick(findHistoryToggle);

      // On the history route the heading must be the route-derived "History",
      // proving the reload did not leave the conversation view pinned.
      await waitFor(() => {
        expect(isShowingClassicListView()).toBe(true);
        expect(panelHeadingText()).toBe('History');
      });
    });
  });

  describe('back-to-list from a conversation', () => {
    it('keeps the route and view in sync on the history route', async () => {
      await openThreadFromHistory();

      await waitAndClick(findHistoryToggle);

      // Route (history) and view (LIST) agree: the thread list is shown, the
      // conversation footer is gone, and the heading reads "History".
      await waitFor(() => {
        expect(isShowingClassicListView()).toBe(true);
        expect(isShowingClassicChatView()).toBe(false);
        expect(panelHeadingText()).toBe('History');
      });
    });
  });
});
