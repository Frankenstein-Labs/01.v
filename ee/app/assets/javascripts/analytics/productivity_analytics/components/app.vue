<script>
import {
  GlEmptyState,
  GlLoadingIcon,
  GlCollapsibleListbox,
  GlButton,
  GlTooltipDirective,
  GlIcon,
  GlAlert,
} from '@gitlab/ui';
import { GlColumnChart } from '@gitlab/ui/src/charts';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions, mapGetters } from 'vuex';
import { dateFormats } from '~/analytics/shared/constants';
import { getDataZoomOption } from '~/analytics/shared/utils';
import dateFormat from '~/lib/dateformat';
import { beginOfDayTime, endOfDayTime } from '~/lib/utils/datetime_utility';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import featureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import Scatterplot from '../../shared/components/scatterplot.vue';
import {
  chartKeys,
  defaultMaxColumnChartItemsPerPage,
  maxColumnChartItemsPerPage,
} from '../constants';
import MetricChart from './metric_chart.vue';
import MergeRequestTable from './mr_table.vue';

export default {
  name: 'ProductivityAnalyticsApp',
  components: {
    GlEmptyState,
    GlLoadingIcon,
    GlCollapsibleListbox,
    GlColumnChart,
    GlButton,
    GlIcon,
    GlAlert,
    MetricChart,
    Scatterplot,
    MergeRequestTable,
    UrlSync,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [featureFlagsMixin()],
  expose: ['fetchChartData'],
  props: {
    emptyStateSvgPath: {
      type: String,
      required: true,
    },
    noAccessSvgPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      chartKeys,
    };
  },
  computed: {
    ...mapState('filters', [
      'groupNamespace',
      'projectPath',
      'authorUsername',
      'labelName',
      'milestoneTitle',
      'startDate',
      'endDate',
      'notMilestoneTitle',
      'notAuthorUsername',
      'notLabelName',
    ]),
    ...mapState('table', [
      'isLoadingTable',
      'mergeRequests',
      'pageInfo',
      'columnMetric',
      'sortField',
    ]),
    ...mapGetters(['getMetricTypes']),
    ...mapGetters('charts', [
      'chartLoading',
      'chartErrorCode',
      'chartHasData',
      'getColumnChartData',
      'getScatterPlotMainData',
      'getScatterPlotMedianData',
      'getMetricLabel',
      'getSelectedMetric',
      'scatterplotYaxisLabel',
      'hasNoAccessError',
      'isChartEnabled',
      'isFilteringByDaysToMerge',
    ]),
    ...mapGetters('table', [
      'sortFieldDropdownLabel',
      'sortIcon',
      'sortTooltipTitle',
      'tableSortOptions',
      'columnMetricLabel',
    ]),
    tableSortOptionsListBoxItems() {
      return this.tableSortOptions?.map(({ key, label }) => ({ value: key, text: label })) || [];
    },
    showAppContent() {
      return this.groupNamespace && !this.hasNoAccessError;
    },
    showMergeRequestTable() {
      return !this.isLoadingTable && this.mergeRequests.length;
    },
    showMergeRequestTableNoData() {
      return !this.isLoadingTable && !this.mergeRequests.length;
    },
    showSecondaryCharts() {
      return !this.chartLoading(chartKeys.main) && this.chartHasData(chartKeys.main);
    },
    query() {
      return {
        group_id: this.groupNamespace,
        project_id: this.projectPath,
        author_username: this.authorUsername,
        'label_name[]': this.labelName,
        milestone_title: this.milestoneTitle,
        merged_after: `${dateFormat(this.startDate, dateFormats.isoDate)}${beginOfDayTime}`,
        merged_before: `${dateFormat(this.endDate, dateFormats.isoDate)}${endOfDayTime}`,
        'not[author_username]': this.notAuthorUsername,
        'not[milestone_title]': this.notMilestoneTitle,
        'not[label_name][]': this.notLabelName,
      };
    },
  },
  methods: {
    ...mapActions('charts', [
      'fetchChartData',
      'setMetricType',
      'updateSelectedItems',
      'resetMainChartSelection',
    ]),
    ...mapActions('table', ['setSortField', 'setPage', 'toggleSortOrder', 'setColumnMetric']),
    onMainChartItemClicked({ params }) {
      const itemValue = params.data.value[0];
      this.updateSelectedItems({ chartKey: this.chartKeys.main, item: itemValue });
    },
    getColumnChartOption(chartKey) {
      const totalItems = this.getColumnChartData(chartKey).length;
      const maxItemsPerPage = maxColumnChartItemsPerPage[chartKey]
        ? maxColumnChartItemsPerPage[chartKey]
        : defaultMaxColumnChartItemsPerPage;
      return {
        yAxis: {
          axisLabel: {
            formatter: (value) => value,
          },
          minInterval: 1,
        },
        ...getDataZoomOption({ totalItems, maxItemsPerPage }),
      };
    },
  },
};
</script>

<template>
  <div>
    <gl-empty-state
      v-if="!groupNamespace"
      class="js-empty-state"
      :title="
        __('Productivity analytics can help identify the problems that are delaying your team')
      "
      :svg-path="emptyStateSvgPath"
      :description="
        __(
          'Start by choosing a group to start exploring the merge requests in that group. You can then proceed to filter by projects, labels, milestones and authors.',
        )
      "
    />
    <gl-empty-state
      v-if="hasNoAccessError"
      class="js-empty-state"
      :title="__('You don’t have access to Productivity Analytics in this group')"
      :svg-path="noAccessSvgPath"
      :description="
        __(
          'Only ‘Reporter’ roles and above on tiers Premium and above can see Productivity Analytics.',
        )
      "
    />
    <template v-if="showAppContent">
      <div class="gl-flex !gl-justify-between">
        <h4>{{ s__('ProductivityAnalytics|Merge Requests') }}</h4>
        <gl-button
          v-if="isFilteringByDaysToMerge"
          ref="clearChartFiltersBtn"
          class="btn-link gl-float-right"
          type="button"
          variant="default"
          @click="resetMainChartSelection()"
          >{{ __('Clear chart filters') }}</gl-button
        >
      </div>
      <metric-chart
        ref="mainChart"
        class="!gl-mb-6"
        :title="s__('ProductivityAnalytics|Time to merge')"
        :description="
          __('You can filter by \'days to merge\' by clicking on the columns in the chart.')
        "
        :is-loading="chartLoading(chartKeys.main)"
        :error-code="chartErrorCode(chartKeys.main)"
        :chart-data="getColumnChartData(chartKeys.main)"
      >
        <gl-column-chart
          :bars="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ [
            { name: 'full', data: getColumnChartData(chartKeys.main) },
          ] /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
          :option="getColumnChartOption(chartKeys.main)"
          :y-axis-title="__('Merge requests')"
          :x-axis-title="__('Days')"
          x-axis-type="category"
          @chartItemClicked="onMainChartItemClicked"
        />
      </metric-chart>

      <template v-if="showSecondaryCharts">
        <div ref="secondaryCharts">
          <metric-chart
            v-if="isChartEnabled(chartKeys.scatterplot)"
            ref="scatterplot"
            class="!gl-mb-6"
            :title="s__('ProductivityAnalytics|Trendline')"
            :is-loading="chartLoading(chartKeys.scatterplot)"
            :metric-types="getMetricTypes(chartKeys.scatterplot)"
            :chart-data="getScatterPlotMainData"
            :selected-metric="getSelectedMetric(chartKeys.scatterplot)"
            @metric-type-change="
              (metric) => setMetricType({ metricType: metric, chartKey: chartKeys.scatterplot })
            "
          >
            <scatterplot
              :x-axis-title="s__('ProductivityAnalytics|Merge date')"
              :y-axis-title="scatterplotYaxisLabel"
              :scatter-data="getScatterPlotMainData"
              :median-line-data="getScatterPlotMedianData"
            />
          </metric-chart>

          <div class="row">
            <metric-chart
              ref="timeBasedChart"
              class="gl-col-lg-6 gl-col-sm-12 !gl-mb-6"
              :description="
                __(
                  'Not all data has been processed yet, the accuracy of the chart for the selected timeframe is limited.',
                )
              "
              :is-loading="chartLoading(chartKeys.timeBasedHistogram)"
              :metric-types="getMetricTypes(chartKeys.timeBasedHistogram)"
              :selected-metric="getSelectedMetric(chartKeys.timeBasedHistogram)"
              :chart-data="getColumnChartData(chartKeys.timeBasedHistogram)"
              @metric-type-change="
                (metric) =>
                  setMetricType({ metricType: metric, chartKey: chartKeys.timeBasedHistogram })
              "
            >
              <gl-column-chart
                :bars="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ [
                  { name: 'full', data: getColumnChartData(chartKeys.timeBasedHistogram) },
                ] /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
                :option="getColumnChartOption(chartKeys.timeBasedHistogram)"
                :y-axis-title="s__('ProductivityAnalytics|Merge requests')"
                :x-axis-title="s__('ProductivityAnalytics|Hours')"
                x-axis-type="category"
              />
            </metric-chart>

            <metric-chart
              ref="commitBasedChart"
              class="gl-col-lg-6 gl-col-sm-12 !gl-mb-6"
              :description="
                __(
                  'Not all data has been processed yet, the accuracy of the chart for the selected timeframe is limited.',
                )
              "
              :is-loading="chartLoading(chartKeys.commitBasedHistogram)"
              :metric-types="getMetricTypes(chartKeys.commitBasedHistogram)"
              :selected-metric="getSelectedMetric(chartKeys.commitBasedHistogram)"
              :chart-data="getColumnChartData(chartKeys.commitBasedHistogram)"
              @metric-type-change="
                (metric) =>
                  setMetricType({ metricType: metric, chartKey: chartKeys.commitBasedHistogram })
              "
            >
              <gl-column-chart
                :bars="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ [
                  { name: 'full', data: getColumnChartData(chartKeys.commitBasedHistogram) },
                ] /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
                :option="getColumnChartOption(chartKeys.commitBasedHistogram)"
                :y-axis-title="s__('ProductivityAanalytics|Merge requests')"
                :x-axis-title="getMetricLabel(chartKeys.commitBasedHistogram)"
                x-axis-type="category"
              />
            </metric-chart>
          </div>

          <div
            class="js-mr-table-sort !gl-mb-3 gl-flex !gl-flex-col !gl-justify-between @md/panel:!gl-flex-row @md/panel:!gl-items-center"
          >
            <h5>{{ s__('ProductivityAnalytics|List') }}</h5>
            <div
              v-if="showMergeRequestTable"
              class="gl-flex !gl-flex-col @md/panel:!gl-flex-row @md/panel:!gl-items-center"
            >
              <strong class="gl-mr-3">{{ __('Sort by') }}</strong>
              <div class="gl-flex">
                <gl-collapsible-listbox
                  block
                  class="gl-mr-3 gl-grow"
                  fluid-width
                  is-check-centered
                  placement="bottom-end"
                  toggle-class="dropdown-menu-toggle"
                  :selected="sortField"
                  :toggle-text="sortFieldDropdownLabel"
                  :items="tableSortOptionsListBoxItems"
                  @select="setSortField"
                />
                <gl-button
                  v-gl-tooltip.hover
                  :title="sortTooltipTitle"
                  :aria-label="sortTooltipTitle"
                  @click="toggleSortOrder"
                >
                  <gl-icon :name="sortIcon" />
                </gl-button>
              </div>
            </div>
          </div>
        </div>

        <div class="js-mr-table">
          <gl-loading-icon v-if="isLoadingTable" size="lg" class="!gl-my-6 !gl-py-6" />
          <merge-request-table
            v-if="showMergeRequestTable"
            :merge-requests="mergeRequests"
            :page-info="pageInfo"
            :column-options="getMetricTypes(chartKeys.timeBasedHistogram)"
            :metric-type="columnMetric"
            :metric-label="columnMetricLabel"
            @column-metric-change="setColumnMetric"
            @page-change="setPage"
          />
          <gl-alert v-if="showMergeRequestTableNoData" variant="info" :dismissible="false">
            {{ __('There is no data available. Please change your selection.') }}
          </gl-alert>
        </div>
      </template>
    </template>
    <url-sync :query="query" url-params-update-strategy="set" />
  </div>
</template>
