import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { waitFor, screen } from '@testing-library/vue';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { CHAT_MODES } from '~/super_sidebar/constants';
import AiPanel from 'ee/ai/components/ai_panel.vue';
import { createApolloProvider } from 'ee/ai/graphql';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import createStore from 'ee/ai/tanuki_bot/store';
import { fullMount, waitForElement } from 'ee_jest/msw_integration/test_helpers';

Vue.use(VueApollo);

const chatConfiguration = {
  agenticTitle: 'GitLab Duo Agentic Chat',
  classicTitle: 'GitLab Duo Chat',
  defaultProps: {
    isAgenticAvailable: true,
    isClassicAvailable: false,
    namespaceId: 'gid://gitlab/Namespace/1',
    defaultNamespaceSelected: true,
    duoSettingsPath: '/groups/gitlab-org/-/settings/gitlab_duo',
    isDuoDisabled: false,
    isDuoDisabledNonAdmin: false,
    containerType: 'group',
    canStartTrial: false,
    isTrialExpired: false,
    forceAgenticModeForCoreDuoUsers: false,
    canBuyAddon: false,
  },
};

describe('AI panel visibility persists across reloads', () => {
  const findPanelContent = () => document.querySelector('#ai-panel-portal');
  const findDuoDisabledToggle = () => screen.queryByTestId('duo-disabled-toggle');
  const findChatToggle = () => screen.queryByTestId('ai-chat-toggle');

  const mountPanel = ({
    chatDisabledReason = '',
    shouldShowBlockedState = false,
    autoExpand = false,
  } = {}) => {
    const router = createRouter('/', 'user', { ...chatConfiguration, autoExpand });
    const apolloProvider = createApolloProvider();
    const store = createStore();

    fullMount(AiPanel, {
      store,
      router,
      apolloProvider,
      propsData: {
        chatDisabledReason,
        shouldShowBlockedState,
      },
      provide: {
        isSidePanelView: true,
        chatConfiguration: { ...chatConfiguration, autoExpand },
        badgeType: 'beta',
      },
    });
  };

  const clearPanelStorage = () => {
    window.localStorage.clear();
    window.sessionStorage.clear();
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
    duoChatGlobalState.lastRoutePerTab = {};
  };

  const simulateReload = () => {
    document.body.innerHTML = '';
  };

  beforeEach(() => {
    clearPanelStorage();
  });

  afterEach(() => {
    clearPanelStorage();
  });

  describe('when GitLab Duo is disabled (admin)', () => {
    it('stays collapsed after reload when user closes the disabled Duo panel', async () => {
      mountPanel({ chatDisabledReason: 'project', shouldShowBlockedState: true });

      await waitForElement(findDuoDisabledToggle);
      expect(findPanelContent()).toBe(null);

      findDuoDisabledToggle().click();
      await waitFor(() => {
        expect(findPanelContent()).not.toBe(null);
      });

      findDuoDisabledToggle().click();
      await waitFor(() => {
        expect(findPanelContent()).toBe(null);
      });

      simulateReload();
      mountPanel({ chatDisabledReason: 'project', shouldShowBlockedState: true });

      await waitForElement(findDuoDisabledToggle);
      expect(findPanelContent()).toBe(null);
    });
  });

  describe('when Duo is enabled (regular user)', () => {
    it('stays collapsed after reload when the user closes the panel', async () => {
      mountPanel();

      await waitForElement(findChatToggle);

      findChatToggle().click();
      await waitFor(() => {
        expect(findPanelContent()).not.toBe(null);
      });

      findChatToggle().click();
      await waitFor(() => {
        expect(findPanelContent()).toBe(null);
      });

      simulateReload();
      mountPanel();

      await waitForElement(findChatToggle);
      expect(findPanelContent()).toBe(null);
    });
  });
});
