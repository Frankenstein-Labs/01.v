<script>
import { convertNanoToMs } from '~/lib/utils/datetime_utility';
import { assignColorToServices } from '../trace_utils';
import TracingSpansChart from './tracing_spans_chart.vue';

export default {
  name: 'TracingChart',
  components: {
    TracingSpansChart,
  },
  props: {
    trace: {
      required: true,
      type: Object,
    },
    spanTrees: {
      required: true,
      type: Array,
    },
    selectedSpanId: {
      required: false,
      type: String,
      default: null,
    },
  },
  emits: ['span-selected'],
  computed: {
    traceDurationMs() {
      return convertNanoToMs(this.trace.duration_nano);
    },
    serviceToColor() {
      return assignColorToServices(this.trace);
    },
  },
  methods: {
    spans(tree) {
      return [tree];
    },
    onSelect({ spanId }) {
      this.$emit('span-selected', { spanId });
    },
  },
};
</script>

<template>
  <div>
    <tracing-spans-chart
      v-for="tree in spanTrees"
      :key="tree.id"
      custom-class="gl-my-4 gl-border gl-rounded-base gl-border-b-0 gl-overflow-x-scroll"
      :spans="spans(tree)"
      :trace-duration-ms="traceDurationMs"
      :service-to-color="serviceToColor"
      :selected-span-id="selectedSpanId"
      @span-selected="onSelect"
    />
  </div>
</template>
