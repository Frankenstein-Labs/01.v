<script>
import { GlAlert, GlBadge, GlEmptyState, GlFormSelect, GlLabel, GlTab, GlTabs } from '@gitlab/ui';
import { differenceBy, unionBy } from 'lodash-es';
import { NAMESPACE_GROUP, NAMESPACE_PROJECT } from '~/issues/constants';
import { isScopedLabel } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import LabelsSelect from '~/sidebar/components/labels/labels_select_vue/labels_select_root.vue';
import { VARIANT_STANDALONE } from '~/sidebar/components/labels/labels_select_widget/constants';
import { GROUP_BY_LABEL, GROUP_BY_NONE } from '../constants';
import IterationReportIssues from './iteration_report_issues.vue';

export default {
  name: 'IterationReportTabs',
  i18n: {
    emptyStateDescription: __('Try grouping with different labels'),
    emptyStateTitle: __('There are no issues with the selected labels'),
  },
  selectOptions: [
    {
      value: GROUP_BY_NONE,
      text: __('None'),
    },
    {
      value: GROUP_BY_LABEL,
      text: __('Label'),
    },
  ],
  VARIANT_STANDALONE,
  components: {
    GlAlert,
    GlBadge,
    GlEmptyState,
    GlFormSelect,
    GlLabel,
    GlTab,
    GlTabs,
    IterationReportIssues,
    LabelsSelect,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    hasScopedLabelsFeature: {
      type: Boolean,
      required: false,
      default: false,
    },
    iterationId: {
      type: String,
      required: true,
    },
    labelsFetchPath: {
      type: String,
      required: false,
      default: '',
    },
    namespaceType: {
      type: String,
      required: false,
      default: NAMESPACE_GROUP,
      validator: (value) => [NAMESPACE_GROUP, NAMESPACE_PROJECT].includes(value),
    },
    svgPath: {
      type: String,
      required: false,
      default: '',
    },
    totalIterationIssueCount: {
      type: Number,
      required: true,
      default: 0,
    },
  },
  data() {
    return {
      issueCount: undefined,
      groupBySelection: GROUP_BY_NONE,
      selectedLabels: [],
    };
  },
  computed: {
    shouldShowFilterByLabel() {
      return this.groupBySelection === GROUP_BY_LABEL;
    },
    showEmptyState() {
      return this.selectedLabels.length && !this.labelsWithIssues.length;
    },
    labelsWithIssues() {
      return this.selectedLabels.filter((label) => label.hasIssues);
    },
    labelsWithoutIssues() {
      return this.selectedLabels.filter((label) => !label.hasIssues);
    },
    hasInaccessibleIssues() {
      // If issueCount is null or if totalIterationIssueCount is null or 0, we can skip this and return false
      if (this.issueCount !== null && this.totalIterationIssueCount) {
        return this.issueCount < this.totalIterationIssueCount;
      }

      return false;
    },
  },
  methods: {
    handleIssuesUpdate({ count, labelId }) {
      if (!labelId) {
        this.issueCount = count;
        return;
      }

      const index = this.selectedLabels.findIndex((l) => l.id === labelId);

      if (index > -1) {
        const label = this.selectedLabels[index];
        label.hasIssues = Boolean(count);
        const copy = [...this.selectedLabels];
        copy[index] = label;
        this.selectedLabels = copy;
      }
    },
    handleRemoveLabel(labelId) {
      const index = this.selectedLabels.findIndex((l) => l.id === labelId);
      this.selectedLabels.splice(index, 1);
    },
    handleSelectChange() {
      if (this.groupBySelection === GROUP_BY_NONE) {
        this.selectedLabels = [];
      }
    },
    handleUpdateSelectedLabels(selectedLabels) {
      const labels = selectedLabels.map((label) => ({ ...label, hasIssues: true }));
      const labelsToAdd = labels.filter((label) => label.set);
      const labelsToRemove = labels.filter((label) => !label.set);
      const idProperty = 'id';

      this.selectedLabels = unionBy(
        differenceBy(this.selectedLabels, labelsToRemove, idProperty),
        labelsToAdd,
        idProperty,
      );
    },
    shouldShowScopedLabel(label) {
      return this.hasScopedLabelsFeature && isScopedLabel(label);
    },
  },
};
</script>

<template>
  <gl-tabs>
    <gl-tab title="Issues">
      <template #title>
        <h3 class="gl-m-0 gl-text-base">{{ __('Issues') }}</h3>
        <gl-badge class="gl-ml-2" variant="neutral">{{ issueCount }}</gl-badge>
      </template>

      <div class="card gl-flex gl-flex-row gl-flex-wrap gl-bg-subtle gl-px-4">
        <div class="gl-my-3 gl-mr-4">
          <label for="iteration-group-by">{{ __('Group by') }}</label>
          <gl-form-select
            id="iteration-group-by"
            v-model="groupBySelection"
            class="gl-w-auto"
            :options="$options.selectOptions"
            @change="handleSelectChange"
          />
        </div>

        <div v-if="shouldShowFilterByLabel" class="gl-my-3 gl-flex gl-basis-1/2 gl-items-center">
          <label class="gl-mb-0 gl-mr-2 gl-whitespace-nowrap">{{ __('Filter by label') }}</label>
          <labels-select
            :allow-label-create="false"
            allow-label-edit
            allow-multiselect
            :allow-scoped-labels="hasScopedLabelsFeature"
            allow-multiple-scoped-labels
            :labels-fetch-path="labelsFetchPath"
            :selected-labels="selectedLabels"
            :variant="$options.VARIANT_STANDALONE"
            @update-selected-labels="handleUpdateSelectedLabels"
          />
        </div>
      </div>

      <gl-alert v-if="labelsWithoutIssues.length" class="gl-mb-4" :dismissible="false">
        {{ __('Labels with no issues in this iteration:') }}
        <gl-label
          v-for="label in labelsWithoutIssues"
          :key="label.id"
          class="gl-ml-1 gl-align-middle"
          :background-color="label.color"
          :description="label.description"
          :scoped="shouldShowScopedLabel(label)"
          :target="null"
          :title="label.title"
        />
      </gl-alert>

      <gl-empty-state
        v-if="showEmptyState"
        :description="$options.i18n.emptyStateDescription"
        :svg-path="svgPath"
        :svg-height="null"
        :title="$options.i18n.emptyStateTitle"
      />

      <iteration-report-issues
        v-for="label in labelsWithIssues"
        :key="label.id"
        class="gl-mb-6"
        :full-path="fullPath"
        :has-scoped-labels-feature="hasScopedLabelsFeature"
        :has-inaccessible-issues="hasInaccessibleIssues"
        :iteration-id="iterationId"
        :label="label"
        :namespace-type="namespaceType"
        @remove-label="handleRemoveLabel"
        @issues-update="handleIssuesUpdate"
      />

      <iteration-report-issues
        v-show="!selectedLabels.length"
        :full-path="fullPath"
        :has-scoped-labels-feature="hasScopedLabelsFeature"
        :has-inaccessible-issues="hasInaccessibleIssues"
        :iteration-id="iterationId"
        :namespace-type="namespaceType"
        @issues-update="handleIssuesUpdate"
      />
    </gl-tab>
  </gl-tabs>
</template>
