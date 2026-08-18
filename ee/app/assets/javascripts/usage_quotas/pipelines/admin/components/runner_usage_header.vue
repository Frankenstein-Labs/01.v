<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';

export default {
  name: 'RunnerUsageHeader',
  components: {
    GlLoadingIcon,
    GlSingleStat,
  },
  props: {
    monthlyUsage: {
      type: Number,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>
<template>
  <div>
    <h2 class="gl-heading-3 gl-my-3" data-testid="overview-subtitle">
      {{ __('Hosted runner usage') }}
    </h2>

    <div class="gl-pb-4">
      <gl-loading-icon v-if="loading" />
      <gl-single-stat
        v-else
        :title="__('Usage this month')"
        :value="monthlyUsage"
        :unit="__('minutes')"
        data-testid="hosted-runner-monthly-usage"
      />
    </div>
  </div>
</template>
