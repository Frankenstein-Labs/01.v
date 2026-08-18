<script>
import { GlIcon, GlLink, GlSprintf } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { s__ } from '~/locale';
import { PREMIUM_PLAN_PRICE } from 'ee/billings/constants';

const formattedPrice = new Intl.NumberFormat(undefined, {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
}).format(PREMIUM_PLAN_PRICE);

export default {
  name: 'PremiumPlanSection',

  components: {
    GlIcon,
    GlLink,
    GlSprintf,
  },
  mixins: [InternalEvents.mixin()],
  i18n: {
    premiumFeatures: [
      s__('Billings|GitLab Duo Agent Platform'),
      s__('Billings|Release Controls'),
      s__('Billings|Team Project Management'),
      s__('Billings|Priority Support'),
      s__('Billings|10,000 compute minutes per month'),
      s__('Billings|Unlimited licensed users'),
    ],
    priceLabel: s__('Billings|%{price} per user/month'),
  },
  formattedPrice,
  props: {
    groupId: {
      type: Number,
      required: true,
    },
    groupBillingHref: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-pb-6">
      <h3 class="gl-heading-3 gl-mb-1 gl-text-default">{{ s__('Billings|Premium') }}</h3>
      <p class="gl-font-weight-semibold gl-m-0 gl-text-default">
        <gl-sprintf :message="$options.i18n.priceLabel">
          <template #price>{{ $options.formattedPrice }}</template>
        </gl-sprintf>
      </p>
    </div>

    <div class="gl-mb-5 gl-text-subtle">
      <p class="gl-mb-4 gl-text-md gl-font-normal">
        {{ s__('Billings|Everything from Free, plus:') }}
      </p>

      <div class="gl-list-style-none gl-p-0 gl-text-sm">
        <div
          v-for="(feature, index) in $options.i18n.premiumFeatures"
          :key="index"
          class="gl-display-flex gl-align-items-start gl-mb-3"
        >
          <gl-icon name="check" class="gl-mr-3 gl-mt-1" />
          <span>{{ feature }}</span>
        </div>
      </div>
    </div>

    <gl-link
      :href="groupBillingHref"
      data-event-tracking="click_link_compare_plans"
      :data-event-property="groupId"
    >
      {{ s__('Billings|See all features and compare plans') }}
    </gl-link>
  </div>
</template>
