<script>
import { GlButton } from '@gitlab/ui';
import tanukiAiSvgUrl from '@gitlab/svgs/dist/illustrations/tanuki-ai-sm.svg?url';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'SubscriptionExpiredEmptyState',
  components: { GlButton },
  props: {
    buyAddonPath: { type: String, required: false, default: '' },
    canBuyAddon: { type: Boolean, required: true },
  },
  computed: {
    showUpgradeCta() {
      return this.canBuyAddon && Boolean(this.buyAddonPath);
    },
  },
  tanukiAiSvgUrl,
  dapDocs: helpPagePath('/user/duo_agent_platform/_index.md'),
  events: {
    view: 'view_duo_agentic_subscription_expired_empty_state',
    clickUpgrade: 'click_duo_agentic_subscription_expired_upgrade',
    clickLearnMore: 'click_duo_agentic_subscription_expired_learn_more',
  },
  i18n: {
    headline: s__('DuoAgenticChat|Your GitLab Duo Agent Platform subscription has been cancelled'),
    description: s__(
      'DuoAgenticChat|Your subscription has been cancelled. Repurchase to resume using GitLab Duo Agent Platform.',
    ),
    repurchaseCta: s__('DuoAgenticChat|Repurchase Agent Platform'),
    learnMore: s__('DuoAgenticChat|Learn more'),
    tanukiAlt: s__('DuoAgenticChat|GitLab Duo AI assistant'),
  },
};
</script>

<template>
  <div
    class="gl-flex gl-w-full gl-flex-col gl-items-start gl-gap-4"
    data-testid="subscription-expired-empty-state"
    :data-event-tracking="$options.events.view"
    data-event-tracking-load="true"
  >
    <img :src="$options.tanukiAiSvgUrl" class="gl-h-10 gl-w-10" :alt="$options.i18n.tanukiAlt" />

    <h2 class="gl-my-0 gl-text-size-h2">
      {{ $options.i18n.headline }}
    </h2>

    <p class="gl-m-0 gl-text-subtle" data-testid="subscription-expired-description">
      {{ $options.i18n.description }}
    </p>

    <div class="gl-flex gl-gap-4">
      <gl-button
        v-if="showUpgradeCta"
        :href="buyAddonPath"
        variant="confirm"
        category="primary"
        data-testid="subscription-expired-upgrade-button"
        :data-event-tracking="$options.events.clickUpgrade"
      >
        {{ $options.i18n.repurchaseCta }}
      </gl-button>
      <gl-button
        :href="$options.dapDocs"
        target="_blank"
        data-testid="subscription-expired-learn-more-button"
        :data-event-tracking="$options.events.clickLearnMore"
      >
        {{ $options.i18n.learnMore }}
      </gl-button>
    </div>
  </div>
</template>
