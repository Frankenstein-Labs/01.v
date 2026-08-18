<script>
import { GlBadge } from '@gitlab/ui';
import { GlSparklineChart } from '@gitlab/ui/src/charts';
import { GL_COLOR_DATA_GREEN_600 } from '@gitlab/ui/src/tokens/build/js/tokens';

// Maps the delta direction to a Pajamas badge variant and a trend arrow.
const DELTA_VARIANT = { up: 'success', down: 'danger', neutral: 'muted' };
const DELTA_ICON = { up: 'arrow-up', down: 'arrow-down' };

export default {
  name: 'SummaryMetricTile',
  components: {
    GlBadge,
    GlSparklineChart,
  },
  props: {
    label: {
      type: String,
      required: true,
    },
    value: {
      type: String,
      required: false,
      default: '—',
    },
    delta: {
      type: String,
      required: false,
      default: '',
    },
    deltaDirection: {
      type: String,
      required: false,
      default: 'neutral',
      validator: (value) => ['up', 'down', 'neutral'].includes(value),
    },
    chartData: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    deltaVariant() {
      return DELTA_VARIANT[this.deltaDirection];
    },
    deltaIcon() {
      return DELTA_ICON[this.deltaDirection];
    },
  },
  chartGradient: [GL_COLOR_DATA_GREEN_600, GL_COLOR_DATA_GREEN_600],
};
</script>

<template>
  <div class="gl-border gl-rounded-base gl-border-section gl-bg-section gl-p-5">
    <div class="gl-text-subtle">{{ label }}</div>
    <div class="gl-mt-3 gl-text-size-h1 gl-font-bold">{{ value }}</div>
    <gl-badge
      v-if="delta"
      :variant="deltaVariant"
      :icon="deltaIcon"
      class="gl-mt-2"
      data-testid="summary-metric-delta"
    >
      {{ delta }}
    </gl-badge>
    <gl-sparkline-chart
      v-if="chartData.length"
      :height="48"
      :data="chartData"
      :show-last-y-value="false"
      :gradient="$options.chartGradient"
      :smooth="0.2"
      class="gl-mt-4 gl-w-full"
      data-testid="summary-metric-chart"
    />
  </div>
</template>
