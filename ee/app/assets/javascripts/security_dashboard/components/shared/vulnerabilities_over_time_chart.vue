<script>
import { GlTooltipDirective, GlTableLite } from '@gitlab/ui';
import { GlSparklineChart } from '@gitlab/ui/src/charts';
import { set } from 'lodash-es';
import {
  SEVERITY_LEVEL_CRITICAL,
  SEVERITY_LEVEL_HIGH,
  SEVERITY_LEVEL_MEDIUM,
  SEVERITY_LEVEL_LOW,
  EXPORT_ERROR_MESSAGE_CHART_LOADING,
  EXPORT_ERROR_MESSAGE_CHART_FAILURE,
} from 'ee/security_dashboard/constants';
import SeverityBadge from 'ee/vue_shared/security_reports/components/severity_badge.vue';
import { firstAndLastY } from '~/lib/utils/chart_utils';
import {
  formatDate,
  differenceInMilliseconds,
  millisecondsPerDay,
} from '~/lib/utils/datetime_utility';
import { formattedChangeInPercent } from '~/lib/utils/number_utils';
import { s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { PdfExportError } from 'ee/security_dashboard/helpers';
import SecurityDashboardCard from './security_dashboard_card.vue';
import ChartButtons from './vulnerabilities_over_time_chart_buttons.vue';

const ISO_DATE = 'isoDate';
const TD_CLASS = '!gl-border-none';
const CLASS_TEXT_RIGHT = `gl-text-right`;
const TD_CLASS_TEXT_RIGHT = `${TD_CLASS} ${CLASS_TEXT_RIGHT}`;

const DAYS = { thirty: 30, sixty: 60, ninety: 90 };

const severityLevels = [
  SEVERITY_LEVEL_CRITICAL,
  SEVERITY_LEVEL_HIGH,
  SEVERITY_LEVEL_MEDIUM,
  SEVERITY_LEVEL_LOW,
];

export default {
  components: {
    SecurityDashboardCard,
    ChartButtons,
    GlSparklineChart,
    GlTableLite,
    SeverityBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['groupFullPath'],
  props: {
    query: { type: Object, required: true },
  },
  emits: ['chart-report-data-registered'],
  data() {
    return {
      vulnerabilitiesHistory: {},
      selectedDayRange: DAYS.thirty,
      chartObject: {},
    };
  },
  days: Object.values(DAYS),
  fields: [
    {
      key: 'severityLevel',
      label: s__('VulnerabilityChart|Severity'),
      tdClass: TD_CLASS,
    },
    {
      key: 'chartData',
      label: '',
      tdClass: `${TD_CLASS} gl-w-full`,
    },
    {
      key: 'changeInPercent',
      label: '%',
      thAlignRight: true,
      tdClass: TD_CLASS_TEXT_RIGHT,
    },
    {
      key: 'currentVulnerabilitiesCount',
      label: '#',
      thAlignRight: true,
      tdClass: TD_CLASS_TEXT_RIGHT,
    },
  ],
  apollo: {
    vulnerabilitiesHistory: {
      query() {
        return this.query;
      },
      variables() {
        return {
          fullPath: this.groupFullPath,
          startDate: formatDate(this.startDate, ISO_DATE),
          endDate: this.formattedEndDateCursor,
        };
      },
      update(results) {
        return this.processRawData(results);
      },
      error() {
        createAlert({
          message: s__(
            'SecurityReports|Failed to retrieve the vulnerability data. Please refresh the page.',
          ),
        });
      },
    },
  },
  computed: {
    startDate() {
      return differenceInMilliseconds(millisecondsPerDay * this.selectedDayRange);
    },
    endDateCursor() {
      return Date.now();
    },
    formattedEndDateCursor() {
      return formatDate(new Date(this.endDateCursor), ISO_DATE);
    },
    charts() {
      return severityLevels.map((severityLevel) => {
        const history = Object.entries(this.vulnerabilitiesHistory[severityLevel] || {});
        const chartData = history.length ? history : this.emptyDataSet;
        const [pastCount, currentCount] = firstAndLastY(chartData);
        const changeInPercent = formattedChangeInPercent(pastCount, currentCount);

        return {
          severityLevel,
          chartData,
          changeInPercent,
          currentVulnerabilitiesCount: currentCount,
        };
      });
    },
    dateInfo() {
      return sprintf(s__('VulnerabilityChart|%{formattedStartDate} to today'), {
        formattedStartDate: formatDate(this.startDate, 'mmmm dS'),
      });
    },
    emptyDataSet() {
      const formattedStartDate = formatDate(this.startDate, ISO_DATE);
      const formattedEndDate = formatDate(Date.now(), ISO_DATE);
      return [
        [formattedStartDate, 0],
        [formattedEndDate, 0],
      ];
    },
    isLoadingHistory() {
      return this.$apollo.queries.vulnerabilitiesHistory.loading;
    },
  },
  mounted() {
    this.$emit('chart-report-data-registered', this.getChartReportData);
  },
  methods: {
    setSelectedDayRange(days) {
      this.selectedDayRange = days;
    },
    processRawData(results) {
      const data = this.groupFullPath
        ? results.group.vulnerabilitiesCountByDay
        : results.vulnerabilitiesCountByDay;

      return data.nodes.reduce((acc, item) => {
        severityLevels.forEach((severity) => {
          set(acc, `${severity}.${item.date}`, item[severity]);
        });

        return acc;
      }, {});
    },
    onChartCreated(echarts, severityLevel) {
      this.chartObject[severityLevel] = echarts;
    },
    getChartReportData() {
      if (this.isLoadingHistory) {
        throw new PdfExportError(EXPORT_ERROR_MESSAGE_CHART_LOADING);
      }

      const charts = severityLevels.map((severityLevel) => {
        const chartItem = this.charts.find((item) => item.severityLevel === severityLevel);
        const chart = this.chartObject[severityLevel];

        if (!chart) {
          throw new PdfExportError(EXPORT_ERROR_MESSAGE_CHART_FAILURE);
        }

        return {
          severity: severityLevel,
          svg: chart.getDataURL({
            type: 'svg',
            excludeComponents: ['toolbox', 'dataZoom'],
          }),
          change_in_percent: chartItem?.changeInPercent,
          current_count: chartItem?.currentVulnerabilitiesCount,
        };
      });

      return {
        charts,
        selected_day_range: this.selectedDayRange,
        date_info: this.dateInfo,
      };
    },
  },
};
</script>

<template>
  <security-dashboard-card :is-loading="isLoadingHistory">
    <template #title>
      {{ __('Vulnerabilities over time') }}
    </template>
    <template #help-text>
      {{ dateInfo }}
    </template>
    <template #controls>
      <chart-buttons
        :days="$options.days"
        :active-day="selectedDayRange"
        @days-selected="setSelectedDayRange"
      />
    </template>

    <gl-table-lite
      :fields="$options.fields"
      :items="charts"
      class="js-vulnerabilities-chart-severity-level-breakdown gl-mb-3"
    >
      <template #head(changeInPercent)="{ label }">
        <span v-gl-tooltip :title="__('Difference between start date and now')">{{ label }}</span>
      </template>

      <template #head(currentVulnerabilitiesCount)="{ label }">
        <span v-gl-tooltip :title="__('Current vulnerabilities count')">{{ label }}</span>
      </template>

      <template #cell(severityLevel)="{ value }">
        <severity-badge :ref="`severityBadge${value}`" :severity="value" />
      </template>
      <template #cell(chartData)="{ item }">
        <div class="gl-relative gl-p-5">
          <gl-sparkline-chart
            :ref="`sparklineChart${item.severityLevel}`"
            :height="32"
            :data="item.chartData"
            :tooltip-label="__('Vulnerabilities')"
            :show-last-y-value="false"
            class="gl-absolute gl-left-0 gl-top-0 gl-w-full"
            @created="onChartCreated($event, item.severityLevel)"
          />
        </div>
      </template>
      <template #cell(changeInPercent)="{ value }">
        <span ref="changeInPercent">{{ value }}</span>
      </template>
      <template #cell(currentVulnerabilitiesCount)="{ value }">
        <span ref="currentVulnerabilitiesCount">{{ value }}</span>
      </template>
    </gl-table-lite>
  </security-dashboard-card>
</template>
