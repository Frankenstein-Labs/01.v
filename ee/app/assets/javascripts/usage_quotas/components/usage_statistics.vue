<script>
import { GlProgressBar } from '@gitlab/ui';

export default {
  name: 'UsageStatistics',
  components: {
    GlProgressBar,
  },
  props: {
    percentage: {
      type: Number,
      required: false,
      default: null,
    },
    usageUnit: {
      type: String,
      required: false,
      default: null,
    },
    usageValue: {
      type: String,
      required: false,
      default: null,
    },
    totalUnit: {
      type: String,
      required: false,
      default: null,
    },
    totalValue: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    shouldShowProgressBar() {
      return this.percentage !== null;
    },
  },
};
</script>

<template>
  <div>
    <section class="gl-flex gl-justify-between">
      <section>
        <slot name="description"></slot>
        <h2 v-if="usageValue" class="gl-heading-2 gl-mb-3">
          <span data-testid="usage-value">{{ usageValue }}</span>
          <span v-if="usageUnit" data-testid="usage-unit" class="gl-text-lg">{{ usageUnit }}</span>
          <span v-if="totalValue">
            /
            <span data-testid="total-value">{{ totalValue }}</span>
            <span v-if="totalUnit" class="gl-text-lg" data-testid="total-unit">{{
              totalUnit
            }}</span>
          </span>
        </h2>
      </section>
      <div class="gl-align-self-top">
        <slot name="actions"></slot>
      </div>
    </section>
    <gl-progress-bar v-if="shouldShowProgressBar" class="gl-mb-3 gl-h-3" :value="percentage" />
    <slot name="additional-info"></slot>
  </div>
</template>
