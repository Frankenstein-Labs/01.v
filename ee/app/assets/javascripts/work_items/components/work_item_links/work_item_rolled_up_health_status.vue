<script>
import { GlIcon, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  HEALTH_STATUS_AT_RISK,
  HEALTH_STATUS_NEEDS_ATTENTION,
  HEALTH_STATUS_ON_TRACK,
  healthStatusColorMap,
  healthStatusIconMap,
} from 'ee/sidebar/constants';

export default {
  name: 'WorkItemRolledUpHealthStatus',
  components: {
    GlIcon,
    GlPopover,
  },
  i18n: {
    healthStatusLabel: s__('WorkItem|Health status'),
    atRiskLabel: s__('WorkItem|at risk'),
    onTrackLabel: s__('WorkItem|on track'),
    attentionLabel: s__('WorkItem|attention'),
  },
  props: {
    rolledUpHealthStatus: {
      type: Array,
      required: true,
    },
    healthStatusVisible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    rolledUpOnTrackWorkItems() {
      return this.rolledUpHealthStatus?.find(
        (status) => status.healthStatus === HEALTH_STATUS_ON_TRACK,
      );
    },
    rolledUpAtRiskWorkItems() {
      return this.rolledUpHealthStatus?.find(
        (status) => status.healthStatus === HEALTH_STATUS_AT_RISK,
      );
    },
    rolledUpNeedsAttentionWorkItems() {
      return this.rolledUpHealthStatus?.find(
        (status) => status.healthStatus === HEALTH_STATUS_NEEDS_ATTENTION,
      );
    },
    showRolledUpHealthStatus() {
      return (
        this.rolledUpOnTrackWorkItems?.count ||
        this.rolledUpAtRiskWorkItems?.count ||
        this.rolledUpNeedsAttentionWorkItems?.count
      );
    },
  },
  methods: {
    getItemLabel(count) {
      return count === 1 ? s__('WorkItem|item') : s__('WorkItem|items');
    },
    getNeedLabel(count) {
      return count === 1 ? s__('WorkItem|needs') : s__('WorkItem|need');
    },
    statusClass(healthStatus) {
      return healthStatusColorMap[healthStatus];
    },
    statusIcon(healthStatus) {
      return healthStatusIconMap[healthStatus];
    },
  },
  HEALTH_STATUS_ON_TRACK,
  HEALTH_STATUS_NEEDS_ATTENTION,
  HEALTH_STATUS_AT_RISK,
};
</script>

<template>
  <div
    v-if="showRolledUpHealthStatus"
    class="gl-ml-3 gl-cursor-default"
    data-testid="rolled-up-health-status-wrapper"
  >
    <span
      ref="healthStatusRollUp"
      tabindex="0"
      class="gl-flex gl-gap-3 gl-text-sm gl-font-normal gl-text-subtle"
    >
      <span class="gl-inline-flex gl-gap-1" data-testid="on-track-count">
        <gl-icon
          :name="statusIcon($options.HEALTH_STATUS_ON_TRACK)"
          :class="{ [statusClass($options.HEALTH_STATUS_ON_TRACK)]: true, 'gl-mr-1': true }"
          :size="16"
        />
        <span>{{ rolledUpOnTrackWorkItems.count }}</span>
      </span>
      <span class="gl-inline-flex gl-gap-1" data-testid="needs-attention-count">
        <gl-icon
          :name="statusIcon($options.HEALTH_STATUS_NEEDS_ATTENTION)"
          :class="{ [statusClass($options.HEALTH_STATUS_NEEDS_ATTENTION)]: true, 'gl-mr-1': true }"
          :size="16"
        />
        {{ rolledUpNeedsAttentionWorkItems.count }}
      </span>
      <span class="gl-inline-flex gl-gap-1" data-testid="at-risk-count">
        <gl-icon
          :name="statusIcon($options.HEALTH_STATUS_AT_RISK)"
          :class="{ [statusClass($options.HEALTH_STATUS_AT_RISK)]: true, 'gl-mr-1': true }"
          :size="16"
        />
        {{ rolledUpAtRiskWorkItems.count }}
      </span>
      <span v-if="healthStatusVisible" class="gl-gray-50 gl-border-r gl-bg-subtle"></span>
    </span>
    <gl-popover triggers="hover focus" :target="() => $refs.healthStatusRollUp">
      <template #title>
        {{ $options.i18n.healthStatusLabel }}
      </template>
      <div class="gl-mb-2" data-testid="on-track-info">
        <gl-icon
          :name="statusIcon($options.HEALTH_STATUS_ON_TRACK)"
          :class="{ [statusClass($options.HEALTH_STATUS_ON_TRACK)]: true, 'gl-mr-2': true }"
        /><span class="gl-font-bold">{{ rolledUpOnTrackWorkItems.count }}</span>
        {{ getItemLabel(rolledUpOnTrackWorkItems.count) }} {{ $options.i18n.onTrackLabel }} <br />
      </div>

      <div class="gl-mb-2" data-testid="needs-attention-info">
        <gl-icon
          :name="statusIcon($options.HEALTH_STATUS_NEEDS_ATTENTION)"
          :class="{ [statusClass($options.HEALTH_STATUS_NEEDS_ATTENTION)]: true, 'gl-mr-2': true }"
        /><span class="gl-font-bold">{{ rolledUpNeedsAttentionWorkItems.count }}</span>
        {{ getItemLabel(rolledUpNeedsAttentionWorkItems.count) }}
        {{ getNeedLabel(rolledUpNeedsAttentionWorkItems.count) }} {{ $options.i18n.attentionLabel }}
      </div>

      <div data-testid="at-risk-info">
        <gl-icon
          :name="statusIcon($options.HEALTH_STATUS_AT_RISK)"
          :class="{ [statusClass($options.HEALTH_STATUS_AT_RISK)]: true, 'gl-mr-2': true }"
        /><span class="gl-font-bold">{{ rolledUpAtRiskWorkItems.count }}</span>
        {{ getItemLabel(rolledUpAtRiskWorkItems.count) }} {{ $options.i18n.atRiskLabel }}
      </div>
    </gl-popover>
  </div>
</template>
