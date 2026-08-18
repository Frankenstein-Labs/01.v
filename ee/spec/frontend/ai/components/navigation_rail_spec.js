import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { shouldDisableShortcuts } from '~/behaviors/shortcuts/shortcuts_toggle';
import { keysFor, DUO_CHAT } from '~/behaviors/shortcuts/keybindings';
import NavigationRail from 'ee/ai/components/navigation_rail.vue';
import NewChatButton from 'ee/ai/components/new_chat_button.vue';
import {
  AGENTIC_CHAT_SHOW_ROUTE,
  AGENTIC_CHAT_HISTORY_ROUTE,
  AGENTS_PLATFORM_INDEX_ROUTE,
  CLOSED_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';

const TAB_TO_ROUTE = {
  chat: AGENTIC_CHAT_SHOW_ROUTE,
  history: AGENTIC_CHAT_HISTORY_ROUTE,
  sessions: AGENTS_PLATFORM_INDEX_ROUTE,
  // Note: suggestions tab has no route mapping - it is effectively unused in production
};

jest.mock('~/behaviors/shortcuts/shortcuts_toggle');
jest.mock('~/behaviors/shortcuts/keybindings');

describe('NavigationRail', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    const { activeTab = 'chat', routeName: explicitRouteName, ...restProps } = props;
    const routeName = explicitRouteName || TAB_TO_ROUTE[activeTab] || CLOSED_ROUTE;
    wrapper = shallowMountExtended(NavigationRail, {
      propsData: {
        isExpanded: true,
        showSuggestionsTab: true,
        showSessionsTab: true,
        chatDisabledReason: '',
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Namespace/456',
        isAgenticMode: true,
        showChatDisabledNav: false,
        ...restProps,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      mocks: {
        $route: { name: routeName, params: {}, path: '/' },
      },
    });
  };

  const findChatButton = () => wrapper.findByTestId('ai-chat-toggle');
  const findHistoryButton = () => wrapper.findByTestId('ai-history-toggle');
  const findSuggestionsButton = () => wrapper.findByTestId('ai-suggestions-toggle');
  const findSessionsButton = () => wrapper.findByTestId('ai-sessions-toggle');
  const findAiCatalogButton = () => wrapper.findComponentByTestId('ai-catalog-button');
  const findNewChatButton = () => wrapper.findComponent(NewChatButton);

  beforeEach(() => {
    shouldDisableShortcuts.mockReturnValue(false);
    keysFor.mockReturnValue([DUO_CHAT]);
  });

  describe('NewChatButton', () => {
    beforeEach(() => {
      createComponent({
        projectId: 'proj-1',
        namespaceId: 'ns-1',
        isAgenticMode: true,
        activeTab: 'chat',
      });
    });

    it('passes correct props', () => {
      expect(findNewChatButton().props()).toMatchObject({
        projectId: 'proj-1',
        namespaceId: 'ns-1',
        isAgentSelectEnabled: true,
        isChatDisabled: false,
      });
    });

    it('emits new-chat event with agent', async () => {
      await findNewChatButton().vm.$emit('new-chat', { id: 'agent1' });
      expect(wrapper.emitted('new-chat')).toEqual([[{ id: 'agent1' }]]);
    });

    it('emits new-chat event without agent', async () => {
      await findNewChatButton().vm.$emit('new-chat');
      expect(wrapper.emitted('new-chat')).toHaveLength(1);
    });

    it('emits new-chat-error event', async () => {
      const error = new Error('test');
      await findNewChatButton().vm.$emit('new-chat-error', error);
      expect(wrapper.emitted('new-chat-error')).toEqual([[error]]);
    });
  });

  describe('NewChatButton when chat disabled', () => {
    it('passes isChatDisabled when chatDisabledReason is set', () => {
      createComponent({ chatDisabledReason: 'project' });
      expect(findNewChatButton().props('isChatDisabled')).toBe(true);
    });
  });

  describe.each`
    name             | testId                     | tabValue         | ariaLabel
    ${'Chat'}        | ${'ai-chat-toggle'}        | ${'chat'}        | ${'Active GitLab Duo Chat'}
    ${'History'}     | ${'ai-history-toggle'}     | ${'history'}     | ${'GitLab Duo Chat history'}
    ${'Sessions'}    | ${'ai-sessions-toggle'}    | ${'sessions'}    | ${'GitLab Duo sessions'}
    ${'Suggestions'} | ${'ai-suggestions-toggle'} | ${'suggestions'} | ${'GitLab Duo suggestions'}
  `('$name button', ({ testId, tabValue, ariaLabel }) => {
    const findButton = () => wrapper.findComponentByTestId(testId);

    describe('default state', () => {
      beforeEach(() => {
        createComponent();
      });

      it('has arias', () => {
        expect(findButton().attributes('aria-label')).toBe(ariaLabel);
      });

      it('emits handle-tab-toggle on click', async () => {
        await findButton().vm.$emit('click');
        expect(wrapper.emitted('handle-tab-toggle')).toEqual([[tabValue]]);
      });
    });

    describe('collapsed state', () => {
      // When the pane is closed no tab is selected, so aria-selected must be
      // omitted entirely (rather than rendered as "false") to avoid assistive
      // tech announcing every tab as "not selected".
      it.each`
        scenario             | activeTab
        ${'no active tab'}   | ${'other'}
        ${'this tab active'} | ${tabValue}
      `('omits aria-selected when closed ($scenario)', ({ activeTab }) => {
        createComponent({ isExpanded: false, activeTab });
        expect(findButton().attributes('aria-selected')).toBeUndefined();
      });
    });

    // Suggestions tab has no route mapping, so active/inactive state
    // cannot be tested via route-derived activeTab — skip for those.
    // eslint-disable-next-line no-unused-expressions -- conditional test registration
    TAB_TO_ROUTE[tabValue] &&
      describe('active state', () => {
        beforeEach(() => {
          createComponent({ activeTab: tabValue });
        });

        it('has attributes and styling', () => {
          expect(findButton().attributes('aria-selected')).toBe('true');
          expect(findButton().props('selected')).toBe(true);
        });
      });

    // eslint-disable-next-line no-unused-expressions -- conditional test registration
    TAB_TO_ROUTE[tabValue] &&
      describe('inactive state', () => {
        beforeEach(() => {
          createComponent({ activeTab: 'other' });
        });

        it('has attributes and styling', () => {
          expect(findButton().attributes('aria-selected')).toBe('false');
          expect(findButton().props('selected')).toBe(false);
        });
      });

    describe('disabled state', () => {
      beforeEach(() => {
        createComponent({ chatDisabledReason: 'project' });
      });

      it('has disabled attributes and styling', () => {
        expect(findButton().attributes('aria-disabled')).toBe('true');
        expect(findButton().classes()).toContain('gl-opacity-5');
      });

      it('does not emit event on click', async () => {
        await findButton().trigger('click');
        expect(wrapper.emitted('handle-tab-toggle')).toBeUndefined();
      });
    });
  });

  describe('Chat button', () => {
    describe('keyboard shortcut', () => {
      it.each`
        scenario                  | shortcutsDisabled | chatDisabledReason | shouldShow
        ${'shown when enabled'}   | ${false}          | ${''}              | ${true}
        ${'hidden when disabled'} | ${true}           | ${''}              | ${false}
        ${'hidden when chat off'} | ${false}          | ${'project'}       | ${false}
      `(
        'aria-keyshortcuts is $scenario',
        ({ shortcutsDisabled, chatDisabledReason, shouldShow }) => {
          shouldDisableShortcuts.mockReturnValue(shortcutsDisabled);
          createComponent({ chatDisabledReason });
          expect(findChatButton().attributes('aria-keyshortcuts') !== undefined).toBe(shouldShow);
        },
      );
    });

    describe('tooltip', () => {
      it.each`
        isAgenticMode | expectedText
        ${true}       | ${'Current GitLab Duo Chat'}
        ${false}      | ${'Active GitLab Duo Chat'}
      `(
        'shows "$expectedText" when isAgenticMode=$isAgenticMode',
        ({ isAgenticMode, expectedText }) => {
          createComponent({ isAgenticMode });
          const tooltip = getBinding(findChatButton().element, 'gl-tooltip');
          expect(tooltip.value.title).toContain(expectedText);
        },
      );

      it('shows disabled message when chat is disabled', () => {
        createComponent({ chatDisabledReason: 'project' });
        const tooltip = getBinding(findChatButton().element, 'gl-tooltip');
        expect(tooltip.value.title).toBe(
          'An administrator has turned off GitLab Duo for this project.',
        );
      });
    });
  });

  describe('when the chat is disabled but a blocked state is being rendered', () => {
    const createDisabledNav = () =>
      createComponent({ chatDisabledReason: 'project', showChatDisabledNav: true });
    const findDuoDisabledToggle = () => wrapper.findComponentByTestId('duo-disabled-toggle');

    it('renders only the duo-disabled toggle button', () => {
      createDisabledNav();

      expect(findDuoDisabledToggle().exists()).toBe(true);
      expect(findChatButton().exists()).toBe(false);
      expect(findHistoryButton().exists()).toBe(false);
      expect(findSessionsButton().exists()).toBe(false);
    });

    it('hides the new chat button', () => {
      createDisabledNav();

      expect(findNewChatButton().exists()).toBe(false);
    });

    it('emits handle-tab-toggle with chat on click', async () => {
      createDisabledNav();

      await findDuoDisabledToggle().vm.$emit('click');
      expect(wrapper.emitted('handle-tab-toggle')).toEqual([['chat']]);
    });

    it('shows active state when panel is expanded', () => {
      createComponent({
        chatDisabledReason: 'project',
        showChatDisabledNav: true,
        isExpanded: true,
      });
      expect(findDuoDisabledToggle().props('selected')).toBe(true);
    });

    it('does not show active state when panel is collapsed', () => {
      createComponent({
        chatDisabledReason: 'project',
        showChatDisabledNav: true,
        isExpanded: false,
      });
      expect(findDuoDisabledToggle().props('selected')).toBe(false);
    });
  });

  describe('History button tooltip', () => {
    it('shows correct tooltip', () => {
      createComponent();
      expect(findHistoryButton().attributes('title')).toBe('GitLab Duo Chat history');
    });

    it('shows disabled tooltip when chat is disabled', () => {
      createComponent({ chatDisabledReason: 'project' });
      expect(findHistoryButton().attributes('title')).toBe(
        'An administrator has turned off GitLab Duo for this project.',
      );
    });
  });

  describe('Sessions button tooltip', () => {
    it('shows correct tooltip', () => {
      createComponent();
      expect(findSessionsButton().attributes('title')).toBe('GitLab Duo sessions');
    });

    it('shows disabled tooltip when chat is disabled', () => {
      createComponent({ chatDisabledReason: 'project' });
      expect(findSessionsButton().attributes('title')).toBe(
        'An administrator has turned off GitLab Duo for this project.',
      );
    });
  });

  describe('AI Catalog button', () => {
    it('does not render when exploreAiCatalogPath is not provided', () => {
      createComponent();
      expect(findAiCatalogButton().exists()).toBe(false);
    });

    describe('when exploreAiCatalogPath is provided', () => {
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      beforeEach(() => {
        createComponent({ exploreAiCatalogPath: '/explore/ai-catalog/agents' });
      });

      it('renders with the correct href', () => {
        expect(findAiCatalogButton().attributes('href')).toBe('/explore/ai-catalog/agents');
      });

      it('opens the AI catalog in a new tab', () => {
        expect(findAiCatalogButton().attributes('target')).toBe('_blank');
      });

      it('shows the correct tooltip', () => {
        expect(findAiCatalogButton().attributes('title')).toBe('GitLab Duo AI Catalog');
      });

      it('tracks the click event', () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        findAiCatalogButton().vm.$emit('click');
        expect(trackEventSpy).toHaveBeenCalledWith(
          'click_ai_catalog_button_duo_rail',
          {},
          undefined,
        );
      });
    });
  });

  describe('Sessions button', () => {
    describe('conditional rendering', () => {
      it.each([true, false])('renders=%s when showSessionsTab=%s', (showSessionsTab) => {
        createComponent({ showSessionsTab });
        expect(findSessionsButton().exists()).toBe(showSessionsTab);
      });
    });
  });

  describe('Suggestions button', () => {
    describe('conditional rendering', () => {
      it.each([true, false])('renders=%s when showSuggestionsTab=%s', (showSuggestionsTab) => {
        createComponent({ showSuggestionsTab });
        expect(findSuggestionsButton().exists()).toBe(showSuggestionsTab);
      });
    });

    describe('tooltip', () => {
      it('shows correct tooltip', () => {
        createComponent();
        expect(findSuggestionsButton().attributes('title')).toBe('GitLab Duo suggestions');
      });

      it('shows disabled tooltip when chat is disabled', () => {
        createComponent({ chatDisabledReason: 'project' });
        expect(findSuggestionsButton().attributes('title')).toBe(
          'An administrator has turned off GitLab Duo for this project.',
        );
      });
    });
  });
});
