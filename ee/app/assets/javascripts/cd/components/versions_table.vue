<script>
import { GlTable, GlTruncate } from '@gitlab/ui';
import { s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'VersionsTable',
  components: {
    GlTable,
    GlTruncate,
    TimeAgo,
  },
  props: {
    versions: {
      type: Array,
      required: true,
    },
  },
  computed: {
    fields() {
      return [
        { key: 'name', label: s__('ContinuousDeployment|Version') },
        { key: 'digest', label: s__('ContinuousDeployment|Digest') },
        { key: 'createdAt', label: s__('ContinuousDeployment|Created') },
      ];
    },
  },
};
</script>

<template>
  <gl-table
    :items="versions"
    :fields="fields"
    stacked="sm"
    small
    borderless
    fixed
    :empty-text="s__('ContinuousDeployment|No versions recorded.')"
    show-empty
    class="gl-text-sm"
    data-testid="versions-table"
  >
    <template #cell(digest)="{ value }">
      <gl-truncate :text="value || ''" position="middle" class="gl-font-monospace gl-text-sm" />
    </template>
    <template #cell(createdAt)="{ value }">
      <time-ago v-if="value" :time="value" />
    </template>
  </gl-table>
</template>
