<script>
import { throttle } from 'lodash-es';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { measureNode, connectorPath } from '../flow_graph';

export default {
  name: 'FlowConnectors',
  props: {
    edges: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      paths: [],
    };
  },
  watch: {
    edges() {
      this.$nextTick(this.redraw);
    },
  },
  created() {
    this.redrawOnResize = throttle(this.redraw, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  mounted() {
    this.$nextTick(this.redraw);

    this.containerObserver = new ResizeObserver(this.redrawOnResize);
    this.containerObserver.observe(this.$el.parentElement);
  },
  beforeDestroy() {
    this.containerObserver.disconnect();
    this.redrawOnResize.cancel();
  },
  methods: {
    nodeElement(container, nodeId) {
      return container.querySelector(`[data-flow-node="${nodeId}"]`);
    },
    redraw() {
      const container = this.$el.parentElement;
      const containerRect = container.getBoundingClientRect();

      this.paths = this.edges.reduce((paths, { from, to }) => {
        const fromElement = this.nodeElement(container, from);
        const toElement = this.nodeElement(container, to);

        if (!fromElement || !toElement) {
          return paths;
        }

        paths.push({
          key: `${from}->${to}`,
          d: connectorPath(
            measureNode(fromElement, containerRect),
            measureNode(toElement, containerRect),
          ),
        });

        return paths;
      }, []);
    },
  },
};
</script>

<template>
  <svg
    class="gl-pointer-events-none gl-absolute gl-inset-0 gl-z-1 gl-h-full gl-w-full gl-text-disabled"
    aria-hidden="true"
    focusable="false"
    data-testid="flow-connectors"
  >
    <defs>
      <marker
        id="cd-flow-arrow"
        markerWidth="4"
        markerHeight="4"
        refX="4"
        refY="2"
        orient="auto"
        markerUnits="strokeWidth"
      >
        <polygon points="0,0 4,2 0,4" fill="currentColor" />
      </marker>
    </defs>

    <path
      v-for="path in paths"
      :key="path.key"
      :d="path.d"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      marker-end="url(#cd-flow-arrow)"
      data-testid="flow-connector"
    />
  </svg>
</template>
