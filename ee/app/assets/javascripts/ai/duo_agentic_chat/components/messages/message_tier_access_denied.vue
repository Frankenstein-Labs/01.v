<script>
import { GlButton } from '@gitlab/ui';
import { marked } from 'marked';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { sanitize } from '~/lib/dompurify';
import { strictMarkdownConfig } from '~/lib/utils/text_utility';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { InternalEvents } from '~/tracking';
import { s__ } from '~/locale';

const DEFAULT_PLAN_NAME = 'ultimate';
const TRACKING_EVENT_UPGRADE = 'click_upgrade_subscription_duo_chat_tier_access_denied';
const TRACKING_EVENT_LEARN_MORE = 'click_learn_more_duo_chat_tier_access_denied';
const UNKNOWN_PLAN_LABEL = 'unknown_plan';
const PLAN_LABELS = {
  premium: 'premium_plan',
  ultimate: 'ultimate_plan',
};
const HAND_RAISE_GLM_CONTENT = 'gitlab-duo-chat-tier-access-denied';
const HAND_RAISE_CTA_TRACKING = {
  action: 'click_button',
  label: 'duo_chat_tier_access_denied_talk_to_sales',
};
const HAND_RAISE_BUTTON_ATTRIBUTES = {
  variant: 'default',
  category: 'primary',
  'data-testid': 'tier-access-denied-talk-to-sales-button',
};

export default {
  name: 'MessageTierAccessDenied',
  i18n: {
    upgrade: s__('DuoAgenticChat|Upgrade subscription'),
    talkToSales: s__('DuoAgenticChat|Talk to sales'),
  },
  components: {
    GlButton,
    HandRaiseLeadButton,
  },
  directives: {
    SafeHtml,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    canBuyAddon: { default: false },
    tierUpgradePath: { default: '' },
  },
  props: {
    message: {
      required: true,
      type: Object,
    },
    isHandRaiseLeadAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    parsedContent() {
      const { content } = this.message;
      if (!content) return '';
      // When a CTA shows, collapse paragraph breaks so a trailing link
      // (e.g. "Learn more") renders inline with the message instead of below it.
      const source =
        this.canBuyAddon || this.isHandRaiseLeadAvailable
          ? content.replace(/\n+/g, ' ').trim()
          : content;
      return sanitize(marked.parse(source), strictMarkdownConfig);
    },
    rawRequiredPlan() {
      return this.message.required_plan ?? null;
    },
    purchasePlanName() {
      return this.rawRequiredPlan ?? DEFAULT_PLAN_NAME;
    },
    upgradeTrackingLabel() {
      return PLAN_LABELS[this.rawRequiredPlan] ?? UNKNOWN_PLAN_LABEL;
    },
    purchasePath() {
      return mergeUrlParams({ plan_name: this.purchasePlanName }, this.tierUpgradePath);
    },
  },
  methods: {
    onUpgradeClick() {
      this.trackEvent(TRACKING_EVENT_UPGRADE, { label: this.upgradeTrackingLabel });
    },
    onContentClick(event) {
      if (event.target.closest('a')) {
        this.trackEvent(TRACKING_EVENT_LEARN_MORE);
      }
    },
  },
  handRaiseGlmContent: HAND_RAISE_GLM_CONTENT,
  handRaiseCtaTracking: HAND_RAISE_CTA_TRACKING,
  handRaiseButtonAttributes: HAND_RAISE_BUTTON_ATTRIBUTES,
};
</script>

<template>
  <div data-testid="tier-access-denied-message">
    <div v-if="parsedContent" v-safe-html="parsedContent" @click="onContentClick"></div>
    <hand-raise-lead-button
      v-if="isHandRaiseLeadAvailable"
      :button-text="$options.i18n.talkToSales"
      :button-attributes="$options.handRaiseButtonAttributes"
      :cta-tracking="$options.handRaiseCtaTracking"
      :glm-content="$options.handRaiseGlmContent"
    />
    <gl-button v-else-if="canBuyAddon" :href="purchasePath" target="_blank" @click="onUpgradeClick">
      {{ $options.i18n.upgrade }}
    </gl-button>
  </div>
</template>
