<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters, mapState } from 'vuex';
import { GlAlert, GlIcon, GlTooltip } from '@gitlab/ui';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { generateFilterTextDescription } from '../../utils';
import { formattedDate } from '../../../shared/utils';
import { TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS, TASKS_BY_TYPE_SUBJECT_ISSUE } from '../../constants';
import NoDataAvailableState from '../no_data_available_state.vue';
import TasksByTypeChart from './chart.vue';
import TasksByTypeFilters from './filters.vue';

export default {
  name: 'TypeOfWorkCharts',
  components: {
    GlAlert,
    GlIcon,
    GlTooltip,
    TasksByTypeChart,
    TasksByTypeFilters,
    NoDataAvailableState,
  },
  directives: {
    SafeHtml,
  },
  props: {
    chartData: {
      type: Object,
      required: true,
    },
    selectedLabelNames: {
      type: Array,
      required: false,
      default: () => [],
    },
    subject: {
      type: String,
      required: false,
      default: TASKS_BY_TYPE_SUBJECT_ISSUE,
    },
    errorMessage: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['set-subject', 'toggle-label'],
  computed: {
    ...mapState(['namespace', 'createdAfter', 'createdBefore']),
    ...mapGetters(['selectedProjectIds']),
    hasData() {
      return Boolean(this.chartData?.data.length);
    },
    tooltipText() {
      return generateFilterTextDescription({
        groupName: this.namespace.name,
        selectedLabelsCount: this.selectedLabelNames.length,
        selectedProjectsCount: this.selectedProjectIds.length,
        selectedSubjectFilterText: this.selectedSubjectFilterText.toLowerCase(),
        createdAfter: formattedDate(this.createdAfter),
        createdBefore: formattedDate(this.createdBefore),
      });
    },
    selectedSubjectFilterText() {
      return TASKS_BY_TYPE_SUBJECT_FILTER_OPTIONS[this.subject];
    },
  },
};
</script>
<template>
  <div>
    <div class="gl-flex gl-justify-between">
      <h4 class="gl-mt-0">
        {{ s__('ValueStreamAnalytics|Tasks by type') }}&nbsp;
        <span ref="tooltipTrigger" data-testid="vsa-task-by-type-description">
          <gl-icon name="information-o" />
        </span>
        <gl-tooltip :target="() => $refs.tooltipTrigger" boundary="viewport" placement="top">
          <span v-safe-html="tooltipText"></span>
        </gl-tooltip>
      </h4>
      <tasks-by-type-filters
        :selected-label-names="selectedLabelNames"
        :subject-filter="subject"
        @toggle-label="$emit('toggle-label', $event)"
        @set-subject="$emit('set-subject', $event)"
      />
    </div>
    <tasks-by-type-chart v-if="hasData" :data="chartData.data" :group-by="chartData.groupBy" />
    <gl-alert v-else-if="errorMessage" variant="info" :dismissible="false" class="gl-mt-3">
      {{ errorMessage }}
    </gl-alert>
    <no-data-available-state v-else />
  </div>
</template>
