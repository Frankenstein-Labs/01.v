<script>
import { GlTable } from '@gitlab/ui';
import {
  ARTIFACTS_TABLE_FIELDS,
  ARTIFACT_VERSIONS_ROUTE_NAME,
} from 'ee/packages_and_registries/artifact_registry/constants';
import { artifactDisplayName } from 'ee/packages_and_registries/artifact_registry/utils';
import { formatNumber } from '~/locale';

export default {
  name: 'ArtifactRegistryArtifactsTable',
  components: {
    GlTable,
  },
  props: {
    artifacts: {
      type: Array,
      required: true,
    },
    format: {
      type: String,
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
  },
  computed: {
    fields() {
      return ARTIFACTS_TABLE_FIELDS[this.format] ?? [];
    },
  },
  methods: {
    artifactName(artifact) {
      return artifactDisplayName(artifact, this.format);
    },
    versionsRoute(artifact) {
      return {
        name: ARTIFACT_VERSIONS_ROUTE_NAME,
        params: { id: this.name, artifactId: artifact.id },
      };
    },
    versions(versionsCount) {
      return formatNumber(versionsCount ?? 0);
    },
  },
};
</script>

<template>
  <gl-table :fields="fields" :items="artifacts" stacked="md">
    <template #cell(name)="{ item }">
      <router-link :to="versionsRoute(item)" class="gl-wrap-anywhere" data-testid="artifact-name">{{
        artifactName(item)
      }}</router-link>
    </template>

    <template #cell(versionsCount)="{ item }">
      <span data-testid="artifact-versions">{{ versions(item.versionsCount) }}</span>
    </template>
  </gl-table>
</template>
