<script>
import { GlIcon } from '@gitlab/ui';
import {
  formattedCount,
  humanSize,
  isContainerFormat,
  toCount,
} from 'ee/packages_and_registries/artifact_registry/utils';
import { localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { n__, s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import AttributedTimestamp from './attributed_timestamp.vue';

export default {
  name: 'ArtifactRegistryRepositorySidebar',
  components: {
    AttributedTimestamp,
    GlIcon,
    TimeAgoTooltip,
  },
  props: {
    repository: {
      type: Object,
      required: true,
    },
    hideStats: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    stats() {
      const { sizeBytes, downloadsCount, artifactsCount } = this.repository;

      return [
        {
          icon: 'archive',
          value: humanSize(sizeBytes),
          label: this.$options.i18n.size,
          testId: 'repository-stat-size',
        },
        {
          icon: 'download',
          value: formattedCount(downloadsCount),
          label: this.downloadsLabel,
          testId: 'repository-stat-downloads',
        },
        {
          icon: 'package',
          value: formattedCount(artifactsCount),
          label: this.artifactsLabel,
          testId: 'repository-stat-artifacts',
        },
      ];
    },
    downloadsLabel() {
      return n__(
        'ArtifactRegistry|Download',
        'ArtifactRegistry|Downloads',
        toCount(this.repository.downloadsCount),
      );
    },
    artifactsLabel() {
      const count = toCount(this.repository.artifactsCount);

      return isContainerFormat(this.repository.format)
        ? n__('ArtifactRegistry|Image', 'ArtifactRegistry|Images', count)
        : n__('ArtifactRegistry|Package', 'ArtifactRegistry|Packages', count);
    },
    createdDate() {
      return localeDateFormat.asDate.format(newDate(this.repository.createdAt));
    },
    hasLastUpdate() {
      return Boolean(this.repository.lastUpdatedAt);
    },
  },
  i18n: {
    size: s__('ArtifactRegistry|Size'),
    createdOn: s__('ArtifactRegistry|Created on'),
    lastUpdated: s__('ArtifactRegistry|Last updated'),
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-4 gl-text-sm">
    <div v-if="!hideStats" class="gl-flex gl-flex-col gl-gap-2" data-testid="repository-stats">
      <div
        v-for="stat in stats"
        :key="stat.testId"
        class="gl-flex gl-items-center gl-gap-3"
        :data-testid="stat.testId"
      >
        <gl-icon :name="stat.icon" variant="subtle" />
        <span class="gl-font-bold">{{ stat.value }}</span>
        <span class="gl-text-subtle">{{ stat.label }}</span>
      </div>
    </div>

    <attributed-timestamp
      :title="$options.i18n.createdOn"
      :user="repository.createdBy"
      data-testid="repository-created"
    >
      {{ createdDate }}
    </attributed-timestamp>

    <attributed-timestamp
      v-if="hasLastUpdate"
      :title="$options.i18n.lastUpdated"
      :user="repository.updatedBy"
      data-testid="repository-last-updated"
    >
      <time-ago-tooltip :time="repository.lastUpdatedAt" />
    </attributed-timestamp>
  </div>
</template>
