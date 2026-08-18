<script>
import IssueCardTimeInfo from '~/work_items/list/components/issue_card_time_info.vue';
import IssueHealthStatus from 'ee/issues/components/issue_health_status.vue';
import WorkItemIterationAttribute from 'ee/work_items/components/shared/work_item_iteration_attribute.vue';
import { findHealthStatusWidget, findWeightWidget, findIterationWidget } from '~/work_items/utils';
import WorkItemAttribute from '~/vue_shared/components/work_item_attribute.vue';
import { METADATA_KEYS } from '~/work_items/constants';

export default {
  name: 'IssueCardTimeInfoEE',
  components: {
    IssueCardTimeInfo,
    IssueHealthStatus,
    WorkItemAttribute,
    WorkItemIterationAttribute,
  },
  inject: ['hasIssuableHealthStatusFeature', 'hasIssueWeightsFeature', 'hasIterationsFeature'],
  props: {
    issue: {
      type: Object,
      required: true,
    },
    isWorkItemList: {
      type: Boolean,
      required: false,
      default: false,
    },
    detailLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    hiddenMetadataKeys: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    issueNamespacePath() {
      return this.issue?.namespace?.fullPath || '';
    },
    healthStatus() {
      return this.issue.healthStatus || findHealthStatusWidget(this.issue)?.healthStatus;
    },
    showHealthStatus() {
      return this.hasIssuableHealthStatusFeature && this.healthStatus && !this.isWorkItemList;
    },
    weight() {
      return this.issue.weight || findWeightWidget(this.issue)?.weight;
    },
    showWeight() {
      return (
        this.hasIssueWeightsFeature &&
        this.weight != null &&
        !this.hiddenMetadataKeys.includes(this.$options.constants.METADATA_KEYS.WEIGHT)
      );
    },
    iteration() {
      return this.hasIterationsFeature && findIterationWidget(this.issue)?.iteration;
    },
  },
  constants: {
    METADATA_KEYS,
  },
};
</script>

<template>
  <issue-card-time-info
    :issue="issue"
    :detail-loading="detailLoading"
    :hidden-metadata-keys="hiddenMetadataKeys"
  >
    <template #weight>
      <work-item-attribute
        v-if="showWeight"
        anchor-id="issuable-weight-content"
        data-testid="issuable-weight-content"
        wrapper-component="button"
        wrapper-component-class="issuable-weight gl-text-subtle gl-bg-transparent gl-border-0 gl-p-0 focus-visible:gl-focus-inset"
        icon-name="weight"
        :icon-size="12"
        :title="`${weight}`"
        :tooltip-text="__('Weight')"
        tooltip-placement="top"
      />
    </template>
    <issue-health-status v-if="showHealthStatus" :health-status="healthStatus" />
    <template #iteration>
      <work-item-iteration-attribute
        v-if="iteration && !hiddenMetadataKeys.includes($options.constants.METADATA_KEYS.ITERATION)"
        :iteration="iteration"
        :namespace-path="issueNamespacePath"
      />
    </template>
  </issue-card-time-info>
</template>
