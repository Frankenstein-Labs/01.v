<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters, mapState } from 'vuex';
import { __ } from '~/locale';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { getTypeOfWorkTopLabels, getTypeOfWorkTasksByType } from 'ee/api/analytics_api';
import {
  getTasksByTypeData,
  checkForDataError,
  throwIfUserForbidden,
  alertErrorIfStatusNotOk,
  transformRawTasksByTypeData,
  toggleSelectedLabel,
} from '../../utils';
import { TASKS_BY_TYPE_SUBJECT_ISSUE } from '../../constants';
import TypeOfWorkCharts from './type_of_work_charts.vue';

export default {
  name: 'TypeOfWorkChartsLoader',
  components: {
    ChartSkeletonLoader,
    TypeOfWorkCharts,
  },
  data() {
    return {
      subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
      isLoadingLabels: false,
      topRankedLabels: [],
      selectedLabels: [],
      isLoadingTasksByType: false,
      tasksByType: [],
      errorMessage: '',
    };
  },
  computed: {
    ...mapState(['namespace', 'createdAfter', 'createdBefore']),
    ...mapGetters(['cycleAnalyticsRequestParams']),
    chartData() {
      const { tasksByType, createdAfter, createdBefore } = this;
      return tasksByType.length
        ? getTasksByTypeData({ data: tasksByType, createdAfter, createdBefore })
        : { groupBy: [], data: [] };
    },
    selectedLabelTitles() {
      return this.selectedLabels.map(({ title }) => title);
    },
    labelParams() {
      const {
        subject,
        cycleAnalyticsRequestParams: {
          project_ids,
          created_after,
          created_before,
          author_username,
          milestone_title,
          assignee_username,
        },
      } = this;
      return {
        project_ids,
        created_after,
        created_before,
        author_username,
        milestone_title,
        assignee_username,
        subject,
      };
    },
    tasksByTypeParams() {
      return {
        ...this.labelParams,
        label_names: this.selectedLabelTitles,
      };
    },
    isLoading() {
      return this.isLoadingLabels || this.isLoadingTasksByType;
    },
  },
  created() {
    this.fetchTopRankedGroupLabels();
  },
  methods: {
    onToggleLabel(value) {
      this.selectedLabels = toggleSelectedLabel({ selectedLabels: this.selectedLabels, value });
      this.fetchTasksByType();
    },
    onSetSubject(value) {
      this.subject = value;
      this.fetchTasksByType();
    },
    fetchTopRankedGroupLabels() {
      this.topRankedLabels = [];
      this.selectedLabels = [];
      this.errorMessage = '';

      this.isLoadingLabels = true;

      return getTypeOfWorkTopLabels(this.namespace.restApiRequestPath, this.labelParams)
        .then(checkForDataError)
        .then(({ data }) => {
          this.topRankedLabels = data.map(convertObjectPropsToCamelCase);
          this.selectedLabels = data.map(convertObjectPropsToCamelCase);

          this.fetchTasksByType();
        })
        .catch((error) => {
          throwIfUserForbidden(error);
          alertErrorIfStatusNotOk({
            error,
            message: __('There was an error fetching the top labels for the selected group'),
          });

          this.errorMessage = error.message;
        })
        .finally(() => {
          this.isLoadingLabels = false;
        });
    },
    fetchTasksByType() {
      // dont request if we have no labels selected
      if (!this.selectedLabels.length) {
        this.tasksByType = [];
        return;
      }

      this.isLoadingTasksByType = true;

      getTypeOfWorkTasksByType(this.namespace.restApiRequestPath, this.tasksByTypeParams)
        .then(checkForDataError)
        .then(({ data }) => {
          this.tasksByType = transformRawTasksByTypeData(data);
        })
        .catch((error) => {
          alertErrorIfStatusNotOk({
            error,
            message: __('There was an error fetching data for the tasks by type chart'),
          });
        })
        .finally(() => {
          this.isLoadingTasksByType = false;
        });
    },
  },
};
</script>
<template>
  <div class="js-tasks-by-type-chart">
    <chart-skeleton-loader v-if="isLoading" class="gl-my-4 gl-py-4" />
    <type-of-work-charts
      v-else
      :subject="subject"
      :chart-data="chartData"
      :selected-label-names="selectedLabelTitles"
      :error-message="errorMessage"
      @toggle-label="onToggleLabel"
      @set-subject="onSetSubject"
    />
  </div>
</template>
