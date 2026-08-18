<script>
import { GlAlert, GlButton, GlButtonGroup, GlSegmentedControl } from '@gitlab/ui';
import { cloneDeep } from 'lodash-es';
import BurnupQueryIteration from 'shared_queries/burndown_chart/burnup.iteration.query.graphql';
import BurnupQueryMilestone from 'shared_queries/burndown_chart/burnup.milestone.query.graphql';
import { createAlert } from '~/alert';
import { STATUS_CLOSED, NAMESPACE_GROUP } from '~/issues/constants';
import dateFormat from '~/lib/dateformat';
import axios from '~/lib/utils/axios_utils';
import { getDayDifference, nDaysAfter, newDate } from '~/lib/utils/datetime_utility';
import { __ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import BurndownChartData from '../burn_chart_data';
import BurndownChart from './burndown_chart.vue';
import BurnupChart from './burnup_chart.vue';
import OpenTimeboxSummary from './open_timebox_summary.vue';
import TimeboxSummaryCards from './timebox_summary_cards.vue';

export const FILTER_BY_ISSUES = 'issues';
export const FILTER_BY_ISSUE_WEIGHT = 'issue_weight';
export const FILTER_BY_STORAGE_KEY = 'burn_charts_display_by';

export default {
  name: 'BurnCharts',
  filterByStorageKey: FILTER_BY_STORAGE_KEY,
  components: {
    GlAlert,
    GlButton,
    GlButtonGroup,
    GlSegmentedControl,
    BurndownChart,
    BurnupChart,
    LocalStorageSync,
    OpenTimeboxSummary,
    TimeboxSummaryCards,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    startDate: {
      type: String,
      required: true,
    },
    dueDate: {
      type: String,
      required: true,
    },
    milestoneId: {
      type: String,
      required: false,
      default: '',
    },
    iterationId: {
      type: String,
      required: false,
      default: '',
    },
    iterationState: {
      type: String,
      required: false,
      default: '',
    },
    fullPath: {
      type: String,
      required: false,
      default: '',
    },
    namespaceType: {
      type: String,
      required: false,
      default: NAMESPACE_GROUP,
    },
    burndownEventsPath: {
      type: String,
      required: false,
      default: '',
    },
    showNewOldBurndownToggle: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['update-total'],
  apollo: {
    report: {
      skip() {
        return !this.milestoneId && !this.iterationId;
      },
      query() {
        return this.iterationId ? BurnupQueryIteration : BurnupQueryMilestone;
      },
      variables() {
        const fullPath = this.isIterationReport ? { fullPath: this.fullPath } : {};

        return {
          iterationId: this.iterationId,
          milestoneId: this.milestoneId,
          weight: !this.issuesSelected,
          ...fullPath,
        };
      },
      update(data) {
        const sparseBurnupData = data[this.parent]?.report.burnupTimeSeries || [];
        const stats = data[this.parent]?.report?.stats || {};

        return {
          burnupData: this.padSparseBurnupData(sparseBurnupData),
          stats: {
            complete: stats.complete?.[this.displayValue] || 0,
            incomplete: stats.incomplete?.[this.displayValue] || 0,
            total: stats.total?.[this.displayValue] || 0,
          },
        };
      },
      result({ data }) {
        const total = data?.[this.parent]?.report?.stats?.total?.[this.displayValue] || 0;
        this.$emit('update-total', total);
      },
      error() {
        this.error = __('Error fetching burnup chart data');
      },
    },
  },
  data() {
    return {
      openIssuesCount: [],
      openIssuesWeight: [],
      issuesSelected: true,
      report: {
        burnupData: [],
        stats: {
          complete: 0,
          incomplete: 0,
          total: 0,
        },
      },
      useLegacyBurndown: false,
      error: '',
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.report.loading;
    },
    burnupData() {
      return this.report.burnupData;
    },
    isIterationReport() {
      return this.iterationId && !this.milestoneId;
    },
    columns() {
      return [
        {
          title: __('Completed'),
          value: this.report.stats.complete,
        },
        {
          title: __('Incomplete'),
          value: this.report.stats.incomplete,
        },
      ];
    },
    displayValue() {
      return this.issuesSelected ? 'count' : 'weight';
    },
    isClosed() {
      return this.iterationState === STATUS_CLOSED;
    },
    parent() {
      return this.iterationId ? 'iteration' : 'milestone';
    },
    issuesCount() {
      if (this.useLegacyBurndown) {
        return this.openIssuesCount;
      }
      return this.pluckBurnupDataProperties('scopeCount', 'completedCount');
    },
    issuesWeight() {
      if (this.useLegacyBurndown) {
        return this.openIssuesWeight;
      }
      return this.pluckBurnupDataProperties('scopeWeight', 'completedWeight');
    },
    filterBySelectedValue() {
      return this.issuesSelected ? FILTER_BY_ISSUES : FILTER_BY_ISSUE_WEIGHT;
    },
    filterByOptions() {
      return [
        {
          value: FILTER_BY_ISSUES,
          text: __('Count'),
          props: { 'data-testid': 'issue-button' },
        },
        {
          value: FILTER_BY_ISSUE_WEIGHT,
          text: __('Weight'),
          props: { 'data-testid': 'weight-button' },
        },
      ];
    },
  },
  methods: {
    fetchLegacyBurndownEvents() {
      this.fetchedLegacyData = true;

      axios
        .get(this.burndownEventsPath)
        .then((burndownResponse) => {
          const burndownEvents = burndownResponse.data;
          const burndownChartData = new BurndownChartData(
            burndownEvents,
            this.startDate,
            this.dueDate,
          ).generateBurndownTimeseries();

          this.openIssuesCount = burndownChartData.map((d) => [d[0], d[1]]);
          this.openIssuesWeight = burndownChartData.map((d) => [d[0], d[2]]);
        })
        .catch(() => {
          this.fetchedLegacyData = false;
          createAlert({
            message: __('Error loading burndown chart data'),
          });
        });
    },
    pluckBurnupDataProperties(total, completed) {
      return this.burnupData.map((data) => {
        return [data.date, data[total] - data[completed]];
      });
    },
    toggleLegacyBurndown(enabled) {
      if (!this.fetchedLegacyData) {
        this.fetchLegacyBurndownEvents();
      }
      this.useLegacyBurndown = enabled;
    },
    setIssueSelected(selected) {
      this.issuesSelected = selected;
    },
    padSparseBurnupData(data) {
      // if we don't have data for the startDate, we still want to draw a point at 0
      // on the chart, so add an item to the start of the array
      const sparseBurnupData = cloneDeep(data);
      const hasDataForStartDate = sparseBurnupData.find((d) => d.date === this.startDate);

      if (!hasDataForStartDate) {
        sparseBurnupData.unshift({
          date: this.startDate,
          completedCount: 0,
          completedWeight: 0,
          scopeCount: 0,
          scopeWeight: 0,
        });
      }

      // chart runs to dueDate or the current date, whichever is earlier
      const lastDate = dateFormat(
        Math.min(Date.parse(this.dueDate), Date.parse(new Date())),
        'yyyy-mm-dd',
        true, // use UTC
      );

      // similar to the startDate padding, if we don't have a value for the
      // last item in the array, we should add one. If no events occur on
      // a day then we don't get any data for that day in the response
      const hasDataForLastDate = sparseBurnupData.find((d) => d.date === lastDate);
      if (!hasDataForLastDate) {
        const lastItem = sparseBurnupData[sparseBurnupData.length - 1];
        sparseBurnupData.push({
          ...lastItem,
          date: lastDate,
        });
      }

      return sparseBurnupData.reduce(this.addMissingDates, []);
    },
    addMissingDates(acc, current) {
      const { date } = current;

      // we might not have data for every day in the timebox, as graphql
      // endpoint only returns days when events have happened
      // if the previous array item is >1 day, then fill in the gap
      // using the data from the previous entry.
      // example: [
      //   { date: '2020-08-01', count: 10 }
      //   { date: '2020-08-04', count: 12 }
      // ]
      // should be transformed to
      // example: [
      //   { date: '2020-08-01', count: 10 }
      //   { date: '2020-08-02', count: 10 }
      //   { date: '2020-08-03', count: 10 }
      //   { date: '2020-08-04', count: 12 }
      // ]

      // skip the start date since we have no previous values
      if (date !== this.startDate) {
        const { date: prevDate, ...previousValues } = acc[acc.length - 1] || {};

        const currentDate = newDate(date);
        const previousDate = newDate(prevDate);

        const gap = getDayDifference(previousDate, currentDate);

        for (let i = 1; i < gap; i += 1) {
          acc.push({
            date: dateFormat(nDaysAfter(previousDate, i), 'yyyy-mm-dd'),
            ...previousValues,
          });
        }
      }

      acc.push(current);

      return acc;
    },
    handleFilterByChanged(value) {
      this.setIssueSelected(value !== FILTER_BY_ISSUE_WEIGHT);
    },
  },
};
</script>

<template>
  <div>
    <div class="burndown-header gl-flex gl-flex-wrap gl-items-center gl-gap-2">
      <strong ref="filterLabel">{{ __('Display by') }}</strong>
      <local-storage-sync
        :value="filterBySelectedValue"
        :storage-key="$options.filterByStorageKey"
        @input="handleFilterByChanged"
      />
      <gl-segmented-control
        :value="filterBySelectedValue"
        :options="filterByOptions"
        @input="handleFilterByChanged"
      />

      <gl-button-group v-if="showNewOldBurndownToggle" class="gl-pl-2">
        <gl-button
          ref="newBurndown"
          :selected="!useLegacyBurndown"
          @click="toggleLegacyBurndown(false)"
        >
          {{ __('Fixed burndown chart') }}
        </gl-button>
        <gl-button
          ref="oldBurndown"
          :selected="useLegacyBurndown"
          @click="toggleLegacyBurndown(true)"
        >
          {{ __('Legacy burndown chart') }}
        </gl-button>
      </gl-button-group>
    </div>
    <template v-if="iterationId">
      <timebox-summary-cards
        v-if="isClosed"
        :columns="columns"
        :loading="loading"
        :total="report.stats.total"
      />
      <open-timebox-summary
        v-else
        :full-path="fullPath"
        :iteration-id="iterationId"
        :namespace-type="namespaceType"
        :display-value="displayValue"
      >
        <template #default="{ columns: openColumns, loading: summaryLoading, total }">
          <timebox-summary-cards :columns="openColumns" :loading="summaryLoading" :total="total" />
        </template>
      </open-timebox-summary>
    </template>
    <div class="row">
      <gl-alert v-if="error" variant="danger" class="gl-col-12" @dismiss="error = null">
        {{ error }}
      </gl-alert>
      <burndown-chart
        :start-date="startDate"
        :due-date="dueDate"
        :open-issues-count="issuesCount"
        :open-issues-weight="issuesWeight"
        :issues-selected="issuesSelected"
        :loading="loading"
        class="gl-col-md-6"
      />
      <burnup-chart
        :start-date="startDate"
        :due-date="dueDate"
        :burnup-data="burnupData"
        :issues-selected="issuesSelected"
        :loading="loading"
        class="gl-col-md-6"
      />
    </div>
  </div>
</template>
