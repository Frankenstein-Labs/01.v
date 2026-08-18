<script>
import { GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';

export default {
  name: 'NoCreditsEmptyState',
  components: {
    GlButton,
    TanukiAiIcon,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    isTrial: {
      type: Boolean,
      required: false,
      default: false,
    },
    purchaseCreditsPath: {
      type: String,
      required: false,
      default: '',
    },
    canBuyAddon: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasAgenticToggle: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    headline() {
      return this.isTrial
        ? s__('DuoAgenticChat|No credits remaining')
        : s__('DuoAgenticChat|No credits remain for this billing period');
    },
    description() {
      if (this.hasAgenticToggle) {
        return this.isTrial
          ? s__(
              'DuoAgenticChat|Purchase credits or turn off the Agentic toggle to start a new conversation.',
            )
          : s__(
              'DuoAgenticChat|Purchase more credits or turn off the Agentic toggle to start a new conversation.',
            );
      }
      return this.isTrial
        ? s__(
            'DuoAgenticChat|To continue collaborating with GitLab Duo Agent Platform, purchase credits.',
          )
        : s__(
            'DuoAgenticChat|To continue collaborating with GitLab Duo Agent Platform, purchase more credits.',
          );
    },
    primaryCtaText() {
      return this.isTrial
        ? s__('DuoAgenticChat|Purchase credits')
        : s__('DuoAgenticChat|Purchase more credits');
    },
    showPrimaryCta() {
      return this.canBuyAddon && Boolean(this.purchaseCreditsPath);
    },
  },
  mounted() {
    this.trackEvent('view_duo_agentic_no_credits_empty_state', { label: this.trackingLabel() });
  },
  methods: {
    trackingLabel() {
      return this.isTrial ? 'trial' : 'paid';
    },
    onLearnMoreClick() {
      this.trackEvent('click_duo_agentic_no_credits_learn_more', { label: this.trackingLabel() });
    },
    onPrimaryCtaClick() {
      this.trackEvent('click_duo_agentic_no_credits_purchase_credits', {
        label: this.trackingLabel(),
      });
    },
  },
  learnMorePath: helpPagePath('user/duo_agent_platform/_index'),
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4 gl-py-8"
    data-testid="no-credits-empty-state"
  >
    <tanuki-ai-icon />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ headline }}
    </h2>
    <p class="gl-text-subtle">
      {{ description }}
    </p>
    <div class="gl-flex gl-gap-3">
      <gl-button
        :href="$options.learnMorePath"
        target="_blank"
        data-testid="learn-more-button"
        @click="onLearnMoreClick"
      >
        {{ s__('DuoAgenticChat|Learn more') }}
      </gl-button>
      <gl-button
        v-if="showPrimaryCta"
        :href="purchaseCreditsPath"
        variant="confirm"
        category="primary"
        data-testid="primary-cta"
        @click="onPrimaryCtaClick"
      >
        {{ primaryCtaText }}
      </gl-button>
    </div>
  </div>
</template>
