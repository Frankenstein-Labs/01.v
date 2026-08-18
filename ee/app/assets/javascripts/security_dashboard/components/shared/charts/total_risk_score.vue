<script>
import { GlResizeObserverDirective } from '@gitlab/ui';
import { GlChart } from '@gitlab/ui/src/charts';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';
import {
  cropSvgWhitespace,
  exportChartSvgAtSize,
} from 'ee/security_dashboard/utils/svg_export_utils';
import { s__ } from '~/locale';

const RATING_LABELS = {
  LOW: s__('SecurityReports|Low risk'),
  MEDIUM: s__('SecurityReports|Medium risk'),
  HIGH: s__('SecurityReports|High risk'),
  CRITICAL: s__('SecurityReports|Critical risk'),
};

const CHART_EXPORT_ID = 'total_risk_score';
const SVG_EXPORT_WIDTH = 600;
const SVG_EXPORT_HEIGHT = 600;
const GAUGE_CENTER_X_PERCENT = 0.5;
const GAUGE_CENTER_Y_PERCENT = 0.6;

export default {
  components: {
    GlChart,
  },
  directives: {
    GlResizeObserver: GlResizeObserverDirective,
  },
  props: {
    score: {
      type: Number,
      required: true,
      validator: (value) => value >= 0 && value <= 100,
    },
  },
  data() {
    return {
      chartWidth: 0,
      chartHeight: 0,
    };
  },
  computed: {
    label() {
      return RATING_LABELS[this.rating];
    },
    labelTextColor() {
      return `var(--risk-score-gauge-text-${this.rating.toLowerCase()})`;
    },
    rating() {
      if (this.score <= 25) {
        return 'LOW';
      }

      if (this.score <= 50) {
        return 'MEDIUM';
      }

      if (this.score <= 75) {
        return 'HIGH';
      }

      return 'CRITICAL';
    },
    chartOptions() {
      return {
        series: [this.outerMeterRing, this.progressMeterRing],
      };
    },
    gaugeDimensions() {
      // the center is slightly raised, because a gauge chart is usually a full circle, but we don't display the bottom part of the circle
      const gapBetweenRingsInPx = 1;
      const outerMeterMaxWidthInPx = 15;
      const outerRingWidthRatio = 0.2;

      // the radius of the outer meter ring is the smallest distance from the center to the edge of the chart
      const { radius: outerMeterRadiusInPx } = this.computeGaugeBounds(
        this.chartWidth,
        this.chartHeight,
      );

      const outerMeterRingWidth = Math.min(
        outerMeterMaxWidthInPx,
        Math.round(outerMeterRadiusInPx * outerRingWidthRatio),
      );

      const progressMeterRadiusInPx =
        outerMeterRadiusInPx - outerMeterRingWidth - gapBetweenRingsInPx;
      const progressMeterRingWidth = outerMeterRingWidth * 2;

      return {
        centerXPercent: GAUGE_CENTER_X_PERCENT,
        centerYPercent: GAUGE_CENTER_Y_PERCENT,
        outerMeter: {
          radius: outerMeterRadiusInPx,
          ringWidth: outerMeterRingWidth,
        },
        progressMeter: {
          radius: progressMeterRadiusInPx,
          ringWidth: progressMeterRingWidth,
        },
      };
    },
    outerMeterRing() {
      return {
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 100,
        splitNumber: 4,
        center: [
          `${this.gaugeDimensions.centerXPercent * 100}%`,
          `${this.gaugeDimensions.centerYPercent * 100}%`,
        ],
        radius: this.gaugeDimensions.outerMeter.radius,
        axisLine: {
          lineStyle: {
            width: this.gaugeDimensions.outerMeter.ringWidth,
            color: [
              [0.25, this.getRiskScoreColor('LOW')],
              [0.5, this.getRiskScoreColor('MEDIUM')],
              [0.75, this.getRiskScoreColor('HIGH')],
              [1, this.getRiskScoreColor('CRITICAL')],
            ],
          },
        },
        pointer: {
          show: false,
        },
        axisTick: {
          show: true,
          lineStyle: {
            color: '#fff',
            width: 1,
          },
          length: 6,
          distance: -this.gaugeDimensions.outerMeter.ringWidth,
        },
        splitLine: {
          show: false,
        },
        axisLabel: {
          show: false,
        },
        // the risk rating label (e.g. "Low risk")
        detail: {
          show: true,
          width: 100,
          height: 40,
          offsetCenter: [0, -20],
          fontSize: 45,
          color: this.labelTextColor,
        },
        title: {
          show: true,
          offsetCenter: [0, 15], // Position below the risk rating label
          fontSize: 17,
          color: this.labelTextColor,
        },
        // the score value displayed as a number
        data: [
          {
            value: this.score,
            name: this.label,
          },
        ],
      };
    },
    progressMeterRing() {
      return {
        type: 'gauge',
        startAngle: 220,
        endAngle: -40,
        min: 0,
        max: 100,
        splitNumber: 4,
        center: [
          `${this.gaugeDimensions.centerXPercent * 100}%`,
          `${this.gaugeDimensions.centerYPercent * 100}%`,
        ],
        radius: this.gaugeDimensions.progressMeter.radius,
        axisLine: {
          show: true,
          lineStyle: {
            width: this.gaugeDimensions.progressMeter.ringWidth,
            color: [
              // the actual data representation
              [this.score / 100, this.getRiskScoreColor(this.rating)],
              // transparent to support dark and light mode
              [1, 'transparent'],
            ],
          },
        },
        pointer: {
          show: false,
        },
        axisTick: {
          show: false,
        },
        splitLine: {
          show: false,
        },
        axisLabel: {
          show: false,
        },
        title: {
          show: false,
        },
        detail: {
          show: false,
        },
        data: [
          {
            value: this.score,
          },
        ],
      };
    },
  },
  mounted() {
    this.chartExportStore = useChartExportStore();
    this.chartExportStore.register(CHART_EXPORT_ID, this.getChartSvg);
  },
  destroyed() {
    this.chartExportStore?.unregister(CHART_EXPORT_ID);
  },
  methods: {
    computeGaugeBounds(width, height) {
      const cx = Math.round(width * GAUGE_CENTER_X_PERCENT);
      const cy = Math.round(height * GAUGE_CENTER_Y_PERCENT);
      const radius = Math.min(cx, width - cx, cy, height - cy);
      return { cx, cy, radius };
    },
    onResize({ contentRect: { width, height } }) {
      this.chartWidth = width;
      this.chartHeight = height;
    },
    getRiskScoreColor(rating) {
      return `var(--risk-score-color-${rating.toLowerCase()})`;
    },
    getChartSvg() {
      const dataUrl = exportChartSvgAtSize(
        this.$refs.wrapper?.chart,
        SVG_EXPORT_WIDTH,
        SVG_EXPORT_HEIGHT,
      );

      if (!dataUrl) {
        return { svg: null };
      }

      const { cx, cy } = this.computeGaugeBounds(SVG_EXPORT_WIDTH, SVG_EXPORT_HEIGHT);

      return {
        svg: cropSvgWhitespace(dataUrl, {
          cx,
          cy,
          exportWidth: SVG_EXPORT_WIDTH,
          exportHeight: SVG_EXPORT_HEIGHT,
        }),
      };
    },
  },
};
</script>

<template>
  <div
    v-gl-resize-observer="onResize"
    class="gl-justify-content-center gl-align-items-center gl-flex gl-h-full gl-w-full"
  >
    <gl-chart
      ref="wrapper"
      :options="chartOptions"
      responsive
      height="auto"
      class="gl-h-full gl-w-full"
    />
  </div>
</template>
