<script>
import { GlIcon, GlTooltip, GlTooltipDirective } from '@gitlab/ui';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import IssueHealthStatus from 'ee/issues/components/issue_health_status.vue';
import WorkItemLinkChildMetadata from '~/work_items/components/shared/work_item_link_child_metadata.vue';
import WorkItemRolledUpHealthStatus from 'ee/work_items/components/work_item_links/work_item_rolled_up_health_status.vue';
import WorkItemIterationAttribute from 'ee/work_items/components/shared/work_item_iteration_attribute.vue';
import {
  WIDGET_TYPE_HEALTH_STATUS,
  WIDGET_TYPE_PROGRESS,
  WIDGET_TYPE_WEIGHT,
  WIDGET_TYPE_ITERATION,
  WIDGET_TYPE_START_AND_DUE_DATE,
  METADATA_KEYS,
} from '~/work_items/constants';
import {
  getDueDateStatus,
  humanTimeframe,
  localeDateFormat,
  newDate,
} from '~/lib/utils/datetime_utility';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';

export default {
  name: 'WorkItemLinkChildEE',
  components: {
    GlIcon,
    GlTooltip,
    IssueHealthStatus,
    WorkItemLinkChildMetadata,
    WorkItemRolledUpHealthStatus,
    WorkItemAttribute,
    WorkItemIterationAttribute,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [timeagoMixin, glFeatureFlagsMixin()],
  props: {
    reference: {
      type: String,
      required: true,
    },
    metadataWidgets: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isChildItemOpen: {
      type: Boolean,
      required: false,
      default: true,
    },
    hiddenMetadataKeys: {
      type: Array,
      required: false,
      default: () => [],
    },
    namespacePath: {
      type: String,
      required: true,
    },
  },
  computed: {
    progress() {
      return this.metadataWidgets[WIDGET_TYPE_PROGRESS]?.progress;
    },
    progressLastUpdatedAtInWords() {
      return this.getTimestampInWords(this.metadataWidgets[WIDGET_TYPE_PROGRESS]?.updatedAt);
    },
    progressLastUpdatedAtTimestamp() {
      return this.getTimestamp(this.metadataWidgets[WIDGET_TYPE_PROGRESS]?.updatedAt);
    },
    healthStatus() {
      return this.metadataWidgets[WIDGET_TYPE_HEALTH_STATUS]?.healthStatus;
    },
    rolledUpHealthStatus() {
      return this.metadataWidgets[WIDGET_TYPE_HEALTH_STATUS]?.rolledUpHealthStatus;
    },
    hasProgress() {
      return Number.isInteger(this.progress);
    },
    weight() {
      return this.metadataWidgets[WIDGET_TYPE_WEIGHT]?.weight;
    },
    rolledUpWeight() {
      return this.metadataWidgets[WIDGET_TYPE_WEIGHT]?.rolledUpWeight;
    },
    workItemWeight() {
      return this.rolledUpWeight || this.weight;
    },
    iteration() {
      return this.metadataWidgets[WIDGET_TYPE_ITERATION]?.iteration;
    },
    startDate() {
      return this.metadataWidgets[WIDGET_TYPE_START_AND_DUE_DATE]?.startDate;
    },
    dueDate() {
      return this.metadataWidgets[WIDGET_TYPE_START_AND_DUE_DATE]?.dueDate;
    },
    showDate() {
      return this.startDate || this.dueDate;
    },
    workItemTimeframe() {
      return humanTimeframe(newDate(this.startDate), newDate(this.dueDate));
    },
    dueDateStatus() {
      return getDueDateStatus(this.dueDate, this.isChildItemOpen);
    },
    overdueText() {
      const { statusLabel } = this.dueDateStatus;
      return statusLabel ? ` (${statusLabel})` : '';
    },
    showWeight() {
      return this.workItemWeight && !this.hiddenMetadataKeys.includes(METADATA_KEYS.WEIGHT);
    },
    showIteration() {
      return this.iteration && !this.hiddenMetadataKeys.includes(METADATA_KEYS.ITERATION);
    },
    showDates() {
      return this.showDate && !this.hiddenMetadataKeys.includes(METADATA_KEYS.DATES);
    },
    showHealthStatus() {
      return !this.hiddenMetadataKeys.includes(METADATA_KEYS.HEALTH);
    },
    showRolledUpHealthStatus() {
      return this.rolledUpHealthStatus && this.showHealthStatus;
    },
    showHealthStatusIndicator() {
      return this.healthStatus && this.isChildItemOpen && this.showHealthStatus;
    },
  },
  methods: {
    getTimestamp(rawTimestamp) {
      return rawTimestamp ? localeDateFormat.asDateTimeFull.format(newDate(rawTimestamp)) : '';
    },
    getTimestampInWords(rawTimestamp) {
      return rawTimestamp ? this.timeFormatted(rawTimestamp) : '';
    },
  },
};
</script>

<template>
  <work-item-link-child-metadata
    :reference="reference"
    :metadata-widgets="metadataWidgets"
    :hidden-metadata-keys="hiddenMetadataKeys"
    :namespace-path="namespacePath"
  >
    <template #weight-metadata>
      <work-item-attribute
        v-if="showWeight"
        anchor-id="item-weight"
        wrapper-component="div"
        wrapper-component-class="gl-flex gl-cursor-help gl-items-center gl-gap-2"
        :title="`${workItemWeight}`"
        icon-name="weight"
        tooltip-placement="top"
      >
        <template #tooltip-text>
          <span data-testid="weight-tooltip" class="gl-font-bold">
            {{ __('Weight') }}
          </span>
        </template>
      </work-item-attribute>
    </template>
    <template #left-metadata>
      <work-item-iteration-attribute
        v-if="showIteration"
        :iteration="iteration"
        :namespace-path="namespacePath"
      />
      <work-item-attribute
        v-if="showDates"
        anchor-id="item-dates"
        wrapper-component="div"
        wrapper-component-class="gl-flex gl-min-w-10 gl-max-w-26 gl-cursor-help gl-flex-wrap gl-gap-2"
        :title="workItemTimeframe"
        tooltip-placement="top"
      >
        <template #icon>
          <gl-icon :variant="dueDateStatus.iconVariant" :name="dueDateStatus.iconName" />
        </template>
        <template #tooltip-text>
          <span class="gl-font-bold">{{ __('Dates') }}</span
          ><span>{{ overdueText }}</span>
        </template>
      </work-item-attribute>
      <div
        v-if="hasProgress"
        ref="progressTooltip"
        class="gl-flex gl-min-w-10 gl-max-w-26 gl-cursor-help gl-items-center gl-justify-start gl-gap-2 gl-leading-normal"
        data-testid="item-progress"
      >
        <gl-icon name="progress" />
        <span data-testid="progressValue">{{ progress }}%</span>
        <gl-tooltip :target="() => $refs.progressTooltip">
          <div data-testid="progressTitle" class="gl-font-bold">
            {{ __('Progress') }}
          </div>
          <div v-if="progressLastUpdatedAtInWords" class="gl-text-subtle">
            <span data-testid="progressText" class="gl-font-bold">
              {{ __('Last updated') }}
            </span>
            <span data-testid="lastUpdatedInWords">{{ progressLastUpdatedAtInWords }}</span>
            <div data-testid="lastUpdatedTimestamp">{{ progressLastUpdatedAtTimestamp }}</div>
          </div>
        </gl-tooltip>
      </div>
    </template>
    <template #right-metadata>
      <div class="gl-flex gl-gap-3">
        <work-item-rolled-up-health-status
          v-if="showRolledUpHealthStatus"
          :rolled-up-health-status="rolledUpHealthStatus"
          :health-status-visible="showHealthStatusIndicator"
        />
        <issue-health-status
          v-if="showHealthStatusIndicator"
          class="gl-text-nowrap"
          display-as-text
          text-size="sm"
          :health-status="healthStatus"
        />
      </div>
    </template>
  </work-item-link-child-metadata>
</template>
