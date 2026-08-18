<script>
import { GlButton, GlCard } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'UpgradeToPremiumCard',
  components: {
    GlButton,
    GlCard,
  },
  inject: {
    upgradeButtonPath: { default: null },
    creditsGeneralizationUi: { default: false },
  },
  computed: {
    headerText() {
      return this.creditsGeneralizationUi
        ? s__('AiPowered|Do more with Premium')
        : s__('AiPowered|Unlock more credits with Premium');
    },
    bodyText() {
      return this.creditsGeneralizationUi
        ? s__(
            'AiPowered|Upgrade to Premium to unlock advanced features and get more out of your GitLab Credits.',
          )
        : s__(
            'AiPowered|Upgrade to keep using GitLab Duo Agent Platform and access a broad credit allocation.',
          );
    },
  },
};
</script>
<template>
  <gl-card class="gl-flex-1" header-class="gl-heading-scale-400">
    <template #header>
      <div class="gl-flex gl-items-center gl-justify-between">
        <span>{{ headerText }}</span>
        <gl-button
          v-if="creditsGeneralizationUi"
          :href="upgradeButtonPath"
          size="small"
          data-event-tracking="click_cta_upgrade_to_premium"
          data-event-property="upgrade_to_premium_card"
        >
          {{ __('Upgrade to Premium') }}
        </gl-button>
      </div>
    </template>
    <div class="gl-flex gl-h-full gl-flex-col gl-justify-between">
      <div>
        {{ bodyText }}
      </div>
      <div v-if="!creditsGeneralizationUi" class="gl-pt-5">
        <gl-button
          :href="upgradeButtonPath"
          data-event-tracking="click_cta_upgrade_to_premium"
          data-event-property="upgrade_to_premium_card"
        >
          {{ __('Upgrade to Premium') }}
        </gl-button>
      </div>
    </div>
  </gl-card>
</template>
