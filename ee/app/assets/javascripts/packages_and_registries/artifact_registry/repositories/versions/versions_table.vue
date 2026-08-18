<script>
import { GlTable } from '@gitlab/ui';
import { VERSIONS_TABLE_FIELDS } from 'ee/packages_and_registries/artifact_registry/constants';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'ArtifactRegistryVersionsTable',
  components: {
    GlTable,
    TimeAgoTooltip,
  },
  props: {
    versions: {
      type: Array,
      required: true,
    },
  },
  fields: VERSIONS_TABLE_FIELDS,
};
</script>

<template>
  <gl-table :fields="$options.fields" :items="versions" stacked="md">
    <template #cell(version)="{ item }">
      <span class="gl-wrap-anywhere" data-testid="version-name">{{ item.version }}</span>
    </template>

    <template #cell(createdAt)="{ item }">
      <time-ago-tooltip :time="item.createdAt" data-testid="version-published" />
    </template>
  </gl-table>
</template>
