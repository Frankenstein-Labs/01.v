<script>
import { GlLink, GlTooltipDirective, GlButton, GlProgressBar, GlSkeletonLoader } from '@gitlab/ui';
import { isNil } from 'lodash-es';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { formatNumber } from '~/locale';

export default {
  name: 'StatisticsCard',
  components: { GlLink, GlButton, GlProgressBar, GlSkeletonLoader, HelpIcon },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    usageValue: {
      type: [Number, String],
      required: false,
      default: null,
    },
    usageUnit: {
      type: String,
      required: false,
      default: null,
    },
    totalValue: {
      type: [Number, String],
      required: false,
      default: null,
    },
    totalUnit: {
      type: String,
      required: false,
      default: null,
    },
    summaryDataTestid: {
      type: String,
      required: false,
      default: 'denominator',
    },
    description: {
      type: String,
      required: false,
      default: null,
    },
    helpLink: {
      type: String,
      required: false,
      default: null,
    },
    helpLabel: {
      type: String,
      required: false,
      default: null,
    },
    helpTooltip: {
      type: String,
      required: false,
      default: null,
    },
    percentage: {
      type: Number,
      required: false,
      default: null,
    },
    purchaseButtonLink: {
      type: String,
      required: false,
      default: null,
    },
    purchaseButtonText: {
      type: String,
      required: false,
      default: null,
    },
    cssClass: {
      type: String,
      required: false,
      default: null,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  methods: {
    isNil,
    formatValue(input) {
      return Number.isInteger(input) ? formatNumber(input) : input;
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-rounded-base gl-border-section gl-bg-section gl-p-5"
    data-testid="container"
    :class="cssClass"
  >
    <div v-if="loading" class="@lg/panel:gl-w-1/2">
      <gl-skeleton-loader :height="50">
        <rect width="140" height="30" x="5" y="0" rx="4" />
        <rect width="240" height="10" x="5" y="40" rx="4" />
      </gl-skeleton-loader>
    </div>
    <template v-else>
      <div class="gl-flex gl-justify-between">
        <h3
          v-if="!isNil(usageValue) && usageValue !== ''"
          class="gl-heading-2 gl-mb-3"
          :data-testid="summaryDataTestid"
        >
          {{ formatValue(usageValue) }}
          <span v-if="usageUnit" data-testid="denominator-usage-unit" class="gl-text-lg">{{
            usageUnit
          }}</span>
          <span v-if="totalValue" data-testid="denominator-total">
            /
            {{ formatValue(totalValue) }}
            <span v-if="totalUnit" class="gl-text-lg" data-testid="denominator-total-unit">{{
              totalUnit
            }}</span>
          </span>
        </h3>

        <div>
          <gl-button
            v-if="purchaseButtonLink && purchaseButtonText"
            :href="purchaseButtonLink"
            referrerpolicy="no-referrer-when-downgrade"
            category="primary"
            variant="confirm"
          >
            {{ purchaseButtonText }}
          </gl-button>
        </div>
      </div>
      <p v-if="description" class="gl-mb-0 gl-font-bold" data-testid="description">
        {{ description }}
        <gl-link
          v-if="helpLink"
          v-gl-tooltip
          :href="helpLink"
          target="_blank"
          class="gl-ml-2"
          :title="helpTooltip"
          :aria-label="helpLabel"
        >
          <help-icon />
        </gl-link>
      </p>
      <gl-progress-bar v-if="percentage !== null" class="gl-mt-5" :value="percentage" />
    </template>
  </div>
</template>
