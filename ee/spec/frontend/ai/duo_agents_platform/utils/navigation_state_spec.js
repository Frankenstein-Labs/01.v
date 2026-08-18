import {
  getLastRouteState,
  saveRouteState,
  clearRouteState,
  restoreLastRoute,
  setupNavigationGuards,
  getStorageKey,
  getHistoryStackKey,
  serializeHistoryStack,
  saveHistoryStack,
  getHistoryStack,
  getModeAwareDefaultRoute,
  trackTabRoutes,
} from 'ee/ai/duo_agents_platform/utils/navigation_state';
import {
  getSessionStorageValue,
  saveSessionStorageValue,
  removeSessionStorageValue,
} from '~/lib/utils/local_storage';
import { duoChatGlobalState } from '~/super_sidebar/state';
import {
  AGENTIC_CHAT_SHOW_ROUTE,
  CLASSIC_CHAT_SHOW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';

jest.mock('~/lib/utils/local_storage', () => ({
  getSessionStorageValue: jest.fn(() => ({ exists: false })),
  saveSessionStorageValue: jest.fn(),
  removeSessionStorageValue: jest.fn(),
}));

describe('Navigation State Utils', () => {
  const mockRoute = {
    name: 'agents_platform_show_route',
    params: { id: '123' },
    path: '/agent-sessions/123',
  };
  const mockRouteState = {
    name: 'agents_platform_show_route',
    params: { id: '123' },
  };
  const mockRouter = {
    push: jest.fn(),
    afterEach: jest.fn(),
    currentRoute: {},
    history: { stack: [{ name: 'chat_route', params: {} }], index: 0 },
  };
  const defaultStorageKey = 'duo_agents_platform_last_route';

  beforeEach(() => {
    jest.clearAllMocks();

    duoChatGlobalState.lastRoutePerTab = {};
    mockRouter.currentRoute = {};
    mockRouter.history = { stack: [{ name: 'chat_route', params: {} }], index: 0 };
    duoChatGlobalState.chatMode = 'agentic';
  });

  describe('getStorageKey', () => {
    it.each([
      { context: undefined, expected: defaultStorageKey, description: 'when no context provided' },
      { context: null, expected: defaultStorageKey, description: 'when context is null' },
      {
        context: 'custom_context',
        expected: `${defaultStorageKey}_custom_context`,
        description: 'when context provided',
      },
    ])('returns $expected $description', ({ context, expected }) => {
      expect(getStorageKey(context)).toBe(expected);
    });
  });

  describe('getLastRouteState', () => {
    it.each([
      { exists: true, value: mockRouteState, expected: mockRouteState },
      { exists: false, expected: null },
    ])('returns $expected when storage exists: $exists', ({ exists, value, expected }) => {
      getSessionStorageValue.mockReturnValue({ exists, value });

      expect(getLastRouteState()).toBe(expected);
      expect(getSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
    });
  });

  describe('saveRouteState', () => {
    it.each([
      {
        name: 'saves route state to sessionStorage when route has name',
        route: mockRoute,
        storageKey: undefined,
        expectedKey: defaultStorageKey,
        expectedValue: mockRouteState,
      },
      {
        name: 'saves route state with custom storage key',
        route: mockRoute,
        storageKey: 'custom_key',
        expectedKey: 'custom_key',
        expectedValue: mockRouteState,
      },
      {
        name: 'saves route state with empty params when params are undefined',
        route: { name: 'test_route', path: '/test' },
        storageKey: undefined,
        expectedKey: defaultStorageKey,
        expectedValue: { name: 'test_route', params: {} },
      },
    ])('$name', ({ route, storageKey, expectedKey, expectedValue }) => {
      saveRouteState(route, storageKey);
      expect(saveSessionStorageValue).toHaveBeenCalledWith(expectedKey, expectedValue);
    });

    it('does not save when route has no name', () => {
      const routeWithoutName = { params: { id: '123' }, path: '/agent-sessions/123' };

      saveRouteState(routeWithoutName);
      expect(saveSessionStorageValue).not.toHaveBeenCalled();
    });
  });

  describe('clearRouteState', () => {
    it('removes route state from sessionStorage', () => {
      clearRouteState();
      expect(removeSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
    });
  });

  describe('restoreLastRoute', () => {
    describe('with history stack persistence enabled', () => {
      const historyStackKey = 'duo_agents_platform_history_stack';

      beforeEach(() => {
        gon.features = { duoPanelHistoryStackPersistence: true };
        mockRouter.push.mockResolvedValue();
      });

      afterEach(() => {
        gon.features = {};
      });

      describe('when the persisted stack has entries', () => {
        const stackEntries = [
          { name: 'agentic_chat_show_route', params: {} },
          { name: 'agents_platform_index_route', params: {} },
          { name: 'agents_platform_show_route', params: { id: '42' } },
        ];

        beforeEach(() => {
          // The last stack entry must match the saved routeState for the
          // stack to be considered fresh (not stale from a prior page).
          getSessionStorageValue.mockImplementation((requestedKey) => {
            if (requestedKey === historyStackKey) {
              return { exists: true, value: stackEntries };
            }
            if (requestedKey === defaultStorageKey) {
              return { exists: true, value: stackEntries[stackEntries.length - 1] };
            }
            return { exists: false };
          });
        });

        it('replays each entry via router.push', async () => {
          await restoreLastRoute(mockRouter, {});

          expect(mockRouter.push).toHaveBeenCalledTimes(3);
          expect(mockRouter.push).toHaveBeenNthCalledWith(1, stackEntries[0]);
          expect(mockRouter.push).toHaveBeenNthCalledWith(2, stackEntries[1]);
          expect(mockRouter.push).toHaveBeenNthCalledWith(3, stackEntries[2]);
        });

        it('does not call the single-route fallback', async () => {
          // After a successful replay, only the N replay pushes should happen —
          // no extra push to a default/fallback route.
          await restoreLastRoute(mockRouter, { isAgenticAvailable: true });

          expect(mockRouter.push).toHaveBeenCalledTimes(stackEntries.length);
        });

        it('registers an afterEach that writes the stack on subsequent navigations', async () => {
          await restoreLastRoute(mockRouter, {});

          const afterEachCallback = mockRouter.afterEach.mock.calls.at(-1)[0];
          saveSessionStorageValue.mockClear();
          afterEachCallback();

          expect(saveSessionStorageValue).toHaveBeenCalledWith(historyStackKey, expect.any(Array));
        });

        it('uses context-suffixed history stack key', async () => {
          getSessionStorageValue.mockImplementation((requestedKey) => {
            if (requestedKey === `${historyStackKey}_side_panel`) {
              return { exists: true, value: stackEntries };
            }
            if (requestedKey === `${defaultStorageKey}_side_panel`) {
              return { exists: true, value: stackEntries[stackEntries.length - 1] };
            }
            return { exists: false };
          });

          await restoreLastRoute(mockRouter, { context: 'side_panel' });

          expect(getSessionStorageValue).toHaveBeenCalledWith(`${historyStackKey}_side_panel`);
          expect(mockRouter.push).toHaveBeenCalledTimes(3);
        });
      });

      describe('when the persisted stack is empty', () => {
        beforeEach(() => {
          getSessionStorageValue.mockImplementation((requestedKey) => {
            if (requestedKey === historyStackKey) {
              return { exists: true, value: [] };
            }
            return { exists: false };
          });
        });

        it('falls through to mode-aware default route', async () => {
          // When the stack is empty the function falls through to the
          // normal route restoration logic so first-visit still works.
          await restoreLastRoute(mockRouter, { isAgenticAvailable: true });

          expect(mockRouter.push).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
        });

        it('still registers an afterEach so subsequent navigations are persisted', async () => {
          await restoreLastRoute(mockRouter, {});

          expect(mockRouter.afterEach).toHaveBeenCalled();

          const afterEachCallback = mockRouter.afterEach.mock.calls.at(-1)[0];
          afterEachCallback();

          expect(saveSessionStorageValue).toHaveBeenCalledWith(historyStackKey, expect.any(Array));
        });
      });

      describe('when the persisted stack is stale (tip does not match routeState)', () => {
        const stackEntries = [
          { name: 'agentic_chat_show_route', params: {} },
          { name: 'agents_platform_index_route', params: {} },
        ];

        beforeEach(() => {
          getSessionStorageValue.mockImplementation((requestedKey) => {
            if (requestedKey === historyStackKey) {
              return { exists: true, value: stackEntries };
            }
            // routeState differs from last stack entry
            if (requestedKey === defaultStorageKey) {
              return {
                exists: true,
                value: { name: 'agentic_chat_show_route', params: { id: '99' } },
              };
            }
            return { exists: false };
          });
        });

        it('does not replay the stack', async () => {
          await restoreLastRoute(mockRouter, { isAgenticAvailable: true });

          // Falls through to single-route restoration instead of replaying
          expect(mockRouter.push).toHaveBeenCalledTimes(1);
          expect(mockRouter.push).toHaveBeenCalledWith({
            name: 'agentic_chat_show_route',
            params: { id: '99' },
          });
        });

        it('clears the stale stack from storage', async () => {
          await restoreLastRoute(mockRouter, { isAgenticAvailable: true });

          expect(removeSessionStorageValue).toHaveBeenCalledWith(historyStackKey);
        });
      });

      describe('when replay throws an error', () => {
        const stackEntries = [
          { name: 'agentic_chat_show_route', params: {} },
          { name: 'bad_route', params: {} },
        ];

        beforeEach(() => {
          getSessionStorageValue.mockImplementation((requestedKey) => {
            if (requestedKey === historyStackKey) {
              return { exists: true, value: stackEntries };
            }
            if (requestedKey === defaultStorageKey) {
              return { exists: true, value: stackEntries[stackEntries.length - 1] };
            }
            return { exists: false };
          });

          mockRouter.push
            .mockResolvedValueOnce() // first entry succeeds
            .mockRejectedValueOnce(new Error('Navigation aborted')) // second fails
            .mockResolvedValue(); // fallback succeeds
        });

        it('clears the corrupt history stack key', async () => {
          await restoreLastRoute(mockRouter, { isAgenticAvailable: true });

          expect(removeSessionStorageValue).toHaveBeenCalledWith(historyStackKey);
        });

        it('pushes the mode-aware default route', async () => {
          // The flag-on branch does not fall through to the legacy path; it
          // pushes the mode-aware default itself.
          await restoreLastRoute(mockRouter, { isAgenticAvailable: true });

          expect(mockRouter.push).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
        });
      });
    });

    describe('with history stack persistence disabled', () => {
      beforeEach(() => {
        gon.features = { duoPanelHistoryStackPersistence: false };
        mockRouter.push.mockResolvedValue();
      });

      afterEach(() => {
        gon.features = {};
      });

      it('does not attempt to read or write the history stack', async () => {
        getSessionStorageValue.mockReturnValue({ exists: false });

        await restoreLastRoute(mockRouter, {});

        const historyStackReads = getSessionStorageValue.mock.calls.filter(([k]) =>
          k.startsWith('duo_agents_platform_history_stack'),
        );
        expect(historyStackReads).toHaveLength(0);
        expect(mockRouter.afterEach).not.toHaveBeenCalled();
      });
    });

    describe('when Duo is disabled', () => {
      const blockedRoute = 'blockedRoute';

      it('navigates to the disabled empty state when the panel should auto-expand', async () => {
        await restoreLastRoute(mockRouter, {
          blockedRoute,
          shouldShowBlockedState: true,
          autoExpand: true,
        });

        expect(mockRouter.push).toHaveBeenCalledWith({ name: blockedRoute });
      });

      it('does not force-open the panel when the user has dismissed the auto-expand callout', async () => {
        await restoreLastRoute(mockRouter, {
          blockedRoute,
          shouldShowBlockedState: true,
          autoExpand: false,
        });

        expect(mockRouter.push).not.toHaveBeenCalledWith({ name: blockedRoute });
      });

      describe('when the stored route is the default one', () => {
        const defaultRoute = 'defaultRoute';

        beforeEach(() => {
          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: { name: defaultRoute },
          });
        });

        it('does not force-open the blocked route when the saved route matches the default', async () => {
          // A saved route matching defaultRoute means the panel was in its
          // initial/closed state — we must not force-open the blocked view.
          await restoreLastRoute(mockRouter, {
            defaultRoute,
            blockedRoute,
            shouldShowBlockedState: true,
          });

          expect(mockRouter.push).not.toHaveBeenCalledWith({ name: blockedRoute });
          expect(mockRouter.push).toHaveBeenCalledWith({ name: defaultRoute });
        });
      });

      describe('when another route was persisted', () => {
        beforeEach(() => {
          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: mockRouteState,
          });
        });

        it('navigates to the disabled empty state regardless', async () => {
          await restoreLastRoute(mockRouter, { blockedRoute, shouldShowBlockedState: true });

          expect(mockRouter.push).toHaveBeenCalledWith({ name: blockedRoute });
        });

        it('clears the history stack when the feature flag is enabled', async () => {
          gon.features = { duoPanelHistoryStackPersistence: true };

          await restoreLastRoute(mockRouter, { blockedRoute, shouldShowBlockedState: true });

          expect(removeSessionStorageValue).toHaveBeenCalledWith(
            'duo_agents_platform_history_stack',
          );

          gon.features = {};
        });
      });

      describe('when there is no saved route but a default route is specified', () => {
        beforeEach(() => {
          getSessionStorageValue.mockReturnValue({ exists: false });
        });

        it('navigates to the default route instead of the blocked route', async () => {
          await restoreLastRoute(mockRouter, {
            defaultRoute: 'closed_route',
            blockedRoute,
            shouldShowBlockedState: true,
          });

          expect(mockRouter.push).toHaveBeenCalledWith({ name: 'closed_route' });
        });
      });
    });

    describe('successful navigation', () => {
      beforeEach(() => {
        mockRouter.push.mockResolvedValue();
      });

      describe('with saved route', () => {
        beforeEach(() => {
          getSessionStorageValue.mockReturnValue({
            exists: true,
            value: mockRouteState,
          });
        });

        it('navigates to saved route with default storage key', async () => {
          await restoreLastRoute(mockRouter, {});

          expect(getSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });

        it('navigates to saved route with custom storage key', async () => {
          await restoreLastRoute(mockRouter, { storageKey: 'custom_key' });

          expect(getSessionStorageValue).toHaveBeenCalledWith('custom_key');
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });

        it('navigates to saved route with custom context', async () => {
          await restoreLastRoute(mockRouter, { context: 'custom_context' });

          expect(getSessionStorageValue).toHaveBeenCalledWith(
            `${defaultStorageKey}_custom_context`,
          );
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });
      });

      describe('without saved route', () => {
        beforeEach(() => {
          getSessionStorageValue.mockReturnValue({
            exists: false,
            value: null,
          });
        });

        describe('when agentic is available', () => {
          beforeEach(async () => {
            await restoreLastRoute(mockRouter, { isAgenticAvailable: true });
          });

          it('reads from the default storage key', () => {
            expect(getSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
          });

          it('navigates to agentic route', () => {
            expect(mockRouter.push).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
          });
        });

        describe('when agentic is not available', () => {
          beforeEach(async () => {
            await restoreLastRoute(mockRouter, { isAgenticAvailable: false });
          });

          it('reads from the default storage key', () => {
            expect(getSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
          });

          it('navigates to classic route', () => {
            expect(mockRouter.push).toHaveBeenCalledWith({ name: CLASSIC_CHAT_SHOW_ROUTE });
          });
        });

        describe('when a custom default route is specified', () => {
          beforeEach(async () => {
            await restoreLastRoute(mockRouter, { defaultRoute: 'custom_route' });
          });

          it('reads from the default storage key', () => {
            expect(getSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
          });

          it('navigates to the custom route', () => {
            expect(mockRouter.push).toHaveBeenCalledWith({ name: 'custom_route' });
          });
        });
      });
    });

    describe('when target route matches current route', () => {
      beforeEach(() => {
        getSessionStorageValue.mockReturnValue({ exists: true, value: mockRouteState });
        mockRouter.currentRoute = {
          name: mockRouteState.name,
          params: mockRouteState.params,
        };
      });

      it('does not call router.push', async () => {
        await restoreLastRoute(mockRouter, {});

        expect(mockRouter.push).not.toHaveBeenCalled();
      });

      it('resolves successfully', async () => {
        await expect(restoreLastRoute(mockRouter, {})).resolves.toBeUndefined();
      });
    });

    describe('when target route name matches but params differ', () => {
      beforeEach(() => {
        getSessionStorageValue.mockReturnValue({ exists: true, value: mockRouteState });
        mockRouter.currentRoute = {
          name: mockRouteState.name,
          params: { id: '456' },
        };
        mockRouter.push.mockResolvedValue();
      });

      it('calls router.push with the saved route', async () => {
        await restoreLastRoute(mockRouter, {});

        expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
      });
    });

    describe('failed navigation', () => {
      beforeEach(() => {
        getSessionStorageValue.mockReturnValue({ exists: true, value: mockRouteState });
        mockRouter.push.mockRejectedValueOnce(new Error('Navigation failed'));
        mockRouter.push.mockResolvedValueOnce();
      });

      describe('when agentic is available', () => {
        beforeEach(async () => {
          await restoreLastRoute(mockRouter, { isAgenticAvailable: true });
        });

        it('attempts the saved route first', () => {
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });

        it('falls back to agentic route', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
        });

        it('clears the stored route state', () => {
          expect(removeSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
        });
      });

      describe('when agentic is not available', () => {
        beforeEach(async () => {
          await restoreLastRoute(mockRouter, { isAgenticAvailable: false });
        });

        it('attempts the saved route first', () => {
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });

        it('falls back to classic route', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({ name: CLASSIC_CHAT_SHOW_ROUTE });
        });

        it('clears the stored route state', () => {
          expect(removeSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
        });
      });

      describe('when using a custom context with agentic available', () => {
        beforeEach(async () => {
          await restoreLastRoute(mockRouter, {
            context: 'text_context',
            isAgenticAvailable: true,
          });
        });

        it('attempts the saved route first', () => {
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });

        it('falls back to agentic route', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
        });

        it('clears the context-specific stored route state', () => {
          expect(removeSessionStorageValue).toHaveBeenCalledWith(
            `${defaultStorageKey}_text_context`,
          );
        });
      });

      describe('when a custom default route is specified', () => {
        beforeEach(async () => {
          await restoreLastRoute(mockRouter, { defaultRoute: 'custom_route' });
        });

        it('attempts the saved route first', () => {
          expect(mockRouter.push).toHaveBeenCalledWith(mockRouteState);
        });

        it('falls back to the custom route', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({ name: 'custom_route' });
        });

        it('clears the stored route state', () => {
          expect(removeSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey);
        });
      });
    });
  });

  describe('setupNavigationGuards', () => {
    const setupGuard = (options = {}) => {
      setupNavigationGuards({
        router: mockRouter,
        ...options,
      });
      return mockRouter.afterEach.mock.calls[0][0];
    };

    it('sets up afterEach guard', () => {
      setupGuard();
      expect(mockRouter.afterEach).toHaveBeenCalledWith(expect.any(Function));
    });

    describe('guard behavior', () => {
      let guardFunction;

      beforeEach(() => {
        guardFunction = setupGuard();
      });

      it('saves route state when called', () => {
        guardFunction(mockRoute);
        expect(saveSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey, mockRouteState);
      });

      it('saves route state for routes outside agent sessions', () => {
        const otherRoute = { name: 'other_route', params: { id: '123' }, path: '/other-path/123' };
        const expectedState = { name: 'other_route', params: { id: '123' } };

        guardFunction(otherRoute);
        expect(saveSessionStorageValue).toHaveBeenCalledWith(defaultStorageKey, expectedState);
      });
    });

    describe('configuration options', () => {
      it.each([
        {
          name: 'uses custom context storage key for custom context',
          options: { context: 'test_context' },
          expectedKey: `${defaultStorageKey}_test_context`,
        },
        {
          name: 'uses custom storage key when provided',
          options: { storageKey: 'custom_session_key' },
          expectedKey: 'custom_session_key',
        },
        {
          name: 'uses default storage key by default',
          options: {},
          expectedKey: defaultStorageKey,
        },
      ])('$name', ({ options, expectedKey }) => {
        const guardFunction = setupGuard(options);

        guardFunction(mockRoute);

        expect(saveSessionStorageValue).toHaveBeenCalledWith(expectedKey, mockRouteState);
      });
    });

    // Stack-write coverage lives in the restoreLastRoute describe above
    // because the stack-saving afterEach is registered there, not here.
    // setupNavigationGuards only owns the legacy single-route key today.
  });

  describe('getHistoryStackKey', () => {
    it.each([
      {
        context: undefined,
        expected: 'duo_agents_platform_history_stack',
        description: 'when no context provided',
      },
      {
        context: null,
        expected: 'duo_agents_platform_history_stack',
        description: 'when context is null',
      },
      {
        context: 'side_panel',
        expected: 'duo_agents_platform_history_stack_side_panel',
        description: 'when context provided',
      },
    ])('returns $expected $description', ({ context, expected }) => {
      expect(getHistoryStackKey(context)).toBe(expected);
    });
  });

  describe('serializeHistoryStack', () => {
    const buildRouter = ({ stack = [], index = 0 } = {}) => ({
      history: { stack, index },
    });

    const buildRoute = (name, params = {}) => ({ name, params, path: `/${name}` });

    it('returns an empty array when the stack is empty', () => {
      expect(serializeHistoryStack(buildRouter({ stack: [] }))).toEqual([]);
    });

    it('returns an empty array when the stack is not an array', () => {
      expect(serializeHistoryStack(buildRouter({ stack: null }))).toEqual([]);
    });

    it('returns an empty array when router.history is missing', () => {
      expect(serializeHistoryStack({ history: undefined })).toEqual([]);
    });

    it('serializes a single entry with name and params', () => {
      const router = buildRouter({
        stack: [buildRoute('agentic_chat_show_route')],
        index: 0,
      });

      expect(serializeHistoryStack(router)).toEqual([
        { name: 'agentic_chat_show_route', params: {} },
      ]);
    });

    it('drops forward history beyond the current index', () => {
      const router = buildRouter({
        stack: [
          buildRoute('agentic_chat_show_route'),
          buildRoute('agents_platform_index_route'),
          buildRoute('agents_platform_show_route', { id: '42' }),
        ],
        index: 1,
      });

      expect(serializeHistoryStack(router)).toEqual([
        { name: 'agentic_chat_show_route', params: {} },
        { name: 'agents_platform_index_route', params: {} },
      ]);
    });

    it('keeps the full stack when the cursor is at the tip', () => {
      const router = buildRouter({
        stack: [
          buildRoute('agentic_chat_show_route'),
          buildRoute('agents_platform_index_route'),
          buildRoute('agents_platform_show_route', { id: '42' }),
        ],
        index: 2,
      });

      expect(serializeHistoryStack(router)).toEqual([
        { name: 'agentic_chat_show_route', params: {} },
        { name: 'agents_platform_index_route', params: {} },
        { name: 'agents_platform_show_route', params: { id: '42' } },
      ]);
    });

    it('defaults undefined params to an empty object', () => {
      const router = buildRouter({
        stack: [{ name: 'chat_route', path: '/chat' }],
        index: 0,
      });

      expect(serializeHistoryStack(router)).toEqual([{ name: 'chat_route', params: {} }]);
    });

    it('caps at 200 entries keeping the newest up to the current index', () => {
      const oversizedStack = Array.from({ length: 210 }, (_, i) =>
        buildRoute(`route_${i}`, { i: String(i) }),
      );
      const router = buildRouter({ stack: oversizedStack, index: 209 });

      const result = serializeHistoryStack(router);
      expect(result).toHaveLength(200);
      expect(result[0].name).toBe('route_10');
      expect(result[199].name).toBe('route_209');
    });

    it('filters out transient new-chat routes that cause side effects on replay', () => {
      const router = buildRouter({
        stack: [
          buildRoute('agentic_chat_new_route'),
          buildRoute('agentic_chat_show_route', { id: '1' }),
          buildRoute('classic_chat_new_route'),
          buildRoute('classic_chat_show_route', { id: '2' }),
        ],
        index: 3,
      });

      const result = serializeHistoryStack(router);
      expect(result).toEqual([
        { name: 'agentic_chat_show_route', params: { id: '1' } },
        { name: 'classic_chat_show_route', params: { id: '2' } },
      ]);
    });
  });

  describe('saveHistoryStack', () => {
    const storageKey = 'duo_agents_platform_history_stack_side_panel';

    const buildRouter = ({ stack = [], index = 0 } = {}) => ({
      history: { stack, index },
    });

    const buildRoute = (name, params = {}) => ({ name, params, path: `/${name}` });

    it('does not write to sessionStorage when the stack is empty', () => {
      saveHistoryStack(buildRouter({ stack: [] }), storageKey);

      expect(saveSessionStorageValue).not.toHaveBeenCalled();
    });

    it('writes the serialized stack to sessionStorage', () => {
      const router = buildRouter({
        stack: [buildRoute('agentic_chat_show_route'), buildRoute('agents_platform_index_route')],
        index: 1,
      });

      saveHistoryStack(router, storageKey);

      expect(saveSessionStorageValue).toHaveBeenCalledWith(storageKey, [
        { name: 'agentic_chat_show_route', params: {} },
        { name: 'agents_platform_index_route', params: {} },
      ]);
    });
  });

  describe('getModeAwareDefaultRoute', () => {
    it('returns defaultRoute when provided', () => {
      expect(getModeAwareDefaultRoute({ defaultRoute: 'custom_route' })).toBe('custom_route');
    });

    it('returns the agentic route when agentic is available and chat mode is agentic', () => {
      duoChatGlobalState.chatMode = 'agentic';

      expect(getModeAwareDefaultRoute({ isAgenticAvailable: true })).toBe(AGENTIC_CHAT_SHOW_ROUTE);
    });

    it('returns the classic route when agentic is not available', () => {
      duoChatGlobalState.chatMode = 'agentic';

      expect(getModeAwareDefaultRoute({ isAgenticAvailable: false })).toBe(CLASSIC_CHAT_SHOW_ROUTE);
    });

    it('returns the classic route when called with no arguments', () => {
      duoChatGlobalState.chatMode = 'classic';

      expect(getModeAwareDefaultRoute()).toBe(CLASSIC_CHAT_SHOW_ROUTE);
    });
  });

  describe('getHistoryStack', () => {
    const storageKey = 'duo_agents_platform_history_stack_side_panel';

    describe('when the key does not exist', () => {
      beforeEach(() => {
        getSessionStorageValue.mockReturnValue({ exists: false });
      });

      it('returns an empty array', () => {
        expect(getHistoryStack(storageKey)).toEqual([]);
      });
    });

    describe('when the stored value is not an array', () => {
      it.each([
        { value: null, label: 'null' },
        { value: undefined, label: 'undefined' },
        { value: 'not-an-array', label: 'a string' },
        { value: { stack: [], index: 0 }, label: 'an object (legacy shape)' },
        { value: [], label: 'an empty array' },
      ])('returns an empty array when stored value is $label', ({ value }) => {
        getSessionStorageValue.mockReturnValue({ exists: true, value });

        expect(getHistoryStack(storageKey)).toEqual([]);
      });
    });

    describe('when an entry is invalid', () => {
      it.each([
        {
          value: [{ name: 'chat_route' }, { params: {} }],
          label: 'entry without name key',
        },
        {
          value: [{ name: 'chat_route' }, { name: 123 }],
          label: 'entry with non-string name',
        },
        {
          value: [{ name: 'chat_route' }, null],
          label: 'null entry',
        },
      ])('returns an empty array when stack contains $label', ({ value }) => {
        getSessionStorageValue.mockReturnValue({ exists: true, value });

        expect(getHistoryStack(storageKey)).toEqual([]);
      });
    });

    describe('when the stored stack is valid', () => {
      const validValue = [
        { name: 'agentic_chat_show_route', params: {} },
        { name: 'agents_platform_index_route', params: {} },
        { name: 'agents_platform_show_route', params: { id: '42' } },
      ];

      beforeEach(() => {
        getSessionStorageValue.mockReturnValue({ exists: true, value: validValue });
      });

      it('returns the stack array as-is', () => {
        expect(getHistoryStack(storageKey)).toEqual(validValue);
      });

      it('reads from the correct storage key', () => {
        getHistoryStack(storageKey);

        expect(getSessionStorageValue).toHaveBeenCalledWith(storageKey);
      });
    });
  });

  describe('trackTabRoutes', () => {
    it('stores route path for active tab', () => {
      trackTabRoutes({ name: 'agents_platform_index_route', path: '/agent-sessions/123' });

      expect(duoChatGlobalState.lastRoutePerTab.sessions).toBe('/agent-sessions/123');
    });

    it('updates route when navigating within same tab', () => {
      trackTabRoutes({ name: 'agents_platform_index_route', path: '/agent-sessions/123' });
      trackTabRoutes({ name: 'agents_platform_show_route', path: '/agent-sessions/456' });

      expect(duoChatGlobalState.lastRoutePerTab.sessions).toBe('/agent-sessions/456');
    });

    it('tracks routes independently for different tabs', () => {
      trackTabRoutes({ name: 'agents_platform_index_route', path: '/agent-sessions/123' });
      trackTabRoutes({ name: 'agentic_chat_show_route', path: '/chat-route' });

      expect(duoChatGlobalState.lastRoutePerTab).toEqual({
        sessions: '/agent-sessions/123',
        chat: '/chat-route',
      });
    });

    it('does not store route when route has no tab mapping', () => {
      trackTabRoutes({ name: 'unknown_route', path: '/agent-sessions/123' });

      expect(duoChatGlobalState.lastRoutePerTab).toEqual({});
    });

    it('does not store route when path is missing', () => {
      trackTabRoutes({ name: 'agents_platform_index_route', path: null });

      expect(duoChatGlobalState.lastRoutePerTab).toEqual({});
    });
  });
});
