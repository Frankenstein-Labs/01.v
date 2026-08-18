<script>
import { GlLink, GlIcon, GlSprintf } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime_utility';
import { SHORT_DATE_TIME_FORMAT } from '~/observability/constants';
import { viewTracesUrlWithMetric } from './utils';

export default {
  name: 'RelatedTraces',
  components: {
    GlLink,
    GlIcon,
    GlSprintf,
  },
  props: {
    dataPoints: {
      type: Array,
      required: true,
    },
    tracingIndexUrl: {
      type: String,
      required: true,
    },
  },
  computed: {
    dataPointsByValue() {
      return this.dataPoints.toSorted((a, b) => b.value - a.value);
    },
    itemsWithTracingUrl() {
      return this.dataPointsByValue.map((dataPoint) => ({
        ...dataPoint,
        url: this.getTracesUrl(dataPoint),
      }));
    },
    timeUtcString() {
      const { timestamp } = this.dataPoints[0] || {};

      return timestamp ? formatDate(timestamp, SHORT_DATE_TIME_FORMAT) : null;
    },
    hasTraces() {
      return this.dataPoints.some(({ traceIds }) => traceIds.length > 0);
    },
    showWidget() {
      return this.dataPoints.length > 0;
    },
  },
  methods: {
    getTracesUrl(dataPoint) {
      if (dataPoint.traceIds.length < 1) return null;

      return viewTracesUrlWithMetric(this.tracingIndexUrl, dataPoint);
    },
    iconAttrs(item) {
      if (item.traceIds.length > 0) {
        return {
          name: 'status_created',
          size: 16,
        };
      }
      return {
        name: 'severity-low',
        size: 8,
        class: 'gl-ml-2',
      };
    },
  },
};
</script>

<template>
  <section v-if="showWidget">
    <h5>
      <gl-sprintf :message="s__('ObservabilityMetrics|Related traces at %{time}')">
        <template #time>{{ timeUtcString }}</template>
      </gl-sprintf>
    </h5>

    <ul v-if="hasTraces" class="gl-m-0 gl-list-none gl-p-0" data-testid="traces-list">
      <li
        v-for="item in itemsWithTracingUrl"
        :key="item.seriesName"
        class="gl-flex gl-items-center gl-gap-3"
      >
        <gl-icon :style="{ color: item.color }" v-bind="iconAttrs(item)" />
        <span>
          {{ item.seriesName }}
          <gl-sprintf :message="s__('ObservabilityMetrics|(Value: %{value})')">
            <template #value>{{ item.value }}</template>
          </gl-sprintf>
        </span>
        <gl-link v-if="item.url" :href="item.url">{{
          s__('ObservabilityMetrics|View traces')
        }}</gl-link>
        <span v-else class="gl-text-subtle">{{
          s__('ObservabilityMetrics|No related traces')
        }}</span>
      </li>
    </ul>

    <p v-else class="gl-text-subtle">
      {{
        s__(
          'ObservabilityMetrics|No related traces for the selected time. Select another data point and try again.',
        )
      }}
    </p>
  </section>
</template>
