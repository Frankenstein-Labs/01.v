import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton, GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { createMockDirective } from 'helpers/vue_mock_directive';
import waitForPromises from 'helpers/wait_for_promises';
import { copyToClipboard } from '~/lib/utils/copy_to_clipboard';
import showGlobalToast from '~/vue_shared/plugins/global_toast';
import AiContentContainer from 'ee/ai/components/content_container.vue';
import PanelActions from '~/vue_shared/components/panel_actions.vue';
import { CHAT_MODES } from 'ee/ai/tanuki_bot/constants';
import {
  AGENTIC_CHAT_SHOW_ROUTE,
  AGENTIC_CHAT_HISTORY_ROUTE,
  CLASSIC_CHAT_HISTORY_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import { duoChatGlobalState } from '~/super_sidebar/state';
import createMockApollo from 'helpers/mock_apollo_helper';
import { cacheConfig, setPanelTitle, setPanelSubtitle } from 'ee/ai/graphql';

Vue.use(VueApollo);

jest.mock('~/lib/utils/copy_to_clipboard');
jest.mock('~/vue_shared/plugins/global_toast');

const SlotContentStub = stubComponent(
  {
    name: 'SlotContent',
    props: [
      'showSessionId',
      'showSessionDropdownTooltip',
      'toggleText',
      'items',
      'showSessionDropdown',
      'hideSessionDropdown',
      'handleTitleChange',
      'handleSessionIdChanged',
    ],
  },
  {
    template: '<div data-testid="slot-content"></div>',
  },
);

describe('AiContentContainer', () => {
  let wrapper;
  let mockStore;
  let mockApollo;

  const defaultTitle = 'Test Tab Title';

  const createComponent = ({
    title = defaultTitle,
    showBackButton = false,
    propsData = {},
    mocks = {},
    apolloData = {},
    directives = { GlTooltip: createMockDirective('gl-tooltip') },
  } = {}) => {
    mockStore = {
      dispatch: jest.fn(),
    };

    mockApollo = createMockApollo([], {}, cacheConfig);

    wrapper = shallowMountExtended(AiContentContainer, {
      apolloProvider: mockApollo,
      directives,
      propsData: {
        title,
        showBackButton,
        userId: 'gid://gitlab/User/1',
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Group/456',
        rootNamespaceId: 'gid://gitlab/Group/789',
        resourceId: 'gid://gitlab/Resource/111',
        metadata: '{"key":"value"}',
        userModelSelectionEnabled: false,
        isMaximized: false,
        showLoadingState: false,
        ...propsData,
      },
      mocks: {
        $store: mockStore,
        $route: {
          name: null,
          params: {},
          path: '/',
        },
        ...mocks,
      },
      stubs: {
        GlButton,
        SlotContent: SlotContentStub,
        PanelActions,
      },
      scopedSlots: {
        'active-tab': `<slot-content v-bind="props" />`,
      },
      data() {
        return apolloData;
      },
    });
  };

  const findSlotContent = () => wrapper.findComponent(SlotContentStub);

  const findPanelTitle = () => wrapper.findByTestId('content-container-title');
  const findPanelSubtitle = () => wrapper.findByTestId('content-container-subtitle');
  const findCloseButton = () => wrapper.findByTestId('content-container-close-button');
  const findMaximizeButton = () =>
    wrapper.findComponentByTestId('content-container-maximize-button');
  const findBackButton = () => wrapper.findComponentByTestId('content-container-back-button');
  const findInformationButton = () => wrapper.findByTestId('content-container-information-button');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findPanelContent = () => wrapper.findByTestId('ai-panel-content');
  const findPanelContentPlaceholder = () => wrapper.findByTestId('ai-panel-content-placeholder');

  const setPanelTitleAndSubtitle = async (title, subtitle) => {
    setPanelTitle(title);
    setPanelSubtitle(subtitle);

    await wrapper.vm.$apollo.queries.panelTitleState.refetch();
  };

  beforeEach(() => {
    // Reset global state before each test
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;

    // Reset Apollo reactive variables
    setPanelTitle(null);
    setPanelSubtitle(null);
  });

  it('renders the tab title in the header', () => {
    createComponent();
    expect(findPanelTitle().text()).toBe(defaultTitle);
  });

  it('renders maximize and close buttons', () => {
    createComponent();
    expect(findMaximizeButton().exists()).toBe(true);
    expect(findCloseButton().exists()).toBe(true);
    expect(findCloseButton().attributes('aria-label')).toBe('Close panel');
  });

  describe('information button', () => {
    it('does not show information button by default', () => {
      createComponent();
      expect(findInformationButton().exists()).toBe(false);
    });

    it('shows information button when showInformationButton is true', () => {
      createComponent({
        propsData: {
          showInformationButton: true,
          informationButtonLabel: 'Session Info',
        },
      });
      expect(findInformationButton().exists()).toBe(true);
      expect(findInformationButton().attributes('aria-label')).toBe('Session Info');
      expect(findInformationButton().attributes('title')).toBe('Session Info');
    });

    it('uses default label when informationButtonLabel is not provided', () => {
      createComponent({
        propsData: {
          showInformationButton: true,
        },
      });
      expect(findInformationButton().attributes('aria-label')).toBe('Information');
    });

    it('emits toggle-session-information event when clicked', async () => {
      createComponent({
        propsData: {
          showInformationButton: true,
        },
      });
      await nextTick();
      findInformationButton().trigger('click');
      await nextTick();
      expect(wrapper.emitted('toggle-session-information')).toEqual([[]]);
    });
  });

  it('closes the panel when close button is clicked', async () => {
    createComponent();
    findCloseButton().trigger('click');
    await nextTick();
    expect(wrapper.emitted('close-panel')).toEqual([[false]]);
  });

  it('shows the maximize icon when minimized', () => {
    createComponent();
    expect(findMaximizeButton().props('icon')).toBe('maximize');
  });

  it('shows the minimized icon when maximized', () => {
    createComponent({ propsData: { isMaximized: true } });
    expect(findMaximizeButton().props('icon')).toBe('minimize');
  });

  it('toggles maximized state', () => {
    createComponent();
    findMaximizeButton().trigger('click');
    expect(wrapper.emitted('toggle-maximize')).toStrictEqual([[]]);
  });

  describe('when showBackButton is false', () => {
    beforeEach(() => {
      createComponent({ showBackButton: false });
    });

    it('hides the back button', () => {
      expect(findBackButton().classes()).toContain('!gl-hidden');
    });
  });

  describe('when showBackButton is true', () => {
    beforeEach(() => {
      createComponent({ showBackButton: true });
    });

    it('shows the back button', () => {
      expect(findBackButton().classes()).not.toContain('!gl-hidden');
    });

    it('has correct back button attributes', () => {
      expect(findBackButton().props('icon')).toBe('go-back');
      expect(findBackButton().props('category')).toBe('tertiary');
      expect(findBackButton().attributes('aria-label')).toBe('Go back');
      expect(findBackButton().attributes('title')).toBe('Go back');
    });

    it('emits go-back event when back button is clicked', async () => {
      findBackButton().trigger('click');
      await nextTick();
      expect(wrapper.emitted('go-back')).toEqual([[]]);
    });
  });

  describe('props passing to dynamic component', () => {
    it('renders dynamic component with props bound', () => {
      createComponent({
        title: 'Test Component',
        propsData: {
          projectId: 'gid://gitlab/Project/999',
          namespaceId: 'gid://gitlab/Group/888',
          rootNamespaceId: 'gid://gitlab/Group/777',
          resourceId: 'gid://gitlab/Resource/666',
          metadata: '{"test":"data"}',
          userModelSelectionEnabled: true,
        },
      });

      // Verify the component is rendered in the panel body
      expect(findPanelContent().exists()).toBe(true);
    });

    it('does not render string placeholder for non-string components', () => {
      createComponent({ title: 'Test Component' });

      expect(findPanelContentPlaceholder().exists()).toBe(false);
    });
  });

  describe('slot rendering', () => {
    it('renders the panel body for slot content', () => {
      createComponent({ title: 'Test Component' });

      expect(findPanelContent().exists()).toBe(true);
    });

    it('does not error when activeTab.props is undefined', () => {
      expect(() => {
        createComponent({ title: 'Test Component' });
      }).not.toThrow();
    });
  });

  describe('panel title and subtitle via reactive vars', () => {
    it('displays default tab title when showLoadingState is false', async () => {
      createComponent({
        title: 'Test Component',
        propsData: { showLoadingState: false },
      });

      await nextTick();

      expect(findPanelTitle().text()).toBe('Test Component');
      expect(findPanelSubtitle().exists()).toBe(false);
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('shows skeleton loader when showLoadingState is true and no panelSubtitle', async () => {
      createComponent({
        title: 'Test Component',
        propsData: { showLoadingState: true },
      });

      await nextTick();

      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findPanelSubtitle().exists()).toBe(false);
    });

    it.each([[true], [false]])(
      'displays panelTitle and panelSubtitle when set with showLoadingState %p',
      async (showLoadingState) => {
        createComponent({
          title: 'Test Component',
          propsData: { showLoadingState },
        });

        await setPanelTitleAndSubtitle('Test Project', 'Test flow #123');
        await nextTick();

        expect(findPanelTitle().text()).toContain('Test Project');
        expect(findPanelSubtitle().text()).toContain('Test flow #123');
        expect(findSkeletonLoader().exists()).toBe(false);
      },
    );

    it('hides skeleton loader when panelSubtitle becomes available', async () => {
      createComponent({
        title: 'Test Component',
        propsData: { showLoadingState: true },
      });

      expect(findSkeletonLoader().exists()).toBe(true);

      await setPanelTitleAndSubtitle('Test Project', 'Test flow #123');
      await nextTick();

      expect(findSkeletonLoader().exists()).toBe(false);
      expect(findPanelTitle().text()).toContain('Test Project');
      expect(findPanelSubtitle().text()).toContain('Test flow #123');
    });
  });

  describe('session ID menu via slot props', () => {
    const triggerSessionIdChange = async (
      sessionId = 'test-session-123',
      title = 'new-chat-title',
    ) => {
      const slotContent = findSlotContent();
      slotContent.props('handleSessionIdChanged')(sessionId);
      slotContent.props('handleTitleChange')(title);
      await nextTick();
      return sessionId;
    };

    it('exposes handleSessionIdChanged via slot props', () => {
      createComponent({ title: 'Test Component' });
      expect(findSlotContent().props('handleSessionIdChanged')).toEqual(expect.any(Function));
    });

    it('exposes handleTitleChange via slot props', () => {
      createComponent({ title: 'Test Component' });
      expect(findSlotContent().props('handleTitleChange')).toEqual(expect.any(Function));
    });

    it('updates sessionIdItems when handleSessionIdChanged is called', async () => {
      createComponent({ title: 'Test Component' });

      await triggerSessionIdChange('new-session-id');

      const items = findSlotContent().props('items');
      expect(items[0].text).toContain('new-session-id');
      expect(items[0].text).toContain('Copy Chat Session ID');
    });

    it('does not show session ID initially', () => {
      createComponent({ title: 'Test Component' });
      expect(findSlotContent().props('showSessionId')).toBe(null);
    });

    it('shows session ID on agentic chat show route', async () => {
      createComponent({
        title: 'Test',
        mocks: { $route: { name: AGENTIC_CHAT_SHOW_ROUTE, params: {}, path: '/agentic-chat' } },
      });

      await triggerSessionIdChange('test-session-123');

      expect(findSlotContent().props('showSessionId')).toBe(true);
    });

    it('does not show session ID on a different route', async () => {
      createComponent({
        title: 'Test',
        mocks: {
          $route: { name: AGENTIC_CHAT_HISTORY_ROUTE, params: {}, path: '/agentic-chat/history' },
        },
      });

      await triggerSessionIdChange('test-session-123');

      expect(findSlotContent().props('showSessionId')).toBe(false);
    });

    it('does not show session ID when session ID is null', async () => {
      createComponent({
        title: 'Test',
        mocks: { $route: { name: AGENTIC_CHAT_SHOW_ROUTE, params: {}, path: '/agentic-chat' } },
      });

      findSlotContent().props('handleSessionIdChanged')(null);
      await nextTick();

      expect(findSlotContent().props('showSessionId')).toBe(null);
    });

    describe('copying session ID to clipboard', () => {
      it('copies session ID to clipboard when action is called', async () => {
        copyToClipboard.mockResolvedValue();
        createComponent({ title: 'Test Component' });
        const sessionId = await triggerSessionIdChange('test-session-copy');

        await findSlotContent().props('items')[0].action();

        expect(copyToClipboard).toHaveBeenCalledWith(sessionId);
      });

      it('shows success toast when copy succeeds', async () => {
        copyToClipboard.mockResolvedValue();
        createComponent({ title: 'Test Component' });
        await triggerSessionIdChange('test-session-success');

        await findSlotContent().props('items')[0].action();
        await waitForPromises();

        expect(showGlobalToast).toHaveBeenCalledWith('Session ID copied to clipboard');
      });

      it('shows error toast when copy fails', async () => {
        copyToClipboard.mockRejectedValue(new Error('Failed'));
        createComponent({ title: 'Test Component' });
        await triggerSessionIdChange('test-session-fail');

        await findSlotContent().props('items')[0].action();
        await waitForPromises();

        expect(showGlobalToast).toHaveBeenCalledWith('Could not copy session ID');
      });
    });
  });

  describe('heading title', () => {
    const changeTitle = async (title) => {
      findSlotContent().props('handleTitleChange')(title);
      await nextTick();
    };

    describe('when on a conversation show route', () => {
      it('uses the child-supplied title', async () => {
        createComponent({
          title: 'Duo Chat',
          mocks: { $route: { name: AGENTIC_CHAT_SHOW_ROUTE, params: {}, path: '/agentic-chat' } },
        });

        await changeTitle('How do I write a good commit message?');

        expect(findPanelTitle().text()).toBe('How do I write a good commit message?');
      });
    });

    describe('when on a conversation list route', () => {
      it.each([
        ['agentic chat history route', AGENTIC_CHAT_HISTORY_ROUTE, '/agentic-chat/history'],
        ['classic chat history route', CLASSIC_CHAT_HISTORY_ROUTE, '/chat/history'],
      ])('uses the route-derived title on the %s', async (_, name, path) => {
        createComponent({
          title: 'History',
          mocks: { $route: { name, params: {}, path } },
        });

        await changeTitle('How do I write a good commit message?');

        expect(findPanelTitle().text()).toBe('History');
      });
    });

    describe('when the route-derived title changes', () => {
      it('clears the child-supplied title', async () => {
        createComponent({
          title: 'Duo Chat',
          directives: {},
          mocks: { $route: { name: AGENTIC_CHAT_SHOW_ROUTE, params: {}, path: '/agentic-chat' } },
        });

        await changeTitle('How do I write a good commit message?');
        expect(findPanelTitle().text()).toBe('How do I write a good commit message?');

        await wrapper.setProps({ title: 'History' });

        expect(findPanelTitle().text()).toBe('History');
      });
    });
  });
});
