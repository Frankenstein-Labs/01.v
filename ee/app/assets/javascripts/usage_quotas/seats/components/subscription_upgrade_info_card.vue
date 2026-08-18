<script>
import { GlButton } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import Tracking from '~/tracking';
import { EXPLORE_PAID_PLANS_CLICKED } from '../constants';

export default {
  name: 'SubscriptionUpgradeInfoCard',
  components: { GlButton },
  mixins: [Tracking.mixin()],
  inject: ['trialDuration'],
  props: {
    explorePlansPath: {
      type: String,
      required: true,
    },
  },
  i18n: {
    title: s__('Billing|Add additional seats'),
    cta: s__('Billing|Explore plans'),
    description: (duration) =>
      sprintf(
        s__(
          'Billing|Start a free %{duration}-day trial or upgrade to a paid tier to get an unlimited number of seats.',
        ),
        { duration },
      ),
  },
  methods: {
    trackClick() {
      this.track('click_button', { label: EXPLORE_PAID_PLANS_CLICKED });
    },
  },
};
</script>

<template>
  <div class="gl-rounded-base gl-border-1 gl-border-solid gl-border-blue-300 gl-bg-default gl-p-6">
    <div class="gl-flex gl-flex-col @md/panel:gl-flex-row">
      <div class="gl-mb-3 @sm/panel:gl-mr-0 @md/panel:gl-mb-0 @md/panel:gl-mr-5">
        <p class="gl-mb-3 gl-font-bold" data-testid="title">
          {{ $options.i18n.title }}
        </p>
        <p class="gl-m-0" data-testid="description">
          {{ $options.i18n.description(trialDuration) }}
        </p>
      </div>
      <div>
        <gl-button
          :href="explorePlansPath"
          category="primary"
          variant="confirm"
          size="small"
          @click="trackClick"
        >
          {{ $options.i18n.cta }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
