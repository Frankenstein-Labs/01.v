<script>
import { GlButton } from '@gitlab/ui';
import { snakeCase } from 'lodash-es';
import { InternalEvents } from '~/tracking';
import {
  TRIAL_TYPES_CONFIG,
  TRIAL_WIDGET_CLICK_LEARN_MORE,
  TRIAL_WIDGET_CLICK_UPGRADE,
} from './constants';

export default {
  name: 'TrialWidgetButtons',
  handRaiseLeadAttributes: {
    variant: 'link',
    category: 'tertiary',
    size: 'small',
  },
  components: {
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    trialType: { default: '' },
    purchaseNowUrl: { default: '' },
    trialDiscoverPagePath: { default: '' },
  },
  computed: {
    trackingLabel() {
      return snakeCase(TRIAL_TYPES_CONFIG[this.trialType].name.toLowerCase());
    },
  },
  methods: {
    handleUpgrade() {
      this.trackEvent(TRIAL_WIDGET_CLICK_UPGRADE, {
        label: this.trackingLabel,
      });
    },
    handleLearnMore() {
      this.trackEvent(TRIAL_WIDGET_CLICK_LEARN_MORE, {
        label: this.trackingLabel,
      });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-gap-3">
    <gl-button
      :href="trialDiscoverPagePath"
      class="gl-flex-1 gl-rounded-base"
      size="small"
      variant="confirm"
      category="secondary"
      data-testid="learn-about-features-btn"
      @click.stop="handleLearnMore"
    >
      {{ s__('TrialWidget|Learn more') }}
    </gl-button>

    <gl-button
      :href="purchaseNowUrl"
      class="gl-flex-1 gl-rounded-base"
      size="small"
      variant="confirm"
      data-testid="upgrade-options-btn"
      referrerpolicy="no-referrer-when-downgrade"
      @click.stop="handleUpgrade"
    >
      {{ s__('TrialWidget|Upgrade') }}
    </gl-button>
  </div>
</template>
