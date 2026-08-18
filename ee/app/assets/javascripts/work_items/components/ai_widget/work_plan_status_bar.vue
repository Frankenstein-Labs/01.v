<script>
import { AGENT_STEP_PILL_VARIANTS } from './constants';
import { getVariantColor } from './utils';

export default {
  name: 'WorkPlanStatusBar',
  props: {
    variant: {
      type: String,
      required: true,
      validator: (value) => Object.keys(AGENT_STEP_PILL_VARIANTS).includes(value),
    },
  },
  computed: {
    barBgClass() {
      return { backgroundColor: getVariantColor(this.variant) };
    },
  },
};
</script>
<template>
  <div
    class="gl-h-full gl-min-h-5 gl-w-2 gl-flex-shrink-0 gl-self-stretch gl-rounded-full"
    :style="barBgClass"
  ></div>
</template>
