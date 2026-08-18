<script>
import { PLAN_CONFIDENCE_LEVELS, CONFIDENCE_SCORE_BAR_COUNT } from './constants';
import { getVariantColor } from './utils';

export default {
  name: 'ConfidenceBar',
  props: {
    confidenceLevel: {
      type: Object,
      required: true,
      validator: (value) => Object.keys(PLAN_CONFIDENCE_LEVELS).includes(value.value),
    },
    ariaLabel: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    pillBgClass() {
      return getVariantColor(this.confidenceLevel.variant);
    },
    pillStyle() {
      const { barsToFill } = this.confidenceLevel;
      return {
        width: `${(barsToFill / CONFIDENCE_SCORE_BAR_COUNT) * 100}%`,
        backgroundColor: this.pillBgClass,
      };
    },
  },
};
</script>
<template>
  <span
    class="gl-relative gl-block gl-h-2 gl-w-11 gl-rounded-sm gl-bg-status-neutral"
    role="status"
    :aria-label="ariaLabel"
  >
    <span class="gl-absolute gl-block gl-h-2 gl-rounded-sm" :style="pillStyle"></span>
  </span>
</template>
