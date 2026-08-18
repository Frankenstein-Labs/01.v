<script>
import { GlIcon } from '@gitlab/ui';
import { n__ } from '~/locale';

export default {
  name: 'DashboardsAlerts',
  components: {
    GlIcon,
  },
  props: {
    count: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    alertClasses() {
      return {
        'gl-text-danger': this.count > 0,
      };
    },
    alertCount() {
      return n__('%d Alert', '%d Alerts', this.count);
    },
  },
};
</script>

<template>
  <div>
    <gl-icon
      :class="alertClasses"
      class="js-dashboard-alerts-icon"
      name="warning"
      variant="subtle"
    />
    <span class="js-alert-count gl-text-subtle"> {{ alertCount }} </span>
  </div>
</template>
