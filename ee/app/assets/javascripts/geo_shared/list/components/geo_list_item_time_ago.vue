<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'GeoListItemTimeAgo',
  i18n: {
    timeAgoString: s__('Geo|%{label} %{timeAgo}'),
  },
  components: {
    TimeAgo,
    GlSprintf,
  },
  props: {
    label: {
      type: String,
      required: true,
    },
    defaultText: {
      type: String,
      required: true,
    },
    dateString: {
      type: String,
      required: false,
      default: '',
    },
    showDivider: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>

<template>
  <div class="gl-text-sm gl-text-subtle">
    <span class="gl-px-1" data-testid="date-string">
      <gl-sprintf :message="$options.i18n.timeAgoString">
        <template #label>
          <span>{{ label }}</span>
        </template>
        <template #timeAgo>
          <time-ago v-if="dateString" :time="dateString" tooltip-placement="top" />
          <span v-else>{{ defaultText }}</span>
        </template>
      </gl-sprintf>
    </span>
    <span v-if="showDivider" class="gl-mr-1" data-testid="divider">·</span>
  </div>
</template>
