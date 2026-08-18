<script>
import { GlAlert, GlSkeletonLoader } from '@gitlab/ui';
import { s__ } from '~/locale';
import ArtifactsEmptyState from './artifacts_empty_state.vue';
import ArtifactsTable from './artifacts_table.vue';

export default {
  name: 'ArtifactRegistryArtifactsSection',
  components: {
    ArtifactsEmptyState,
    ArtifactsTable,
    GlAlert,
    GlSkeletonLoader,
  },
  props: {
    name: {
      type: String,
      required: true,
    },
    format: {
      type: String,
      required: true,
    },
    artifacts: {
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
  <gl-skeleton-loader v-if="loading" :lines="3" data-testid="artifacts-skeleton" />

  <gl-alert
    v-else-if="hasError"
    variant="danger"
    :dismissible="false"
    data-testid="artifacts-error"
  >
    {{ $options.i18n.unavailable }}
  </gl-alert>

  <artifacts-empty-state v-else-if="!artifacts.length" :name="name" :format="format" />

  <artifacts-table v-else :artifacts="artifacts" :format="format" :name="name" />
</template>
