<script>
import { GlIcon } from '@gitlab/ui';

export default {
  name: 'HealthCheckListProbe',
  components: {
    GlIcon,
  },
  props: {
    probe: {
      type: Object,
      required: true,
    },
  },
  computed: {
    probeCSS() {
      return this.probe.success
        ? 'gl-text-feedback-success gl-bg-feedback-success'
        : 'gl-text-feedback-danger gl-bg-feedback-danger';
    },
    probeIcon() {
      return this.probe.success
        ? { name: 'check-circle', variant: 'success' }
        : { name: 'error', variant: 'danger' };
    },
  },
};
</script>

<template>
  <div
    class="gl-my-3 gl-rounded-small gl-px-3 gl-py-2"
    :class="probeCSS"
    data-testid="health-check-probe"
  >
    <gl-icon v-bind="probeIcon" />
    {{ probe.message }}
  </div>
</template>
