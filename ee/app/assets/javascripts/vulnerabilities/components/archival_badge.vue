<script>
import { GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';

export default {
  name: 'ArchivalBadge',
  components: {
    GlBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    expectedDate: {
      type: String,
      required: true,
    },
  },
  computed: {
    popoverContent() {
      return sprintf(s__('SecurityReports|Vulnerability will be archived on %{date}'), {
        date: this.expectedDate,
      });
    },
  },
};
</script>

<template>
  <gl-badge
    v-gl-tooltip
    variant="warning"
    icon="archive"
    :title="popoverContent"
    :aria-label="popoverContent"
  />
</template>
