// eslint-disable-next-line no-restricted-syntax -- test mocks viewport breakpoints used by the source component
import { GlBreakpointInstance } from '@gitlab/ui/src/utils';
import { GlDisclosureDropdown } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { setHTMLFixture } from 'helpers/fixtures';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AIPanel from 'ee/ai/components/ai_panel.vue';
import AiContentContainer from 'ee/ai/components/content_container.vue';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import AccessiblePanelResizer from '~/vue_shared/components/accessible_panel_resizer.vue';
import DuoAgenticChat from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_state_manager.vue';
import DuoChat from 'ee/ai/tanuki_bot/components/duo_chat_state_manager.vue';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import {
  AGENTS_PLATFORM_SHOW_ROUTE,
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTIC_CHAT_SHOW_ROUTE,
  AGENTIC_CHAT_NEW_ROUTE,
  AGENTIC_CHAT_BLOCKED_ROUTE,
  AGENTIC_CHAT_HISTORY_ROUTE,
  CLOSED_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import { CHAT_MODES } from 'ee/ai/tanuki_bot/constants';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { cacheConfig, setMaximized } from 'ee/ai/graphql';

Vue.use(VueApollo);

jest.mock('~/behaviors/markdown/render_gfm');

describe('AiPanel', () => {
  let wrapper;
  let router;
  let mockApollo;
  let pushSpy;

  const ContentContainerStub = stubComponent(AiContentContainer, {
    template: `
      <div data-testid="content-container-stub">
        <slot
          v-if="title"
          name="active-tab"
          :show-session-id="false"
          :show-session-dropdown-tooltip="''"
          :toggle-text="''"
          :items="[]"
          :show-session-dropdown="() => {}"
          :hide-session-dropdown="() => {}"
          :handle-title-change="() => {}"
          :handle-session-id-changed="() => {}"
        />
      </div>
    `,
  });

  const createComponent = async ({
    routeName = AGENTIC_CHAT_SHOW_ROUTE,
    propsData = {},
    provide = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    const chatConfiguration = {
      agenticTitle: 'GitLab Duo Agentic Chat',
      classicTitle: 'GitLab Duo Chat',
      agenticComponent: DuoAgenticChat,
      classicComponent: DuoChat,
      defaultProps: {
        isAgenticAvailable: true,
        isClassicAvailable: true,
        showStudioHeader: true,
        creditsAvailable: true,
        userId: 0,
        projectId: 0,
        namespaceId: 0,
        rootNamespaceId: 0,
        resourceId: 0,
        metadata: {},
        userModelSelectionEnabled: true,
        forceAgenticModeForCoreDuoUsers: true,
        agenticUnavailableMessage: '',
        chatTitle: 'test',
        defaultNamespaceSelected: true,
        preferencesPath: '/',
        isTrial: true,
        buyAddonPath: '/',
        canBuyAddon: true,
        trialActive: false,
        subscriptionActive: true,
        exploreAiCatalogPath: '/',
      },
    };

    router = createRouter('/test', 'user', chatConfiguration);

    await router.isReady?.();
    await router.push({ name: routeName }).catch(() => {});

    mockApollo = createMockApollo([], {}, cacheConfig);

    wrapper = mountFn(AIPanel, {
      apolloProvider: mockApollo,
      router,
      propsData: {
        userId: 'gid://gitlab/User/1',
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Group/456',
        rootNamespaceId: 'gid://gitlab/Group/789',
        resourceId: 'gid://gitlab/Resource/111',
        metadata: '{"key":"value"}',
        userModelSelectionEnabled: false,
        shouldShowBlockedState: false,
        ...propsData,
      },
      provide: {
        isAgenticAvailable: true,
        chatTitle: null,
        chatConfiguration,
        ...provide,
      },
      stubs: {
        AiContentContainer: ContentContainerStub,
        NavigationRail,
      },
    });

    await nextTick();
    await waitForPromises();
  };

  const findContentContainer = () => wrapper.findComponent(AiContentContainer);
  const findNavigationRail = () => wrapper.findComponent(NavigationRail);
  const findPageLayout = () => document.querySelector('.js-page-layout');
  const findSessionMenu = () => wrapper.findComponent(GlDisclosureDropdown);

  const emitAndWait = async (finderFn, eventName, ...eventData) => {
    finderFn().vm.$emit(eventName, ...eventData);
    jest.advanceTimersToNextTimer();
    await waitForPromises();
    await nextTick();
    // Run all timers to ensure Apollo updates are flushed
    jest.runAllTimers();
    await waitForPromises();
    await nextTick();
  };

  beforeEach(() => {
    setHTMLFixture(`<div class="js-page-layout"></div>`);
    localStorage.clear();
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
    duoChatGlobalState.lastRoutePerTab = {};
  });

  it('renders navigation rail', async () => {
    await createComponent();
    expect(findNavigationRail().exists()).toBe(true);
  });

  describe('agent selection flow', () => {
    describe('when new-chat is emitted', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('shows chat panel with correct title', async () => {
        await emitAndWait(findNavigationRail, 'new-chat');

        expect(findContentContainer().exists()).toBe(true);
        expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
      });

      it('navigates to new chat route', async () => {
        await emitAndWait(findNavigationRail, 'new-chat');

        expect(router.currentRoute.name).toBe(AGENTIC_CHAT_NEW_ROUTE);
      });
    });
  });

  describe('panel opened state', () => {
    it('opens a panel', async () => {
      await createComponent();
      expect(findContentContainer().exists()).toBe(true);
    });

    it('closes a panel', async () => {
      await createComponent();
      await emitAndWait(findContentContainer, 'close-panel');
      expect(findContentContainer().exists()).toBe(false);
    });

    describe('tab toggle behavior', () => {
      // Chat tab starts active (initial route is AGENTIC_CHAT_SHOW_ROUTE),
      // so first toggle closes it, then subsequent toggles alternate open/close
      it('toggles panel closed then open for chat tab', async () => {
        await createComponent();

        // First toggle closes because we're already on chat tab
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');
        expect(findContentContainer().exists()).toBe(false);
        expect(router.currentRoute.name).toBe(CLOSED_ROUTE);

        // Second toggle opens
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');
        expect(findContentContainer().exists()).toBe(true);

        // Third toggle closes
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');
        expect(findContentContainer().exists()).toBe(false);
        expect(router.currentRoute.name).toBe(CLOSED_ROUTE);
      });

      // Other tabs start inactive, so first toggle opens them
      it.each(['sessions', 'history'])(
        'toggles panel closed then open for %s tab',
        async (tabName) => {
          await createComponent();

          await emitAndWait(findNavigationRail, 'handle-tab-toggle', tabName);
          expect(findContentContainer().exists()).toBe(true);

          await emitAndWait(findNavigationRail, 'handle-tab-toggle', tabName);
          expect(findContentContainer().exists()).toBe(false);
          expect(router.currentRoute.name).toBe(CLOSED_ROUTE);

          await emitAndWait(findNavigationRail, 'handle-tab-toggle', tabName);
          expect(findContentContainer().exists()).toBe(true);
        },
      );

      it('keeps the panel open for new chat', async () => {
        await createComponent();
        await emitAndWait(findNavigationRail, 'new-chat');
        await emitAndWait(findNavigationRail, 'new-chat');

        expect(findContentContainer().exists()).toBe(true);
        expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
      });
    });

    describe('expansion', () => {
      beforeEach(async () => {
        await createComponent();
        await setMaximized(false);
        await nextTick();
      });

      const toggleMaximize = async () => {
        await emitAndWait(findContentContainer, 'toggle-maximize');
        await nextTick();
      };

      it('maximizes', async () => {
        await toggleMaximize();
        expect(findContentContainer().props('isMaximized')).toBe(true);
        expect(findPageLayout().classList.contains('ai-panel-maximized')).toBe(true);
      });

      it('shrinks', async () => {
        await toggleMaximize();
        await toggleMaximize();
        expect(findContentContainer().props('isMaximized')).toBe(false);
        expect(findPageLayout().classList.contains('ai-panel-maximized')).toBe(false);
      });

      it('shrinks on close', async () => {
        await toggleMaximize();
        await emitAndWait(findContentContainer, 'close-panel');
        expect(findPageLayout().classList.contains('ai-panel-maximized')).toBe(false);
      });
    });
  });

  describe('panels', () => {
    describe('router navigation', () => {
      beforeEach(async () => {
        await createComponent({
          routeName: AGENTS_PLATFORM_INDEX_ROUTE,
        });
        pushSpy = jest.spyOn(router, 'push').mockResolvedValue();
      });

      describe('when chat tab is toggled', () => {
        it('navigates to root', async () => {
          await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');

          expect(pushSpy).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
        });
      });

      describe('when history tab is toggled', () => {
        it('navigates to history route', async () => {
          await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'history');

          expect(pushSpy).toHaveBeenCalledWith({ name: AGENTIC_CHAT_HISTORY_ROUTE });
        });
      });

      describe('when sessions tab is toggled', () => {
        it('navigates to initialRoute', async () => {
          await createComponent({
            routeName: AGENTIC_CHAT_HISTORY_ROUTE,
          });
          pushSpy = jest.spyOn(router, 'push').mockResolvedValue();

          await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');

          expect(pushSpy).toHaveBeenCalledWith({ name: AGENTS_PLATFORM_INDEX_ROUTE });
        });
      });

      describe('when new chat is triggered', () => {
        it('navigates to root', async () => {
          // First toggle to a different tab to ensure we're not already on chat
          await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
          pushSpy.mockClear();

          // Now trigger new chat
          await emitAndWait(findNavigationRail, 'new-chat');

          expect(pushSpy).toHaveBeenCalledWith({ name: AGENTIC_CHAT_NEW_ROUTE });
        });
      });
    });

    describe('when chat tab is toggled', () => {
      beforeEach(async () => {
        await createComponent();
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');
      });

      it('shows chat panel with correct configuration', () => {
        expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
      });
    });

    describe('when sessions tab is toggled', () => {
      beforeEach(async () => {
        await createComponent();
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
      });

      it('shows sessions panel with correct title', () => {
        expect(findContentContainer().props('title')).toBe('Sessions');
      });

      it('shows sessions panel with correct configuration', () => {
        expect(findContentContainer().props('title')).toBe('Sessions');
      });
    });
  });

  describe('showBackButton computed property', () => {
    it('returns false when route name is not AGENTS_PLATFORM_SHOW_ROUTE', async () => {
      await createComponent({ routeName: AGENTIC_CHAT_NEW_ROUTE });
      const showBackButton = findContentContainer().props('showBackButton');
      expect(showBackButton).toBe(false);
    });

    it('returns true when route name is AGENTS_PLATFORM_SHOW_ROUTE', async () => {
      await createComponent();
      try {
        await router.push({ name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id: '123' } });
      } catch (err) {
        if (err.name !== 'NavigationDuplicated') throw err;
      }
      await nextTick();
      await waitForPromises();
      const showBackButton = findContentContainer().props('showBackButton');
      expect(showBackButton).toBe(true);
    });
  });

  describe('passes showLoadingState to content container', () => {
    it('passes showLoadingState as true when on AGENTS_PLATFORM_SHOW_ROUTE', async () => {
      await createComponent({
        routeName: AGENTS_PLATFORM_INDEX_ROUTE,
      });
      await router.push({ name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id: '123' } });
      await nextTick();
      expect(findContentContainer().props('showLoadingState')).toBe(true);
    });

    it('passes showLoadingState as false when not on AGENTS_PLATFORM_SHOW_ROUTE', async () => {
      await createComponent({
        routeName: AGENTS_PLATFORM_INDEX_ROUTE,
      });
      expect(findContentContainer().props('showLoadingState')).toBe(false);
    });
  });

  describe('session view back button', () => {
    beforeEach(async () => {
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
    });

    it('hides the back button when the panel router has no navigation history', () => {
      jest.spyOn(router, 'canGoBack').mockReturnValue(false);

      expect(findContentContainer().props('showBackButton')).toBe(false);
    });

    it('shows the back button on a session route when the router has history', async () => {
      jest.spyOn(router, 'canGoBack').mockReturnValue(true);
      await router.push({ name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id: 1 } });
      await waitForPromises();

      expect(findContentContainer().props('showBackButton')).toBe(true);
    });

    it('calls router.back() when the back button emits go-back', async () => {
      jest.spyOn(router, 'canGoBack').mockReturnValue(true);
      const backSpy = jest.spyOn(router, 'back').mockImplementation(() => {});

      findContentContainer().vm.$emit('go-back');
      await waitForPromises();

      expect(backSpy).toHaveBeenCalled();
    });
  });

  describe('on window resize', () => {
    const triggerResize = () => {
      window.dispatchEvent(new Event('resize'));
    };

    it('collapses panel and clears the tab when resizing from desktop to non-desktop', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');

      GlBreakpointInstance.isDesktop.mockReturnValue(false);
      triggerResize();
      jest.advanceTimersToNextTimer();
      await waitForPromises();

      expect(findNavigationRail().props('isExpanded')).toBe(false);
      expect(findContentContainer().exists()).toBe(false);
      expect(router.currentRoute.name).toBe(CLOSED_ROUTE);
    });

    it('does not change panel state when resizing from non-desktop to desktop', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(false);
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');

      GlBreakpointInstance.isDesktop.mockReturnValue(true);
      triggerResize();
      await nextTick();

      expect(findNavigationRail().props('isExpanded')).toBe(true);
      expect(findContentContainer().exists()).toBe(true);
    });

    it('does not change panel state when breakpoint size does not change', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');

      triggerResize();
      await nextTick();

      expect(findNavigationRail().props('isExpanded')).toBe(true);
      expect(findContentContainer().exists()).toBe(true);
      expect(findContentContainer().props('title')).toBe('Sessions');
    });
  });

  describe('props passing', () => {
    it('passes exploreAiCatalogPath from chatConfiguration to navigation rail', async () => {
      await createComponent({
        provide: {
          chatConfiguration: {
            defaultProps: {
              exploreAiCatalogPath: '/explore/ai-catalog/agents',
            },
          },
        },
      });
      expect(findNavigationRail().props('exploreAiCatalogPath')).toBe('/explore/ai-catalog/agents');
    });

    it.each`
      isDuoAgentPlatformEnabled | expected
      ${true}                   | ${true}
      ${false}                  | ${false}
      ${undefined}              | ${false}
    `(
      'passes showSessionsTab=$expected when isDuoAgentPlatformEnabled=$isDuoAgentPlatformEnabled',
      async ({ isDuoAgentPlatformEnabled, expected }) => {
        await createComponent({
          provide: {
            chatConfiguration: {
              agenticTitle: 'GitLab Duo Agentic Chat',
              classicTitle: 'GitLab Duo Chat',
              agenticComponent: DuoAgenticChat,
              classicComponent: DuoChat,
              defaultProps: { isAgenticAvailable: true, isDuoAgentPlatformEnabled },
            },
          },
        });
        expect(findNavigationRail().props('showSessionsTab')).toBe(expected);
      },
    );

    it('passes activeTab configuration to content container', async () => {
      await createComponent({
        routeName: AGENTIC_CHAT_SHOW_ROUTE,
        propsData: {
          projectId: 'gid://gitlab/Project/999',
          namespaceId: 'gid://gitlab/Group/888',
          rootNamespaceId: 'gid://gitlab/Group/777',
          resourceId: 'gid://gitlab/Resource/666',
          metadata: '{"test":"data"}',
          userModelSelectionEnabled: true,
        },
      });

      expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
    });

    it('passes isMaximized and showBackButton to content container', async () => {
      await createComponent();
      await router.push({ name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id: '123' } });
      await nextTick();
      await waitForPromises();

      expect(findContentContainer().props()).toMatchObject({
        isMaximized: false,
        showBackButton: true,
      });
    });
  });

  describe('dynamic component rendering via slot', () => {
    it('shows agentic chat title in agentic mode', async () => {
      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');

      expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
    });

    it('shows classic chat title in classic mode', async () => {
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');

      expect(findContentContainer().props('title')).toBe('GitLab Duo Chat');
    });

    it('switches title when chat mode changes from agentic to classic', async () => {
      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');

      expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');

      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
      // Wait for the chatMode watcher to trigger router navigation
      await nextTick();
      await waitForPromises();
      jest.runAllTimers();
      await waitForPromises();
      await nextTick();

      expect(findContentContainer().props('title')).toBe('GitLab Duo Chat');
    });
  });

  describe('router navigation for tabs with initialRoute', () => {
    it('navigates to initialRoute when activating sessions tab', async () => {
      await createComponent();
      pushSpy = jest.spyOn(router, 'push').mockResolvedValue();

      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');

      expect(pushSpy).toHaveBeenCalledWith({ name: AGENTS_PLATFORM_INDEX_ROUTE });
    });

    it('navigates to chat route when activating chat tab', async () => {
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
      pushSpy = jest.spyOn(router, 'push').mockResolvedValue();

      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');

      expect(pushSpy).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
    });

    it('shows sessions panel when tab is already set', async () => {
      await createComponent({
        routeName: AGENTS_PLATFORM_INDEX_ROUTE,
      });
      jest.advanceTimersToNextTimer();
      await waitForPromises();

      expect(findContentContainer().exists()).toBe(true);
      expect(findContentContainer().props('title')).toBe('Sessions');
    });
  });

  describe('tab configuration', () => {
    describe('when chat tab is selected', () => {
      beforeEach(async () => {
        await createComponent();
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');
      });
      it('returns chat tab with correct title', () => {
        expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
      });
    });

    describe('when the new chat tab becomes active', () => {
      beforeEach(async () => {
        await createComponent();
        await emitAndWait(findNavigationRail, 'new-chat');
      });

      it('returns new chat tab with correct title', () => {
        expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
      });
    });

    describe('when history becomes active', () => {
      beforeEach(async () => {
        await createComponent({ routeName: AGENTIC_CHAT_HISTORY_ROUTE });
      });

      it('returns history tab with title from route meta', () => {
        const title = findContentContainer().props('title');
        expect(title).toBe('History');
      });
    });
  });

  describe('chat availability and fallback behavior', () => {
    describe('isAgenticMode behavior', () => {
      it.each`
        isAgenticAvailable | chatMode              | expectedTitle
        ${true}            | ${CHAT_MODES.AGENTIC} | ${'GitLab Duo Agentic Chat'}
        ${false}           | ${CHAT_MODES.AGENTIC} | ${'GitLab Duo Chat'}
        ${true}            | ${CHAT_MODES.CLASSIC} | ${'GitLab Duo Chat'}
        ${false}           | ${CHAT_MODES.CLASSIC} | ${'GitLab Duo Chat'}
      `(
        'renders $expectedTitle when isAgenticAvailable is $isAgenticAvailable and chatMode is $chatMode',
        async ({ isAgenticAvailable, chatMode, expectedTitle }) => {
          duoChatGlobalState.chatMode = chatMode;
          await createComponent({
            provide: {
              chatConfiguration: {
                agenticTitle: 'GitLab Duo Agentic Chat',
                classicTitle: 'GitLab Duo Chat',
                agenticComponent: DuoAgenticChat,
                classicComponent: DuoChat,
                defaultProps: {
                  isAgenticAvailable,
                  isClassicAvailable: true,
                  showStudioHeader: true,
                  creditsAvailable: true,
                },
              },
            },
          });

          await nextTick();
          await waitForPromises();

          expect(findContentContainer().props('title')).toBe(expectedTitle);
        },
      );
    });
  });

  describe('chat mode switching', () => {
    describe('component switching based on chat mode', () => {
      it('renders agentic chat component when in agentic mode', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
        await createComponent();

        expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
      });

      it('renders classic chat component when in classic mode', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
        await createComponent();

        expect(findContentContainer().props('title')).toBe('GitLab Duo Chat');
      });

      it('switches component when chat mode changes from agentic to classic', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
        await createComponent();

        expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');

        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
        await nextTick();
        await waitForPromises();

        expect(findContentContainer().props('title')).toBe('GitLab Duo Chat');
      });

      it('applies classic mode to chat tab', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
        await createComponent();

        expect(findContentContainer().exists()).toBe(true);
        expect(findContentContainer().props('title')).toBe('GitLab Duo Chat');
      });

      it('applies agentic mode to chat tab', async () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
        await createComponent();

        expect(findContentContainer().exists()).toBe(true);
        expect(findContentContainer().props('title')).toBe('GitLab Duo Agentic Chat');
      });
    });

    describe('activeTab reactivity with route changes', () => {
      it('opens sessions panel when navigating to sessions route', async () => {
        await createComponent();
        await router.push({ name: AGENTS_PLATFORM_INDEX_ROUTE });
        await nextTick();
        await waitForPromises();

        expect(findContentContainer().exists()).toBe(true);
        expect(findContentContainer().props('title')).toBe('Sessions');
      });

      it('closes panel when navigating to closed route', async () => {
        await createComponent();
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');

        expect(findContentContainer().exists()).toBe(true);

        await emitAndWait(findContentContainer, 'close-panel');

        expect(router.currentRoute.name).toBe(CLOSED_ROUTE);
        expect(findContentContainer().exists()).toBe(false);
      });
    });
  });

  describe('when chat is disabled', () => {
    describe('with chatDisabledReason prop set', () => {
      it('passes chatDisabledReason and IDs to navigation rail', async () => {
        await createComponent({
          propsData: {
            chatDisabledReason: 'project',
            projectId: 'gid://gitlab/Project/123',
            namespaceId: 'gid://gitlab/Group/456',
          },
        });
        expect(findNavigationRail().props()).toMatchObject({
          chatDisabledReason: 'project',
          projectId: 'gid://gitlab/Project/123',
          namespaceId: 'gid://gitlab/Group/456',
        });
      });

      it('prevents opening chat tab on mount when user cannot configure', async () => {
        await createComponent({ propsData: { chatDisabledReason: 'project' } });

        expect(findContentContainer().exists()).toBe(false);
      });
    });

    describe('when user can configure duo settings', () => {
      const createDisabledAdminComponent = async (overrides = {}) => {
        await createComponent({
          routeName: overrides.routeName,
          propsData: {
            chatDisabledReason: 'project',
            shouldShowBlockedState: true,
            ...overrides.propsData,
          },
          provide: {
            chatConfiguration: {
              agenticTitle: 'GitLab Duo Agentic Chat',
              classicTitle: 'GitLab Duo Chat',
              agenticComponent: DuoAgenticChat,
              classicComponent: DuoChat,
              defaultProps: {
                isAgenticAvailable: true,
                isClassicAvailable: true,
                duoSettingsPath: '/test/project/edit#js-gitlab-duo-settings',
                creditsAvailable: true,
                ...overrides.defaultProps,
              },
            },
          },
        });
      };

      it('does not auto-open chat tab on mount when panel is closed', async () => {
        await createDisabledAdminComponent({ routeName: CLOSED_ROUTE });

        expect(router.currentRoute.name).toBe(CLOSED_ROUTE);
        expect(findContentContainer().exists()).toBe(false);
      });

      it('stays on agentic chat blocked route on mount when panel is already open', async () => {
        await createDisabledAdminComponent();

        expect(router.currentRoute.name).toBe(AGENTIC_CHAT_BLOCKED_ROUTE);
      });

      it('renders content container with admin title when panel is open', async () => {
        await createDisabledAdminComponent();

        expect(findContentContainer().exists()).toBe(true);
        expect(findContentContainer().props('title')).toBe('GitLab Duo Agent Platform');
      });

      it('closes panel when chat tab is toggled again', async () => {
        await createDisabledAdminComponent();

        expect(findContentContainer().exists()).toBe(true);

        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');

        expect(router.currentRoute.name).toBe(CLOSED_ROUTE);
        expect(findContentContainer().exists()).toBe(false);
      });
    });

    describe('when subscription is expired', () => {
      const createSubscriptionExpiredComponent = async (overrides = {}) => {
        await createComponent({
          routeName: overrides.routeName,
          propsData: {
            shouldShowBlockedState: true,
            ...overrides.propsData,
          },
          provide: {
            chatConfiguration: {
              agenticTitle: 'GitLab Duo Agentic Chat',
              classicTitle: 'GitLab Duo Chat',
              agenticComponent: DuoAgenticChat,
              classicComponent: DuoChat,
              defaultProps: {
                isAgenticAvailable: true,
                isClassicAvailable: true,
                isSubscriptionExpired: true,
                creditsAvailable: true,
                ...overrides.defaultProps,
              },
            },
          },
        });
      };

      it('navigates to blocked chat route when chat tab is toggled from another tab', async () => {
        await createSubscriptionExpiredComponent();
        // Move off the chat tab first so the next toggle is non-trivial
        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'sessions');
        pushSpy = jest.spyOn(router, 'push').mockResolvedValue();

        await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');

        expect(pushSpy).toHaveBeenCalledWith({ name: AGENTIC_CHAT_BLOCKED_ROUTE });
      });
    });

    describe('when user cannot configure duo settings', () => {
      it('blocks content container from rendering', async () => {
        await createComponent({
          propsData: { chatDisabledReason: 'project' },
          provide: {
            chatConfiguration: {
              agenticTitle: 'GitLab Duo Agentic Chat',
              classicTitle: 'GitLab Duo Chat',
              agenticComponent: DuoAgenticChat,
              classicComponent: DuoChat,
              defaultProps: {
                isAgenticAvailable: true,
                isClassicAvailable: true,
                canConfigureDuoSettings: false,
                creditsAvailable: true,
              },
            },
          },
        });

        expect(findContentContainer().exists()).toBe(false);
      });
    });
  });

  describe('session information button', () => {
    describe('when on agent platform show route', () => {
      beforeEach(async () => {
        await createComponent({
          routeName: AGENTS_PLATFORM_INDEX_ROUTE,
        });
        await router.push({ name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id: '123' } });
        await nextTick();
        await waitForPromises();
      });

      it('shows information button', () => {
        expect(findContentContainer().props('showInformationButton')).toBe(true);
        expect(findContentContainer().props('informationButtonLabel')).toBe('Session information');
      });
    });

    describe('when not on agent platform show route', () => {
      it('does not show information button', async () => {
        await createComponent({
          routeName: AGENTIC_CHAT_SHOW_ROUTE,
        });
        await nextTick();
        await waitForPromises();

        expect(findContentContainer().props('showInformationButton')).toBe(false);
      });
    });
  });

  describe('switch-to-active-tab from router-view', () => {
    it('navigates to chat route', async () => {
      await createComponent({ routeName: AGENTS_PLATFORM_INDEX_ROUTE });
      pushSpy = jest.spyOn(router, 'push').mockResolvedValue();

      await wrapper.vm.handleChangeTab('chat');
      await waitForPromises();

      expect(pushSpy).toHaveBeenCalledWith({ name: AGENTIC_CHAT_SHOW_ROUTE });
    });
  });

  describe('session menu in header slot', () => {
    beforeEach(async () => {
      await createComponent();
      await emitAndWait(findNavigationRail, 'handle-tab-toggle', 'chat');
    });

    it('does not render session menu when showSessionId is false', () => {
      expect(findSessionMenu().exists()).toBe(false);
    });
  });

  describe('drag resize', () => {
    const findResizer = () => wrapper.findComponent(AccessiblePanelResizer);

    beforeEach(() => {
      duoChatGlobalState.aiPanelDragWidth = null;
      // isMaximizedVar is a module-level Apollo reactive var — it survives
      // fresh mockApollo creation between tests. Reset explicitly so prior
      // tests that set it to true don't poison this block.
      setMaximized(false);
    });

    it('renders AccessiblePanelResizer when isPanelOpen=true, isDesktop=true, isMaximized=false', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      await setMaximized(false);
      await nextTick();

      expect(findResizer().exists()).toBe(true);
    });

    it('does not render AccessiblePanelResizer when isMaximized=true', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      await setMaximized(true);
      jest.runAllTimers();
      await waitForPromises();
      await nextTick();

      expect(findResizer().exists()).toBe(false);
    });

    it('does not render AccessiblePanelResizer when isDesktop=false', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(false);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });

      expect(findResizer().exists()).toBe(false);
    });

    it('does not render AccessiblePanelResizer when isPanelOpen=false', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: CLOSED_ROUTE });

      expect(findResizer().exists()).toBe(false);
    });

    it('drives v-model from duoChatGlobalState.aiPanelDragWidth and writes back on input', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      await setMaximized(false);
      duoChatGlobalState.aiPanelDragWidth = 640;
      await nextTick();
      expect(findResizer().props('value')).toBe(640);
      expect(findResizer().props('minSize')).toBe(400);
      expect(findResizer().props('maxSize')).toBe(Math.min(window.innerWidth * 0.6, 960));

      findResizer().vm.$emit('input', 720);
      await nextTick();
      expect(duoChatGlobalState.aiPanelDragWidth).toBe(720);
    });

    it('exposes the rendered panel width on aria-content-container as --ai-panel-width', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      duoChatGlobalState.aiPanelDragWidth = 500;
      await nextTick();

      // Assert against the rendered DOM, not the computed property —
      // tests the observable contract, not the implementation shape.
      const containerEl = findContentContainer().element;
      expect(containerEl.style.getPropertyValue('--ai-panel-width')).toBe('500px');
    });

    it('does not set --ai-panel-width when aiPanelDragWidth is null', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      duoChatGlobalState.aiPanelDragWidth = null;
      await nextTick();

      const containerEl = findContentContainer().element;
      expect(containerEl.style.getPropertyValue('--ai-panel-width')).toBe('');
    });

    it('refreshes defaultSize on viewport resize when no drag override is set', async () => {
      // The CSS `clamp(25rem, 20vw, 35rem)` produces a viewport-dependent
      // painted width. Without this refresh, aria-valuenow would lag the
      // visible width as the user resizes the browser.
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      await setMaximized(false);
      duoChatGlobalState.aiPanelDragWidth = null;
      await nextTick();

      wrapper.vm.readPanelWidth = jest.fn().mockReturnValue(560);

      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 1400,
      });
      window.dispatchEvent(new Event('resize'));
      await nextTick();

      expect(wrapper.vm.readPanelWidth).toHaveBeenCalled();
      expect(findResizer().props('defaultSize')).toBe(560);
    });

    it('does not refresh defaultSize on resize when a drag override is set', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      await setMaximized(false);
      duoChatGlobalState.aiPanelDragWidth = 720;
      await nextTick();

      wrapper.vm.readPanelWidth = jest.fn();

      window.dispatchEvent(new Event('resize'));
      await nextTick();

      expect(wrapper.vm.readPanelWidth).not.toHaveBeenCalled();
    });

    it('does not refresh defaultSize while maximized', async () => {
      // The portal width during maximize is the full viewport, not the
      // default CSS clamp; reading it would mislead next un-maximize.
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      await setMaximized(true);
      jest.runAllTimers();
      await waitForPromises();
      await nextTick();
      duoChatGlobalState.aiPanelDragWidth = null;

      wrapper.vm.readPanelWidth = jest.fn();

      window.dispatchEvent(new Event('resize'));
      await nextTick();

      expect(wrapper.vm.readPanelWidth).not.toHaveBeenCalled();
    });

    it('updates the resizer max-size after a window resize event', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      await setMaximized(false);
      await nextTick();

      Object.defineProperty(window, 'innerWidth', {
        writable: true,
        configurable: true,
        value: 800,
      });
      window.dispatchEvent(new Event('resize'));
      await nextTick();

      // 800 * 0.6 = 480, below the 960 ceiling
      expect(findResizer().props('maxSize')).toBe(480);
    });

    it('closePanel resets aiPanelDragWidth to null', async () => {
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      duoChatGlobalState.aiPanelDragWidth = 550;

      await emitAndWait(findContentContainer, 'close-panel');

      expect(duoChatGlobalState.aiPanelDragWidth).toBeNull();
    });

    it('toggleMaximize preserves the user-dragged width across maximize cycles', async () => {
      // Locked decision: drag-width persists across maximize/un-maximize so
      // the user's chosen width is restored when leaving maximized state.
      jest.spyOn(GlBreakpointInstance, 'isDesktop').mockReturnValue(true);
      await createComponent({ routeName: AGENTIC_CHAT_SHOW_ROUTE });
      duoChatGlobalState.aiPanelDragWidth = 720;
      await nextTick();

      await emitAndWait(findContentContainer, 'toggle-maximize');
      expect(duoChatGlobalState.aiPanelDragWidth).toBe(720);

      await emitAndWait(findContentContainer, 'toggle-maximize');
      expect(duoChatGlobalState.aiPanelDragWidth).toBe(720);
    });
  });

  describe('when user is non-admin and duo is disabled', () => {
    const createNonAdminDisabledComponent = async (overrides = {}) => {
      await createComponent({
        routeName: overrides.routeName,
        propsData: {
          shouldShowBlockedState: true,
          ...overrides.propsData,
        },
        provide: {
          chatConfiguration: {
            agenticTitle: 'GitLab Duo Agentic Chat',
            classicTitle: 'GitLab Duo Chat',
            agenticComponent: DuoAgenticChat,
            classicComponent: DuoChat,
            defaultProps: {
              isAgenticAvailable: true,
              isClassicAvailable: true,
              isDuoDisabledNonAdmin: true,
              creditsAvailable: true,
              ...overrides.defaultProps,
            },
          },
        },
      });
    };

    it('does not auto-open chat tab on mount when panel is closed', async () => {
      await createNonAdminDisabledComponent({ routeName: CLOSED_ROUTE });

      expect(router.currentRoute.name).toBe(CLOSED_ROUTE);
      expect(findContentContainer().exists()).toBe(false);
    });

    it('stays on agentic chat blocked route on mount when panel is already open', async () => {
      await createNonAdminDisabledComponent();

      expect(router.currentRoute.name).toBe(AGENTIC_CHAT_BLOCKED_ROUTE);
    });

    it('renders content container with blocked-state title when panel is open', async () => {
      await createNonAdminDisabledComponent();

      expect(findContentContainer().exists()).toBe(true);
      expect(findContentContainer().props('title')).toBe('GitLab Duo Agent Platform');
    });
  });
});
