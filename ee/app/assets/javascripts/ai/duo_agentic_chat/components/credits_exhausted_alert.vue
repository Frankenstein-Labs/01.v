<script>
import { GlAlert, GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';

export default {
  name: 'CreditsExhaustedAlert',
  components: {
    GlAlert,
    GlButton,
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
    isFreeAddonCreditsUser: {
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
    isTrialOrFreeAddon() {
      return this.isTrial || this.isFreeAddonCreditsUser;
    },
    title() {
      return this.isTrialOrFreeAddon
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
      if (this.isFreeAddonCreditsUser) return 'free_addon';
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
  <gl-alert
    variant="warning"
    :dismissible="false"
    :title="title"
    data-testid="credits-exhausted-alert"
  >
    <p>{{ description }}</p>
    <template #actions>
      <div class="gl-flex gl-gap-2">
        <gl-button
          :href="$options.learnMorePath"
          target="_blank"
          size="small"
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
          size="small"
          data-testid="primary-cta"
          @click="onPrimaryCtaClick"
        >
          {{ primaryCtaText }}
        </gl-button>
      </div>
    </template>
  </gl-alert>
</template>
