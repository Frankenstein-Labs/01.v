<script>
import VersionsTable from './versions_table.vue';

export default {
  name: 'ArtifactSourceCard',
  components: {
    VersionsTable,
  },
  props: {
    artifactSource: {
      type: Object,
      required: true,
    },
  },
  computed: {
    sourceRef() {
      return this.artifactSource.sourceRef ?? '';
    },
    versions() {
      return this.artifactSource.versions?.nodes ?? [];
    },
  },
};
</script>

<template>
  <div class="gl-border gl-rounded-lg gl-border-default gl-p-4" data-testid="artifact-source-card">
    <p
      class="gl-mb-2 gl-text-xs gl-font-bold gl-uppercase gl-text-secondary"
      data-testid="artifact-source-title"
    >
      {{ s__('ContinuousDeployment|Artifact source') }}
    </p>
    <span v-if="sourceRef" class="gl-font-monospace gl-text-sm" data-testid="artifact-source-ref">
      {{ sourceRef }}
    </span>
    <versions-table :versions="versions" class="gl-mt-3" />
  </div>
</template>
