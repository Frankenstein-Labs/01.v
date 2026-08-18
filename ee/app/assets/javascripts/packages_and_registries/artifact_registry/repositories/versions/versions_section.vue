<script>
import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import VersionsTable from './versions_table.vue';

export default {
  name: 'ArtifactRegistryVersionsSection',
  components: {
    GlAlert,
    GlSkeletonLoader,
    VersionsTable,
  },
  props: {
    versions: {
      type: Array,
      required: false,
      default: () => [],
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasError: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  i18n: {
    unavailable: s__('ArtifactRegistry|The Artifact Registry service is unavailable.'),
  },
};
</script>

<template>
  <gl-skeleton-loader v-if="loading" :lines="3" data-testid="versions-skeleton" />

  <gl-alert v-else-if="hasError" variant="danger" :dismissible="false" data-testid="versions-error">
    {{ $options.i18n.unavailable }}
  </gl-alert>

  <versions-table v-else :versions="versions" />
</template>
