<script>
import { camelCase } from 'lodash-es';
import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { GRAY_500 } from '@gitlab/ui/src/tokens/build/js/tokens';
import {
  listenSystemColorSchemeChange,
  removeListenerSystemColorSchemeChange,
} from '~/lib/utils/css_utils';
import { getSeverityColors } from 'ee/security_dashboard/utils/chart_utils';
import { REPORT_TYPE_COLORS } from 'ee/security_dashboard/components/shared/vulnerability_report/constants';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';

const CHART_EXPORT_ID = 'vulnerabilities_by_age';

export default {
  name: 'VulnerabilitiesByAgeChart',
  components: {
    GlStackedColumnChart,
  },
  props: {
    bars: {
      type: Array,
      required: true,
      validator(value) {
        return value.every(({ name, id, data }) => {
          // Each series must have a name (string), id (string, and data (array)
          return typeof name === 'string' && typeof id === 'string' && Array.isArray(data);
        });
      },
    },
    // The x-axis category labels, one per age bucket (e.g. "0-30 days").
    labels: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      severityColors: {},
    };
  },
  computed: {
    customPalette() {
      return this.bars.map((bar) => {
        const normalizedId = camelCase(bar.id);
        return this.severityColors[normalizedId] || REPORT_TYPE_COLORS[normalizedId] || GRAY_500;
      });
    },
    key() {
      return this.bars.map((b) => b.id).join('-');
    },
  },
  mounted() {
    this.setSeverityColors();
    listenSystemColorSchemeChange(this.setSeverityColors);
    this.chartExportStore = useChartExportStore();
    this.chartExportStore.register(CHART_EXPORT_ID, this.getChartSvg);
  },
  destroyed() {
    removeListenerSystemColorSchemeChange(this.setSeverityColors);
    this.chartExportStore?.unregister(CHART_EXPORT_ID);
  },
  methods: {
    setSeverityColors() {
      this.severityColors = getSeverityColors();
    },
    getChartSvg() {
      return {
        svg: this.$refs.wrapper?.chart?.getDataURL({
          type: 'svg',
          excludeComponents: ['toolbox', 'dataZoom'],
        }),
      };
    },
  },
  chartOptions: {
    animation: false,
    xAxis: {
      axisLabel: {
        interval: 0,
      },
    },
    yAxis: [
      {
        minInterval: 1,
      },
    ],
    // Note: This is a workaround to remove the extra whitespace when the chart has no title
    // Once https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2199 has been fixed, this can be removed
    grid: {
      left: '10px',
      right: '10px',
      bottom: '10px',
      top: '10px',
      // Setting `containLabel` to `true` ensures the grid area is large enough to contain the labels
      containLabel: true,
    },
  },
};
</script>

<template>
  <gl-stacked-column-chart
    ref="wrapper"
    :key="key"
    :bars="bars"
    :option="$options.chartOptions"
    :group-by="labels"
    :custom-palette="customPalette"
    :include-legend-avg-max="false"
    presentation="stacked"
    x-axis-type="category"
    :x-axis-title="''"
    :y-axis-title="''"
    responsive
    height="auto"
  />
</template>
