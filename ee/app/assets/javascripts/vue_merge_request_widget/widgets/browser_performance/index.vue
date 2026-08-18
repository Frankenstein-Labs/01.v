<script>
import { n__, s__, sprintf } from '~/locale';
import axios from '~/lib/utils/axios_utils';
import { formattedChangeInPercent } from '~/lib/utils/number_utils';
import MrWidget from '~/vue_merge_request_widget/components/widget/widget.vue';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';

export default {
  name: 'WidgetBrowserPerformance',
  i18n: {
    loading: s__('ciReport|Browser performance test metrics results are being parsed'),
  },
  components: {
    MrWidget,
  },
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  emits: ['loaded'],
  data() {
    return {
      headMetrics: [],
      baseMetrics: [],
    };
  },
  computed: {
    statusIcon() {
      const { degraded = [], same = [] } = this.compareBrowserPerformanceMetrics();
      return degraded.length > 0 || same.length > 0
        ? EXTENSION_ICONS.warning
        : EXTENSION_ICONS.success;
    },
    summary() {
      const { improved = [], degraded = [], same = [] } = this.compareBrowserPerformanceMetrics();
      const changesFound = improved.length + degraded.length + same.length;
      const text = sprintf(
        n__(
          'ciReport|Browser performance test metrics: %{strong_start}%{changesFound}%{strong_end} change',
          'ciReport|Browser performance test metrics: %{strong_start}%{changesFound}%{strong_end} changes',
          changesFound,
        ),
        {
          changesFound,
        },
        false,
      );

      const reportNumbersText = sprintf(
        s__(
          'ciReport|%{danger_start}%{degradedNum} degraded%{danger_end}, %{same_start}%{sameNum} same%{same_end}, and %{success_start}%{improvedNum} improved%{success_end}',
        ),
        {
          degradedNum: degraded.length,
          sameNum: same.length,
          improvedNum: improved.length,
        },
      );

      return {
        title: text,
        subtitle: reportNumbersText,
      };
    },
    shouldCollapse() {
      return this.content.length > 0;
    },
    content() {
      const { improved = [], degraded = [], same = [] } = this.compareBrowserPerformanceMetrics();
      return [...improved, ...degraded, ...same];
    },
  },
  methods: {
    fetchHeadAndBaseReports() {
      const { head_path: headPath, base_path: basePath } = this.mr.browserPerformance;

      return [headPath, basePath].map((endpoint) => () => {
        return axios.get(endpoint).then((response) => {
          if (endpoint === headPath) {
            this.headMetrics = response.data;
          } else if (endpoint === basePath) {
            this.baseMetrics = response.data;
          }

          this.$emit('loaded', this.compareBrowserPerformanceMetrics().degraded.length);

          return response;
        });
      });
    },
    compareBrowserPerformanceMetrics() {
      const headMetricsIndexed = this.normalizeBrowserPerformanceMetrics(this.headMetrics);
      const baseMetricsIndexed = this.normalizeBrowserPerformanceMetrics(this.baseMetrics);
      const improved = [];
      const degraded = [];
      const same = [];

      Object.keys(headMetricsIndexed).forEach((subject) => {
        const subjectMetrics = headMetricsIndexed[subject];
        Object.keys(subjectMetrics).forEach((metric) => {
          const headMetricData = subjectMetrics[metric];

          if (baseMetricsIndexed[subject] && baseMetricsIndexed[subject][metric]) {
            const baseMetricData = baseMetricsIndexed[subject][metric];
            const metricData = {
              name: metric,
              path: subject,
              score: headMetricData.value,
              delta: headMetricData.value - baseMetricData.value,
            };

            if (metricData.delta !== 0) {
              const isImproved =
                headMetricData.desiredSize === 'smaller'
                  ? metricData.delta < 0
                  : metricData.delta > 0;

              if (isImproved) {
                improved.push(
                  this.prepareMetricData(metricData, {
                    name: EXTENSION_ICONS.success,
                  }),
                );
              } else {
                degraded.push(
                  this.prepareMetricData(metricData, {
                    name: EXTENSION_ICONS.failed,
                  }),
                );
              }
            } else {
              same.push(
                this.prepareMetricData(metricData, {
                  name: EXTENSION_ICONS.neutral,
                }),
              );
            }
          }
        });
      });

      return { improved, degraded, same };
    },
    prepareMetricData(metricData, icon) {
      const preparedMetricData = metricData;

      const prefix = metricData.score ? `${metricData.name}:` : metricData.name;
      const score = metricData.score ? `${this.formatScore(metricData.score)}` : '';
      const delta = metricData.delta ? `(${this.formatScore(metricData.delta)})` : '';
      const { path } = metricData;
      let deltaPercent = '';

      if (metricData.delta && metricData.score) {
        const oldScore = parseFloat(metricData.score) - metricData.delta;
        deltaPercent = `(${formattedChangeInPercent(oldScore, metricData.score)})`;
      }

      const text = sprintf(
        s__(
          'ciReport|%{prefix} %{strong_start}%{score}%{strong_end} %{delta} %{deltaPercent} in %{path}',
        ),
        {
          prefix,
          score,
          delta,
          deltaPercent,
          path,
        },
        false,
      );

      preparedMetricData.icon = icon;
      preparedMetricData.text = text;

      return preparedMetricData;
    },
    normalizeBrowserPerformanceMetrics(browserPerformanceData) {
      const indexedSubjects = {};
      browserPerformanceData.forEach(({ subject, metrics }) => {
        const indexedMetrics = {};
        metrics.forEach(({ name, ...data }) => {
          indexedMetrics[name] = data;
        });
        indexedSubjects[subject] = indexedMetrics;
      });

      return indexedSubjects;
    },
    formatScore(value) {
      if (Number(value) && !Number.isInteger(value)) {
        return (Math.floor(parseFloat(value) * 100) / 100).toFixed(2);
      }
      return value;
    },
  },
};
</script>
<template>
  <mr-widget
    :status-icon-name="statusIcon"
    :loading-text="$options.i18n.loading"
    :widget-name="$options.name"
    :is-collapsible="shouldCollapse"
    :expand-button-label="s__('ciReport|Expand browser performance details')"
    :collapse-button-label="s__('ciReport|Collapse browser performance details')"
    :fetch-collapsed-data="fetchHeadAndBaseReports"
    :summary="summary"
    :content="content"
    multi-polling
  />
</template>
