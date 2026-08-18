<script>
import { GlStackedColumnChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { GlSkeletonLoader, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { initial } from 'lodash-es';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { sprintf, __, n__ } from '~/locale';
import groupDoraPerformanceScoreCountsQuery from '../graphql/group_dora_performance_score_counts.query.graphql';
import { extractDoraPerformanceScoreCounts } from '../api';
import {
  DORA_PERFORMERS_SCORE_METRICS,
  DORA_PERFORMERS_SCORE_PANEL_TITLE_WITH_PROJECTS_COUNT,
  DORA_PERFORMERS_SCORE_TOOLTIP_PROJECTS_COUNT_TITLE,
  DORA_PERFORMERS_SCORE_NOT_INCLUDED,
  DORA_PERFORMERS_SCORE_LOADING_ERROR,
  DORA_PERFORMERS_SCORE_CHART_COLOR_PALETTE,
} from '../constants';
import { DASHBOARD_NO_DATA_FOR_GROUP } from '../../constants';
import { validateProjectTopics } from '../utils';
import FilterProjectTopicsBadges from './filter_project_topics_badges.vue';

export default {
  name: 'DoraPerformersScoreChart',
  components: {
    GlStackedColumnChart,
    GlChartSeriesLabel,
    ChartSkeletonLoader,
    GlSkeletonLoader,
    GlIcon,
    FilterProjectTopicsBadges,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
  },
  emits: ['error'],
  data() {
    return {
      chart: null,
      tooltip: {
        projectsCountTitle: null,
        metricTitle: null,
        scores: [],
        scoreDefinition: null,
      },
    };
  },
  apollo: {
    // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
    groupDoraPerformanceScoreCounts: {
      query: groupDoraPerformanceScoreCountsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          topics: this.filterProjectTopics,
        };
      },
      skip() {
        return !this.fullPath;
      },
      update(data) {
        const {
          noDoraDataProjectsCount = 0,
          nodes: items = [],
          totalProjectsCount = 0,
        } = data?.group?.doraPerformanceScoreCounts || {};

        return {
          totalProjectsCount,
          noDoraDataProjectsCount,
          items,
        };
      },
      error() {
        const { fullPath } = this;
        this.$emit('error', sprintf(this.$options.i18n.loadingError, { fullPath }));
      },
    },
  },
  computed: {
    fullPath() {
      return this.data?.namespace;
    },
    isLoading() {
      return this.$apollo.queries.groupDoraPerformanceScoreCounts.loading;
    },
    chartData() {
      return extractDoraPerformanceScoreCounts(this.groupDoraPerformanceScoreCounts?.items);
    },
    doraMetrics() {
      return DORA_PERFORMERS_SCORE_METRICS.map(({ label }) => label);
    },
    projectsCountWithDoraData() {
      const { totalProjectsCount, noDoraDataProjectsCount } =
        this.groupDoraPerformanceScoreCounts || {};

      return Math.max(0, totalProjectsCount - noDoraDataProjectsCount) || 0; // handle edge case where noDoraDataProjectsCount could be higher than totalProjectsCount
    },
    panelTitle() {
      const count = this.projectsCountWithDoraData;
      return sprintf(this.$options.i18n.panelTitleWithProjectsCount, { count });
    },
    hasData() {
      return (
        this.projectsCountWithDoraData &&
        initial(this.chartData).some(({ data }) => data.some((val) => val)) // ignore the "Not included" series – we are only interested in checking if any projects have high/medium/low score counts
      );
    },
    noDataMessage() {
      return sprintf(this.$options.i18n.noData, {
        fullPath: this.fullPath,
      });
    },
    tooltipTitle() {
      const { metricTitle, projectsCountTitle } = this.tooltip;

      if (projectsCountTitle) {
        return projectsCountTitle;
      }

      return metricTitle;
    },
    excludedProjectsMessage() {
      const { noDoraDataProjectsCount } = this.groupDoraPerformanceScoreCounts || {};

      if (!this.hasData || !noDoraDataProjectsCount) return '';

      return n__(
        'Excluding 1 project with no DORA metrics',
        'Excluding %d projects with no DORA metrics',
        noDoraDataProjectsCount,
      );
    },
    filterProjectTopics() {
      const { filters: { projectTopics = [] } = {} } = this.data;
      return validateProjectTopics(projectTopics);
    },
    hasFilterProjectTopics() {
      return this.filterProjectTopics.length > 0;
    },
  },
  beforeDestroy() {
    if (this.chart) {
      this.chart.off('mouseover', this.onChartDataSeriesMouseOver);
      this.chart.off('mouseout', this.onChartDataSeriesMouseOut);
    }
  },
  methods: {
    onChartCreated(chart) {
      this.chart = chart;

      this.chart.on('mouseover', 'series', this.onChartDataSeriesMouseOver);
      this.chart.on('mouseout', 'series', this.onChartDataSeriesMouseOut);
    },
    onChartDataSeriesMouseOver({ dataIndex, seriesIndex, value }) {
      const scoreDefinition =
        this.getScoreDefinition(dataIndex, seriesIndex) ??
        this.$options.i18n.notIncludedScoreDefinition(value);
      const projectsCountTitle = this.$options.i18n.tooltipProjectsCountTitle(value);

      this.tooltip = {
        ...this.tooltip,
        projectsCountTitle,
        scoreDefinition,
      };
    },
    onChartDataSeriesMouseOut() {
      this.tooltip = { ...this.tooltip, projectsCountTitle: null, scoreDefinition: null };
    },
    getScoreDefinition(dataIndex, seriesIndex) {
      return DORA_PERFORMERS_SCORE_METRICS[dataIndex].scoreDefinitions[seriesIndex];
    },
    formatTooltipText({ value: metricTitle, seriesData }) {
      const scores = seriesData.map(({ seriesId, seriesName, seriesIndex, value }) => ({
        seriesId,
        seriesName,
        color: this.$options.customPalette[seriesIndex],
        value: value ?? this.$options.i18n.noTooltipData,
      }));

      this.tooltip = {
        ...this.tooltip,
        metricTitle,
        scores,
      };
    },
  },
  i18n: {
    noData: DASHBOARD_NO_DATA_FOR_GROUP,
    noTooltipData: __('No data'),
    loadingError: DORA_PERFORMERS_SCORE_LOADING_ERROR,
    panelTitleWithProjectsCount: DORA_PERFORMERS_SCORE_PANEL_TITLE_WITH_PROJECTS_COUNT,
    notIncludedScoreDefinition: DORA_PERFORMERS_SCORE_NOT_INCLUDED,
    tooltipProjectsCountTitle: DORA_PERFORMERS_SCORE_TOOLTIP_PROJECTS_COUNT_TITLE,
  },
  customPalette: DORA_PERFORMERS_SCORE_CHART_COLOR_PALETTE,
  presentation: 'tiled',
  xAxisTitle: '',
  yAxisTitle: '',
  xAxisType: 'category',
  chartOptions: {
    yAxis: [
      {
        axisLabel: {
          formatter: (value) => value,
        },
      },
    ],
  },
};
</script>

<template>
  <div>
    <gl-skeleton-loader v-if="isLoading" :lines="1" :width="450" />
    <div v-else class="gl-flex gl-items-center gl-justify-between">
      <div
        data-testid="dora-performers-score-chart-title"
        class="gl-my-0 gl-flex gl-items-center gl-gap-3"
      >
        {{ panelTitle }}
        <gl-icon
          v-if="excludedProjectsMessage"
          v-gl-tooltip="excludedProjectsMessage"
          name="information-o"
        />
      </div>

      <filter-project-topics-badges v-if="hasFilterProjectTopics" :topics="filterProjectTopics" />
    </div>

    <chart-skeleton-loader v-if="isLoading" />

    <div v-else-if="!hasData" class="gl-text-center gl-text-subtle">
      {{ noDataMessage }}
    </div>

    <gl-stacked-column-chart
      v-else
      :bars="chartData"
      :group-by="doraMetrics"
      :option="$options.chartOptions"
      :presentation="$options.presentation"
      :custom-palette="$options.customPalette"
      :x-axis-type="$options.xAxisType"
      :x-axis-title="$options.xAxisTitle"
      :y-axis-title="$options.yAxisTitle"
      :include-legend-avg-max="false"
      :format-tooltip-text="formatTooltipText"
      :height="380"
      responsive
      @created="onChartCreated"
    >
      <template #tooltip-title>{{ tooltipTitle }}</template>
      <template #tooltip-content>
        <div v-if="tooltip.scoreDefinition" class="gl-max-w-26">{{ tooltip.scoreDefinition }}</div>
        <template v-else>
          <div
            v-for="{ seriesId, seriesName, color, value } in tooltip.scores"
            :key="seriesId"
            class="gl-flex gl-min-w-20 gl-justify-between gl-leading-24"
          >
            <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="color">
              {{ seriesName }}
            </gl-chart-series-label>
            <div>{{ value }}</div>
          </div>
        </template>
      </template>
    </gl-stacked-column-chart>
  </div>
</template>
