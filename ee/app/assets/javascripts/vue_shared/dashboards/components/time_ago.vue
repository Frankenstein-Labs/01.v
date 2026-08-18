<script>
import { GlTooltip, GlIcon } from '@gitlab/ui';
import timeagoMixin from '~/vue_shared/mixins/timeago';

export default {
  name: 'TimeAgo',
  components: {
    GlTooltip,
    GlIcon,
  },

  mixins: [timeagoMixin],

  props: {
    time: {
      type: String,
      required: true,
    },
    tooltipText: {
      type: String,
      required: true,
    },
  },
  computed: {
    timeTitle() {
      return this.tooltipTitle(this.time);
    },
    formattedTime() {
      return this.timeFormatted(this.time);
    },
  },
};
</script>
<template>
  <div class="gl-text-subtle">
    <gl-icon name="clock" :size="12" class="js-dashboard-project-clock-icon" variant="subtle" />

    <time ref="timeAgo" class="js-dashboard-project-time-ago">
      {{ formattedTime }}
    </time>
    <gl-tooltip :target="() => $refs.timeAgo">
      <div class="gl-font-bold">{{ tooltipText }}</div>
      <div>{{ timeTitle }}</div>
    </gl-tooltip>
  </div>
</template>
