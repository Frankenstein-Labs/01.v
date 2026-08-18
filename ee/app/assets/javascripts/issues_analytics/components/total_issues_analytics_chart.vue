<script>
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import { GlStackedColumnChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, n__, sprintf, __ } from '~/locale';
import { isValidDate, differenceInMonths } from '~/lib/utils/datetime_utility';
import { generateChartDateRangeData } from '../utils';
import issuesAnalyticsCountsQueryBuilder from '../graphql/issues_analytics_counts_query_builder';
import { extractIssuesAnalyticsCounts } from '../api';
import {
  TOTAL_ISSUES_ANALYTICS_CHART_COLOR_PALETTE,
  NAMESPACE_PROJECT_TYPE,
  NO_DATA_EMPTY_STATE_TYPE,
  NO_DATA_WITH_FILTERS_EMPTY_STATE_TYPE,
  ISSUES_OPENED_COUNT_ALIAS,
  ISSUES_COMPLETED_COUNT_ALIAS,
} from '../constants';
import IssuesAnalyticsEmptyState from './issues_analytics_empty_state.vue';

export default {
  name: 'TotalIssuesAnalyticsChart',
  components: {
    GlLoadingIcon,
    GlStackedColumnChart,
    GlChartSeriesLabel,
    GlAlert,
    IssuesAnalyticsEmptyState,
  },
  inject: {
    fullPath: {
      default: '',
    },
    type: {
      default: '',
    },
  },
  props: {
    startDate: {
      type: Date,
      required: true,
    },
    endDate: {
      type: Date,
      required: true,
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['hide-filtered-search-bar'],
  data() {
    return {
      hasError: false,
      tooltipTitle: null,
      tooltipContent: [],
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    issuesOpenedCounts: {
      query() {
        return this.getIssuesAnalyticsCountsQuery(ISSUES_OPENED_COUNT_ALIAS);
      },
      variables() {
        return this.issuesAnalyticsCountsQueryVariables;
      },
      update(data) {
        return this.getIssuesAnalyticsCountsQueryResponse(data);
      },
      skip() {
        return this.shouldSkipQuery;
      },
      result() {
        if (this.shouldHideFilteredSearchBar) {
          this.$emit('hide-filtered-search-bar');
        }
      },
      error(e) {
        this.handleQueryError(e);
      },
    },
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    issuesClosedCounts: {
      query() {
        return this.getIssuesAnalyticsCountsQuery(ISSUES_COMPLETED_COUNT_ALIAS);
      },
      variables() {
        return this.issuesAnalyticsCountsQueryVariables;
      },
      update(data) {
        return this.getIssuesAnalyticsCountsQueryResponse(data);
      },
      skip() {
        return this.shouldSkipQuery;
      },
      result() {
        if (this.shouldHideFilteredSearchBar) {
          this.$emit('hide-filtered-search-bar');
        }
      },
      error(e) {
        this.handleQueryError(e);
      },
    },
  },
  computed: {
    isProject() {
      return this.type === NAMESPACE_PROJECT_TYPE;
    },
    issuesAnalyticsCountsQueryVariables() {
      const { monthsBack, weight, not, ...filters } = this.filters;
      const parseWeightVal = (val) => Math.round(val) || undefined;

      // queries expect weight filter to be an integer
      if (weight) {
        filters.weight = parseWeightVal(weight);
      }

      if (not?.weight) {
        not.weight = parseWeightVal(not.weight);
      }

      return {
        fullPath: this.fullPath,
        not,
        ...filters,
      };
    },
    shouldSkipQuery() {
      return !this.fullPath || !this.type || !this.isValidDateRange;
    },
    isLoading() {
      return (
        this.$apollo.queries.issuesOpenedCounts?.loading ||
        this.$apollo.queries.issuesClosedCounts?.loading
      );
    },
    isValidDateRange() {
      return (
        isValidDate(this.startDate) && isValidDate(this.endDate) && this.endDate >= this.startDate
      );
    },
    barsData() {
      return extractIssuesAnalyticsCounts({
        ...this.issuesOpenedCounts,
        ...this.issuesClosedCounts,
      });
    },
    hasChartData() {
      if (!this.issuesOpenedCounts && !this.issuesClosedCounts) return false;

      return this.barsData?.some(({ data }) => data.some((value) => value > 0));
    },
    dates() {
      return generateChartDateRangeData(this.startDate, this.endDate).map(({ month, year }) => ({
        month,
        year,
      }));
    },
    monthLabels() {
      return this.dates.map(({ month }) => month);
    },
    monthYearLabels() {
      return this.dates.map(({ month, year }) => `${month} ${year}`);
    },
    firstMonthYearLabel() {
      return this.monthYearLabels[0];
    },
    monthsCount() {
      return differenceInMonths(this.startDate, this.endDate);
    },
    dateRange() {
      const { monthYearLabels, firstMonthYearLabel } = this;

      return sprintf(__('%{startDate} – %{dueDate}'), {
        startDate: firstMonthYearLabel,
        dueDate: monthYearLabels.at(-1),
      });
    },
    xAxisTitle() {
      const { monthsCount, dateRange, firstMonthYearLabel } = this;

      if (monthsCount === 0) {
        return sprintf(s__('IssuesAnalytics|This month (%{currentMonthYear})'), {
          currentMonthYear: firstMonthYearLabel,
        });
      }

      return sprintf(
        n__(
          'IssuesAnalytics|Last month (%{dateRange})',
          'IssuesAnalytics|Last %{monthsCount} months (%{dateRange})',
          monthsCount,
        ),
        { monthsCount, dateRange },
      );
    },
    hasFilters() {
      return Object.values(this.filters).some((filter) => Boolean(filter));
    },
    shouldShowError() {
      return !this.isLoading && this.hasError;
    },
    shouldShowEmptyState() {
      return !this.isLoading && !this.hasChartData;
    },
    shouldShowNoDataEmptyState() {
      return this.shouldShowEmptyState && !this.hasFilters;
    },
    shouldHideFilteredSearchBar() {
      return this.shouldShowNoDataEmptyState && !this.shouldShowError;
    },
    emptyStateType() {
      return this.shouldShowNoDataEmptyState
        ? NO_DATA_EMPTY_STATE_TYPE
        : NO_DATA_WITH_FILTERS_EMPTY_STATE_TYPE;
    },
  },
  methods: {
    getIssuesAnalyticsCountsQuery(queryAlias) {
      const { startDate, endDate, isProject } = this;

      return issuesAnalyticsCountsQueryBuilder({ queryAlias, startDate, endDate, isProject });
    },
    getIssuesAnalyticsCountsQueryResponse(data) {
      return data?.namespace ?? {};
    },
    handleQueryError(e) {
      Sentry.captureException(e);
      this.hasError = true;
    },
    formatTooltipText({ seriesData }) {
      const [firstSeries] = seriesData;
      const { dataIndex } = firstSeries;

      this.tooltipTitle = this.monthYearLabels[dataIndex];
      this.tooltipContent = seriesData.map(({ seriesName, seriesId, value, componentIndex }) => ({
        seriesName,
        seriesId,
        color: this.$options.colorPalette[componentIndex],
        value,
      }));
    },
  },
  i18n: {
    yAxisTitle: s__('IssuesAnalytics|Issues Opened vs Closed'),
    errorMessage: s__('IssuesAnalytics|Failed to load chart. Please try again.'),
    chartHeader: s__('IssuesAnalytics|Overview'),
  },
  colorPalette: TOTAL_ISSUES_ANALYTICS_CHART_COLOR_PALETTE,
  chartOptions: {
    xAxis: {
      axisPointer: {
        type: 'shadow',
      },
    },
  },
};
</script>

<template>
  <div
    v-if="isLoading"
    class="issues-analytics-chart-loader gl-flex gl-items-center gl-justify-center"
  >
    <gl-loading-icon size="lg" />
  </div>
  <gl-alert v-else-if="shouldShowError" variant="danger" :dismissible="false">
    {{ $options.i18n.errorMessage }}
  </gl-alert>
  <issues-analytics-empty-state
    v-else-if="shouldShowEmptyState"
    :empty-state-type="emptyStateType"
  />
  <div v-else>
    <h4 class="gl-mb-5 gl-mt-0">{{ $options.i18n.chartHeader }}</h4>
    <gl-stacked-column-chart
      :bars="barsData"
      :y-axis-title="$options.i18n.yAxisTitle"
      :x-axis-title="xAxisTitle"
      :group-by="monthLabels"
      :option="$options.chartOptions"
      :custom-palette="$options.colorPalette"
      x-axis-type="category"
      presentation="tiled"
      :format-tooltip-text="formatTooltipText"
    >
      <template #tooltip-title>{{ tooltipTitle }}</template>
      <template #tooltip-content>
        <div
          v-for="{ seriesId, seriesName, color, value } in tooltipContent"
          :key="seriesId"
          class="gl-flex gl-min-w-20 gl-justify-between gl-leading-24"
        >
          <gl-chart-series-label class="gl-text-sm" :color="color">
            {{ seriesName }}
          </gl-chart-series-label>
          <div class="gl-font-bold">{{ value }}</div>
        </div>
      </template>
    </gl-stacked-column-chart>
  </div>
</template>
