import Vue from 'vue';
import VueApollo from 'vue-apollo';
import DuoAgenticChatStateManager from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_state_manager.vue';
import { initDuoPanel } from 'ee/ai/init_duo_panel';
import { setAgenticMode } from 'ee/ai/utils';
import DuoChat from 'ee/ai/tanuki_bot/components/duo_chat_state_manager.vue';
import { initLazyHandRaiseLeadModal } from 'ee/hand_raise_leads/hand_raise_lead/init_lazy_hand_raise_lead_modal';

Vue.use(VueApollo);

jest.mock('ee/ai/utils', () => ({
  setAgenticMode: jest.fn(),
  activeWorkItemIds: {
    value: [],
  },
}));

jest.mock('ee/ai/duo_agents_platform/router/ai_panel_router', () => ({
  createRouter: jest.fn(() => {
    const mockRouter = {
      push: jest.fn().mockResolvedValue(true),
      beforeEach: jest.fn(),
    };
    return mockRouter;
  }),
}));

jest.mock('ee/hand_raise_leads/hand_raise_lead/init_lazy_hand_raise_lead_modal', () => ({
  initLazyHandRaiseLeadModal: jest.fn(),
}));

describe('initDuoPanel', () => {
  let el;

  const cleanEl = () => {
    if (el && el.parentNode) {
      el.parentNode.removeChild(el);
    }
  };

  const createDuoPanelElement = (dataset = {}) => {
    cleanEl();
    const element = document.createElement('div');
    element.id = 'duo-chat-panel';
    const attributes = {
      userId: 'gid://gitlab/User/1',
      projectId: 'gid://gitlab/Project/123',
      namespaceId: 'gid://gitlab/Group/456',
      rootNamespaceId: 'gid://gitlab/Group/789',
      resourceId: 'gid://gitlab/Resource/111',
      metadata: '{"key":"value"}',
      userModelSelectionEnabled: 'false',
      agenticAvailable: 'true',
      classicAvailable: 'true',
      forceAgenticModeForCoreDuoUsers: 'false',
      agenticUnavailableMessage: 'Agentic mode is not available',
      chatTitle: 'GitLab Duo Chat',
      chatDisabledReason: '',
      creditsAvailable: 'true',
      defaultNamespaceSelected: 'true',
      isSaas: 'true',
      preferencesPath: '/-/profile/preferences',
      ...dataset,
    };
    // Object.assign(element.dataset, ...) stringifies `undefined`/`null` to "undefined"/"null",
    // so filter them out to let callers opt out of a default (e.g. namespaceId: null).
    Object.entries(attributes).forEach(([key, value]) => {
      if (value !== null && value !== undefined) {
        element.dataset[key] = value;
      }
    });
    document.body.appendChild(element);
    return element;
  };

  beforeEach(() => {
    jest.clearAllMocks();
    // Create a mock page layout element
    const pageLayout = document.createElement('div');
    pageLayout.className = 'js-page-layout';
    document.body.appendChild(pageLayout);
  });

  afterEach(() => {
    cleanEl();
    const pageLayout = document.querySelector('.js-page-layout');
    if (pageLayout && pageLayout.parentNode) {
      pageLayout.parentNode.removeChild(pageLayout);
    }
  });

  describe('when duo-chat-panel element does not exist', () => {
    it('returns false', () => {
      const result = initDuoPanel();
      expect(result).toBe(false);
    });
  });

  describe('when duo-chat-panel element exists', () => {
    beforeEach(() => {
      el = createDuoPanelElement();
    });

    it('returns a Vue instance', () => {
      const vueInstance = initDuoPanel();
      expect(vueInstance).toHaveProperty('$options');
      expect(vueInstance.$options.name).toBe('DuoPanel');
    });

    describe('data attributes parsing', () => {
      it('extracts all required data attributes', () => {
        el = createDuoPanelElement({
          userId: 'gid://gitlab/User/999',
          projectId: 'gid://gitlab/Project/888',
          namespaceId: 'gid://gitlab/Group/777',
          rootNamespaceId: 'gid://gitlab/Group/666',
          resourceId: 'gid://gitlab/Resource/555',
          metadata: '{"custom":"data"}',
          userModelSelectionEnabled: 'true',
        });

        const vueInstance = initDuoPanel();
        const aiPanelProps = vueInstance.$children[0].$props;

        expect(aiPanelProps.userId).toBe('gid://gitlab/User/999');
        expect(aiPanelProps.projectId).toBe('gid://gitlab/Project/888');
        expect(aiPanelProps.namespaceId).toBe('gid://gitlab/Group/777');
        expect(aiPanelProps.rootNamespaceId).toBe('gid://gitlab/Group/666');
        expect(aiPanelProps.resourceId).toBe('gid://gitlab/Resource/555');
        expect(aiPanelProps.metadata).toBe('{"custom":"data"}');
        expect(aiPanelProps.userModelSelectionEnabled).toBe(true);
      });
    });

    describe('chat configuration', () => {
      it('provides chat configuration with agentic and classic components', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        // Access the AIPanel component which is the first child
        const aiPanel = vueInstance.$children[0];
        expect(aiPanel.chatConfiguration.agenticComponent).toBe(DuoAgenticChatStateManager);
        expect(aiPanel.chatConfiguration.classicComponent).toBe(DuoChat);
      });

      it('sets correct chat titles', () => {
        el = createDuoPanelElement({
          chatTitle: 'Custom Chat Title',
        });

        const vueInstance = initDuoPanel();

        const aiPanel = vueInstance.$children[0];
        expect(aiPanel.chatConfiguration.agenticTitle).toBe('Custom Chat Title');
        expect(aiPanel.chatConfiguration.classicTitle).toBeDefined();
      });

      it('includes default props in chat configuration', () => {
        el = createDuoPanelElement({
          userId: 'gid://gitlab/User/123',
          projectId: 'gid://gitlab/Project/456',
          userModelSelectionEnabled: 'true',
          agenticAvailable: 'true',
          classicAvailable: 'false',
        });

        const vueInstance = initDuoPanel();

        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;
        expect(defaultProps.userId).toBe('gid://gitlab/User/123');
        expect(defaultProps.projectId).toBe('gid://gitlab/Project/456');
        expect(defaultProps.userModelSelectionEnabled).toBe(true);
        expect(defaultProps.isAgenticAvailable).toBe(true);
        expect(defaultProps.isClassicAvailable).toBe(false);
      });
    });

    describe('agentic mode initialization', () => {
      it('does not set agentic mode when forceAgenticModeForCoreDuoUsers is false', () => {
        el = createDuoPanelElement({
          forceAgenticModeForCoreDuoUsers: 'false',
        });

        initDuoPanel();
        expect(setAgenticMode).not.toHaveBeenCalled();
      });

      it('sets agentic mode when forceAgenticModeForCoreDuoUsers is true', () => {
        el = createDuoPanelElement({
          forceAgenticModeForCoreDuoUsers: 'true',
        });

        initDuoPanel();
        expect(setAgenticMode).toHaveBeenCalledWith({
          agenticMode: true,
          saveCookie: true,
        });
      });
    });

    describe('Vue instance configuration', () => {
      it('sets the component name to DuoPanel', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        expect(vueInstance.$options.name).toBe('DuoPanel');
      });

      it('provides isSidePanelView as true', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        // isSidePanelView is provided to child components, check it's in the provide
        expect(vueInstance.$options.provide.isSidePanelView).toBe(true);
      });

      it('initializes with store', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        expect(vueInstance.$store).toBeDefined();
      });

      it('initializes with router', () => {
        el = createDuoPanelElement();
        const vueInstance = initDuoPanel();

        // In Vue 3 compat mode, the router is attached to the instance
        expect(vueInstance.$options.router).toBeDefined();
      });
    });

    describe('when the user cannot start a trial', () => {
      beforeEach(() => {
        createDuoPanelElement({ canStartTrial: 'false' });
      });

      it('parses `canStartTrial` from backend', () => {
        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.canStartTrial).toBe(false);
      });
    });

    describe('defaultNamespaceSelected attribute', () => {
      it('parses defaultNamespaceSelected as boolean true', () => {
        el = createDuoPanelElement({
          defaultNamespaceSelected: 'true',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.defaultNamespaceSelected).toBe(true);
      });

      it('parses defaultNamespaceSelected as boolean false', () => {
        el = createDuoPanelElement({
          defaultNamespaceSelected: 'false',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.defaultNamespaceSelected).toBe(false);
      });

      it('defaults to false when defaultNamespaceSelected is not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.defaultNamespaceSelected;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.defaultNamespaceSelected).toBe(false);
      });
    });

    describe('preferencesPath attribute', () => {
      it('extracts preferencesPath from dataset', () => {
        el = createDuoPanelElement({
          preferencesPath: '/-/profile/preferences',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.preferencesPath).toBe('/-/profile/preferences');
      });

      it('sets preferencesPath to undefined when not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.preferencesPath;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.preferencesPath).toBeUndefined();
      });
    });

    describe('defaultNamespaceRequired attribute', () => {
      it.each`
        condition                                                                       | dataset                                                                                            | expected
        ${'defaultNamespaceSelected is false and there is no namespaceId or projectId'} | ${{ defaultNamespaceSelected: 'false', namespaceId: null, projectId: null }}                       | ${true}
        ${'a namespaceId is present'}                                                   | ${{ defaultNamespaceSelected: 'false', namespaceId: 'gid://gitlab/Group/456', projectId: null }}   | ${false}
        ${'a projectId is present'}                                                     | ${{ defaultNamespaceSelected: 'false', projectId: 'gid://gitlab/Project/123', namespaceId: null }} | ${false}
        ${'defaultNamespaceSelected is true'}                                           | ${{ defaultNamespaceSelected: 'true', namespaceId: null, projectId: null }}                        | ${false}
        ${'isSaas is false'}                                                            | ${{ isSaas: 'false', defaultNamespaceSelected: 'false', namespaceId: null, projectId: null }}      | ${false}
      `('is $expected when $condition', ({ dataset, expected }) => {
        el = createDuoPanelElement(dataset);

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.defaultNamespaceRequired).toBe(expected);
      });

      it('marks the panel as blocked when a default namespace is required', () => {
        el = createDuoPanelElement({
          defaultNamespaceSelected: 'false',
          namespaceId: null,
          projectId: null,
        });

        const vueInstance = initDuoPanel();

        expect(vueInstance.$children[0].$props.shouldShowBlockedState).toBe(true);
      });
    });

    describe('isTrial attribute', () => {
      it('parses isTrial as boolean true', () => {
        el = createDuoPanelElement({
          isTrial: 'true',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.isTrial).toBe(true);
      });

      it('parses isTrial as boolean false', () => {
        el = createDuoPanelElement({
          isTrial: 'false',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.isTrial).toBe(false);
      });

      it('defaults to false when isTrial is not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.isTrial;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.isTrial).toBe(false);
      });
    });

    describe('buyAddonPath attribute', () => {
      it('extracts buyAddonPath from dataset', () => {
        el = createDuoPanelElement({
          buyAddonPath: '/groups/test/-/billings',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.buyAddonPath).toBe('/groups/test/-/billings');
      });

      it('sets buyAddonPath to undefined when not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.buyAddonPath;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.buyAddonPath).toBeUndefined();
      });
    });

    describe('canBuyAddon attribute', () => {
      it('parses canBuyAddon as boolean true', () => {
        el = createDuoPanelElement({
          canBuyAddon: 'true',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.canBuyAddon).toBe(true);
      });

      it('parses canBuyAddon as boolean false', () => {
        el = createDuoPanelElement({
          canBuyAddon: 'false',
        });

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.canBuyAddon).toBe(false);
      });

      it('defaults to false when canBuyAddon is not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.canBuyAddon;

        const vueInstance = initDuoPanel();
        const aiPanel = vueInstance.$children[0];
        const { defaultProps } = aiPanel.chatConfiguration;

        expect(defaultProps.canBuyAddon).toBe(false);
      });
    });

    describe('isSubscriptionExpired attribute', () => {
      it('parses subscriptionExpired as boolean true', () => {
        el = createDuoPanelElement({ subscriptionExpired: 'true' });

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.isSubscriptionExpired).toBe(true);
      });

      it('parses subscriptionExpired as boolean false', () => {
        el = createDuoPanelElement({ subscriptionExpired: 'false' });

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.isSubscriptionExpired).toBe(false);
      });

      it('defaults to false when subscriptionExpired is not provided', () => {
        el = createDuoPanelElement();
        delete el.dataset.subscriptionExpired;

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.isSubscriptionExpired).toBe(false);
      });
    });

    describe('duoAgentPlatformEnabled attribute', () => {
      it('parses duoAgentPlatformEnabled as boolean true', () => {
        el = createDuoPanelElement({ duoAgentPlatformEnabled: 'true' });

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.isDuoAgentPlatformEnabled).toBe(true);
      });

      it('parses duoAgentPlatformEnabled as boolean false', () => {
        el = createDuoPanelElement({ duoAgentPlatformEnabled: 'false' });

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.isDuoAgentPlatformEnabled).toBe(false);
      });

      it('defaults to false when duoAgentPlatformEnabled is not provided', () => {
        el = createDuoPanelElement();

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.isDuoAgentPlatformEnabled).toBe(false);
      });
    });

    describe('identity verification attributes', () => {
      it('parses identityVerificationRequired and passes the path through', () => {
        el = createDuoPanelElement({
          identityVerificationRequired: 'true',
          identityVerificationPath: '/-/identity_verification',
        });

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.identityVerificationRequired).toBe(true);
        expect(defaultProps.identityVerificationPath).toBe('/-/identity_verification');
      });

      it('defaults identityVerificationRequired to false when not provided', () => {
        el = createDuoPanelElement();

        const vueInstance = initDuoPanel();
        const { defaultProps } = vueInstance.$children[0].chatConfiguration;

        expect(defaultProps.identityVerificationRequired).toBe(false);
      });

      it('marks the panel as blocked when identity verification is required', () => {
        el = createDuoPanelElement({ identityVerificationRequired: 'true' });

        const vueInstance = initDuoPanel();

        expect(vueInstance.$children[0].$props.shouldShowBlockedState).toBe(true);
      });
    });

    describe('isHandRaiseLeadAvailable attribute', () => {
      it('calls initLazyHandRaiseLeadModal with the panel element', () => {
        el = createDuoPanelElement();

        initDuoPanel();

        expect(initLazyHandRaiseLeadModal).toHaveBeenCalledWith(el);
      });

      it('sets isHandRaiseLeadAvailable to true when initLazyHandRaiseLeadModal returns true', () => {
        initLazyHandRaiseLeadModal.mockReturnValue(true);
        el = createDuoPanelElement();

        const { defaultProps } = initDuoPanel().$children[0].chatConfiguration;

        expect(defaultProps.isHandRaiseLeadAvailable).toBe(true);
      });

      it('sets isHandRaiseLeadAvailable to false when initLazyHandRaiseLeadModal returns false', () => {
        initLazyHandRaiseLeadModal.mockReturnValue(false);
        el = createDuoPanelElement();

        const { defaultProps } = initDuoPanel().$children[0].chatConfiguration;

        expect(defaultProps.isHandRaiseLeadAvailable).toBe(false);
      });
    });
  });
});
