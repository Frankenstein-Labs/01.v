import { eventHub, SHOW_SESSION, SHOW_NEW_CHAT } from 'ee/ai/events/panel';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { CHAT_MODES } from '~/super_sidebar/constants';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import {
  AGENTS_PLATFORM_SHOW_ROUTE,
  AGENTIC_CHAT_NEW_ROUTE,
  AGENTIC_CHAT_SHOW_ROUTE,
  CLASSIC_CHAT_NEW_ROUTE,
  CLOSED_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import { DUO_CURRENT_WORKFLOW_STORAGE_KEY } from 'ee/ai/constants';

jest.mock('ee/ai/events/panel');
jest.mock('ee/ai/duo_agents_platform/utils/navigation_state', () => ({
  getStorageKey: jest.fn(),
  restoreLastRoute: jest.fn(),
  saveRouteState: jest.fn(),
  setupNavigationGuards: jest.fn(),
  trackTabRoutes: jest.fn(),
}));
jest.mock('~/lib/utils/local_storage', () => ({
  ...jest.requireActual('~/lib/utils/local_storage'),
  removeSessionStorageValue: jest.fn(),
}));

describe('ai panel router', () => {
  let eventHandlers;
  let router;

  beforeEach(() => {
    eventHandlers = {};
    eventHub.$on.mockImplementation((event, handler) => {
      eventHandlers[event] = handler;
    });
    const chatConfiguration = {
      defaultProps: {
        isAgenticAvailable: true,
        isClassicAvailable: true,
      },
    };
    router = createRouter('/project', 'panel', chatConfiguration);
  });

  it('listens for SHOW_SESSION events', () => {
    expect(eventHub.$on).toHaveBeenCalledWith(SHOW_SESSION, expect.any(Function));
  });

  it('listens for SHOW_NEW_CHAT events', () => {
    expect(eventHub.$on).toHaveBeenCalledWith(SHOW_NEW_CHAT, expect.any(Function));
  });

  it('pushes the show session route with the provided id', async () => {
    const id = '5';
    eventHandlers[SHOW_SESSION]({ id });

    await waitForPromises();

    expect(router.currentRoute.name).toBe(AGENTS_PLATFORM_SHOW_ROUTE);
    expect(router.currentRoute.params).toEqual({ id });
  });

  describe('SHOW_NEW_CHAT handler', () => {
    it('navigates to agentic new chat route when in agentic mode', async () => {
      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      eventHandlers[SHOW_NEW_CHAT]();

      await waitForPromises();

      expect(router.currentRoute.name).toBe(AGENTIC_CHAT_NEW_ROUTE);
    });

    it('navigates to classic new chat route when in classic mode', async () => {
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
      eventHandlers[SHOW_NEW_CHAT]();

      await waitForPromises();

      expect(router.currentRoute.name).toBe(CLASSIC_CHAT_NEW_ROUTE);
    });
  });

  it('includes a closed route', () => {
    const closedRoute = router.options.routes.find((r) => r.name === CLOSED_ROUTE);
    expect(closedRoute).toBeDefined();
    expect(closedRoute.path).toBe('/closed');
  });

  describe('initial-route resolution by autoExpand', () => {
    const { restoreLastRoute } = jest.requireMock(
      'ee/ai/duo_agents_platform/utils/navigation_state',
    );

    beforeEach(() => {
      restoreLastRoute.mockClear();
    });

    it('passes CLOSED_ROUTE as defaultRoute when autoExpand is false', () => {
      createRouter('/', 'user', {
        defaultProps: { isAgenticAvailable: true },
        autoExpand: false,
      });

      expect(restoreLastRoute).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ defaultRoute: CLOSED_ROUTE }),
      );
    });

    it('leaves defaultRoute undefined when autoExpand is true', () => {
      createRouter('/', 'user', {
        defaultProps: { isAgenticAvailable: true },
        autoExpand: true,
      });

      expect(restoreLastRoute).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ defaultRoute: undefined }),
      );
    });
  });

  describe('event-listener teardown', () => {
    it('exposes a `cleanupEventListeners` function on the router', () => {
      expect(typeof router.cleanupEventListeners).toBe('function');
    });

    it('removes SHOW_SESSION and SHOW_NEW_CHAT listeners when invoked', () => {
      router.cleanupEventListeners();

      expect(eventHub.$off).toHaveBeenCalledWith(SHOW_SESSION, expect.any(Function));
      expect(eventHub.$off).toHaveBeenCalledWith(SHOW_NEW_CHAT, expect.any(Function));
    });
  });

  describe('beforeEach guard clears stale workflow on new-chat navigation', () => {
    const { removeSessionStorageValue } = jest.requireMock('~/lib/utils/local_storage');

    beforeEach(() => {
      removeSessionStorageValue.mockClear();
    });

    it('clears workflow storage when navigating to agentic new chat route', async () => {
      router.push({ name: AGENTIC_CHAT_NEW_ROUTE });
      await waitForPromises();

      expect(removeSessionStorageValue).toHaveBeenCalledWith(DUO_CURRENT_WORKFLOW_STORAGE_KEY);
    });

    it('clears workflow storage when navigating to classic new chat route', async () => {
      router.push({ name: CLASSIC_CHAT_NEW_ROUTE });
      await waitForPromises();

      expect(removeSessionStorageValue).toHaveBeenCalledWith(DUO_CURRENT_WORKFLOW_STORAGE_KEY);
    });

    it('does NOT clear workflow storage when navigating to agentic show route', async () => {
      router.push({ name: AGENTIC_CHAT_SHOW_ROUTE });
      await waitForPromises();

      expect(removeSessionStorageValue).not.toHaveBeenCalled();
    });
  });
});
