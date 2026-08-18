<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'RunnerDashboardLink',
  components: {
    GlButton,
  },
  inject: {
    runnerDashboardPath: {
      default: null,
    },
  },
};
</script>
<template>
  <gl-button v-if="runnerDashboardPath" variant="link" :href="runnerDashboardPath" class="gl-mr-2">
    {{ s__('Runners|Fleet dashboard') }}
  </gl-button>
</template>
