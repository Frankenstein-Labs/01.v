<script>
import { s__ } from '~/locale';
import { computeTrustedUrls } from 'ee/ai/shared/utils/trusted_urls_utils';
import DuoAgenticChatView from './duo_agentic_chat_view.vue';
import AgenticModeToggle from './agentic_mode_toggle.vue';
import DuoDisabledEmptyState from './duo_disabled_empty_state.vue';
import DuoDisabledNonAdminEmptyState from './duo_disabled_non_admin_empty_state.vue';
import TrialExpiredEmptyState from './trial_expired_empty_state.vue';
import SubscriptionExpiredEmptyState from './subscription_expired_empty_state.vue';
import StartTrialEmptyState from './start_trial_empty_state.vue';
import AccessDeniedEmptyState from './access_denied_empty_state.vue';
import IdentityVerificationEmptyState from './identity_verification_empty_state.vue';
import NoNamespaceEmptyState from './no_namespace_empty_state.vue';

export default {
  name: 'DuoAgenticChatBlockedStateView',
  components: {
    DuoAgenticChatView,
    AgenticModeToggle,
    DuoDisabledEmptyState,
    DuoDisabledNonAdminEmptyState,
    TrialExpiredEmptyState,
    SubscriptionExpiredEmptyState,
    StartTrialEmptyState,
    AccessDeniedEmptyState,
    IdentityVerificationEmptyState,
    NoNamespaceEmptyState,
  },
  props: {
    isDuoDisabled: { type: Boolean, required: true },
    isDuoDisabledNonAdmin: { type: Boolean, required: true },
    containerType: { type: String, required: true },
    canStartTrial: { type: Boolean, required: true },
    isTrialExpired: { type: Boolean, required: true },
    isSubscriptionExpired: { type: Boolean, required: false, default: false },
    isClassicAvailable: { type: Boolean, required: true },
    forceAgenticModeForCoreDuoUsers: { type: Boolean, required: true },
    duoSettingsPath: { type: String, required: false, default: null },
    trustedUrls: { type: Array, required: false, default: () => [] },
    buyAddonPath: { type: String, required: false, default: '' },
    canBuyAddon: { type: Boolean, required: true },
    newTrialPath: { type: String, required: false, default: '' },
    trialDuration: { type: String, required: false, default: '' },
    accessDenied: { type: Boolean, required: true },
    identityVerificationRequired: { type: Boolean, required: false, default: false },
    identityVerificationPath: { type: String, required: false, default: '' },
    defaultNamespaceRequired: { type: Boolean, required: false, default: false },
    preferencesPath: { type: String, required: false, default: '' },
  },
  emits: ['return-to-classic'],
  computed: {
    computedTrustedUrls() {
      return computeTrustedUrls(this.trustedUrls);
    },
    chatState() {
      if (this.isSubscriptionExpired) {
        return {
          isEnabled: false,
          reason: s__('DuoAgenticChat|Your subscription has ended'),
        };
      }
      return { isEnabled: false, reason: s__('DuoAgenticChat|GitLab Duo is disabled') };
    },
  },
  emptyMessages: [],
};
</script>

<template>
  <duo-agentic-chat-view
    id="duo-chat"
    is-multithreaded
    show-header
    multi-threaded-view="chat"
    :chat-state="chatState"
    :messages="$options.emptyMessages"
    :trusted-urls="computedTrustedUrls"
    class="gl-h-full gl-w-full"
  >
    <template v-if="isClassicAvailable && !forceAgenticModeForCoreDuoUsers" #agentic-switch>
      <agentic-mode-toggle :value="true" @change="$emit('return-to-classic')" />
    </template>
    <template #custom-empty-state>
      <identity-verification-empty-state
        v-if="identityVerificationRequired"
        key="identity-verification-empty-state"
        :identity-verification-path="identityVerificationPath"
      />
      <subscription-expired-empty-state
        v-else-if="isSubscriptionExpired"
        key="subscription-expired-empty-state"
        :buy-addon-path="buyAddonPath"
        :can-buy-addon="canBuyAddon"
      />
      <duo-disabled-non-admin-empty-state
        v-else-if="isDuoDisabledNonAdmin"
        key="duo-disabled-non-admin"
        :container-type="containerType"
      />
      <duo-disabled-empty-state
        v-else-if="isDuoDisabled"
        key="duo-disabled-empty-state"
        :duo-settings-path="duoSettingsPath"
        :container-type="containerType"
      />
      <trial-expired-empty-state
        v-else-if="isTrialExpired"
        :can-buy-addon="canBuyAddon"
        :buy-addon-path="buyAddonPath"
      />
      <start-trial-empty-state
        v-else-if="canStartTrial"
        :new-trial-path="newTrialPath"
        :trial-duration="trialDuration"
      />
      <access-denied-empty-state v-else-if="accessDenied" :container-type="containerType" />
      <no-namespace-empty-state
        v-else-if="defaultNamespaceRequired"
        :preferences-path="preferencesPath"
      />
    </template>
  </duo-agentic-chat-view>
</template>
