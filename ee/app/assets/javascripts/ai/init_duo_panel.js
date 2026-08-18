import Vue from 'vue';
import VueApollo from 'vue-apollo';
import DuoAgenticStateManager from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_state_manager.vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import DuoChat from 'ee/ai/tanuki_bot/components/duo_chat_state_manager.vue';
import { activeWorkItemIds } from '~/work_items/utils';
import { initLazyHandRaiseLeadModal } from 'ee/hand_raise_leads/hand_raise_lead/init_lazy_hand_raise_lead_modal';
import { setAgenticMode } from 'ee/ai/utils';
import store from './tanuki_bot/store';
import { createApolloProvider } from './graphql';
import AIPanel from './components/ai_panel.vue';

export function initDuoPanel() {
  const el = document.getElementById('duo-chat-panel');

  if (!el) {
    return false;
  }

  const {
    userId,
    projectId,
    projectPath,
    namespaceId,
    rootNamespaceId,
    resourceId,
    metadata,
    userModelSelectionEnabled,
    agenticAvailable,
    classicAvailable,
    forceAgenticModeForCoreDuoUsers,
    agenticUnavailableMessage,
    chatTitle,
    chatDisabledReason,
    duoSettingsPath,
    defaultNamespaceSelected,
    preferencesPath,
    isTrial,
    buyAddonPath,
    canBuyAddon,
    purchaseCreditsPath,
    tierUpgradePath,
    trialActive,
    subscriptionActive,
    subscriptionExpired,
    exploreAiCatalogPath,
    autoExpand,
    containerType,
    newTrialPath,
    trialDuration,
    isFreeAddonCreditsUser,
    duoAgentPlatformEnabled,
  } = el.dataset;

  const isHandRaiseLeadAvailable = initLazyHandRaiseLeadModal(el);

  if (parseBoolean(forceAgenticModeForCoreDuoUsers)) {
    setAgenticMode({ agenticMode: true, saveCookie: true });
  }

  Vue.use(VueApollo);

  const apolloProvider = createApolloProvider();

  const canConfigureDuoSettings = Boolean(duoSettingsPath);
  const isTrialExpired = parseBoolean(el.dataset.isTrialExpired);
  const isDuoDisabledForAdmin = chatDisabledReason && canConfigureDuoSettings;
  const isDuoDisabledNonAdmin = parseBoolean(el.dataset.isDuoDisabledNonAdmin);
  const isSubscriptionExpired = parseBoolean(subscriptionExpired);
  const canStartTrial = parseBoolean(el.dataset.canStartTrial);
  const accessDenied = parseBoolean(el.dataset.accessDenied);
  const identityVerificationRequired = parseBoolean(el.dataset.identityVerificationRequired);
  const { identityVerificationPath } = el.dataset;
  const isSaas = parseBoolean(el.dataset.isSaas);
  const isDefaultNamespaceSelected = parseBoolean(defaultNamespaceSelected);
  const defaultNamespaceRequired =
    isSaas && !isDefaultNamespaceSelected && !namespaceId && !projectId;
  const shouldShowBlockedState =
    isDuoDisabledForAdmin ||
    isDuoDisabledNonAdmin ||
    isTrialExpired ||
    isSubscriptionExpired ||
    canStartTrial ||
    accessDenied ||
    identityVerificationRequired ||
    defaultNamespaceRequired;

  // Configure chat-specific values in a single configuration object
  const chatConfiguration = {
    agenticComponent: DuoAgenticStateManager,
    classicComponent: DuoChat,
    agenticTitle: chatTitle || __('GitLab Duo Agentic Chat'),
    classicTitle: __('GitLab Duo Chat'),
    defaultProps: {
      userId,
      projectId,
      projectPath,
      namespaceId,
      rootNamespaceId,
      resourceId,
      metadata,
      agenticUnavailableMessage,
      userModelSelectionEnabled: parseBoolean(userModelSelectionEnabled),
      chatDisabledReason,
      isDuoDisabled: Boolean(chatDisabledReason),
      isAgenticAvailable: parseBoolean(agenticAvailable),
      isClassicAvailable: parseBoolean(classicAvailable),
      forceAgenticModeForCoreDuoUsers: parseBoolean(forceAgenticModeForCoreDuoUsers),
      chatTitle,
      canConfigureDuoSettings,
      duoSettingsPath,
      defaultNamespaceSelected: isDefaultNamespaceSelected,
      defaultNamespaceRequired,
      preferencesPath,
      isTrial: parseBoolean(isTrial),
      isTrialExpired,
      buyAddonPath,
      canBuyAddon: parseBoolean(canBuyAddon),
      purchaseCreditsPath,
      tierUpgradePath,
      isSaas,
      trialActive: parseBoolean(trialActive ?? 'false'),
      subscriptionActive: parseBoolean(subscriptionActive ?? 'false'),
      isSubscriptionExpired,
      exploreAiCatalogPath,
      isDuoDisabledNonAdmin,
      isFreeAddonCreditsUser: parseBoolean(isFreeAddonCreditsUser),
      isHandRaiseLeadAvailable,
      containerType,
      isDuoDisabledForAdmin,
      canStartTrial,
      newTrialPath,
      trialDuration,
      accessDenied,
      identityVerificationRequired,
      identityVerificationPath,
      shouldShowBlockedState,
      isDuoAgentPlatformEnabled: parseBoolean(duoAgentPlatformEnabled),
    },
  };

  const router = createRouter('/', 'user', {
    ...chatConfiguration,
    autoExpand: parseBoolean(autoExpand),
  });

  return new Vue({
    el,
    name: 'DuoPanel',
    store: store(),
    router,
    apolloProvider,
    provide: {
      isSidePanelView: true,
      // Inject chat configuration directly to components that need it
      chatConfiguration,
    },
    render(createElement) {
      const latestActiveWorkItemId = activeWorkItemIds.value[activeWorkItemIds.value.length - 1];
      return createElement(AIPanel, {
        props: {
          name: 'AiPanel',
          userId,
          projectId,
          namespaceId,
          rootNamespaceId,
          resourceId: latestActiveWorkItemId ?? resourceId,
          metadata,
          userModelSelectionEnabled: parseBoolean(userModelSelectionEnabled),
          chatDisabledReason,
          shouldShowBlockedState,
        },
      });
    },
  });
}
