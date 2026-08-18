<script>
import { GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';

export default {
  name: 'FreeAddonExhaustedEmptyState',
  components: {
    GlButton,
    TanukiAiIcon,
  },
  mixins: [InternalEvents.mixin()],
  props: {
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
  },
  computed: {
    showPrimaryCta() {
      return this.canBuyAddon && Boolean(this.purchaseCreditsPath);
    },
  },
  mounted() {
    this.trackEvent('view_duo_agentic_no_credits_empty_state', { label: 'free_addon' });
  },
  methods: {
    onLearnMoreClick() {
      this.trackEvent('click_duo_agentic_no_credits_learn_more', { label: 'free_addon' });
    },
    onPurchaseCreditsClick() {
      this.trackEvent('click_duo_agentic_no_credits_purchase_credits', { label: 'free_addon' });
    },
  },
  learnMorePath: helpPagePath('user/duo_agent_platform/_index'),
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4 gl-py-8"
    data-testid="free-addon-exhausted-empty-state"
  >
    <tanuki-ai-icon />
    <h2 class="gl-my-0 gl-text-size-h2">
      {{ s__('DuoAgenticChat|No credits remaining') }}
    </h2>
    <p class="gl-text-subtle">
      {{
        s__(
          'DuoAgenticChat|To continue collaborating with GitLab Duo Agent Platform, purchase more credits.',
        )
      }}
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
        @click="onPurchaseCreditsClick"
      >
        {{ s__('DuoAgenticChat|Purchase credits') }}
      </gl-button>
    </div>
  </div>
</template>
