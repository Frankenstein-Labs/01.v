<script>
import { defineComponent, markRaw, nextTick } from 'vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ThreeGraph2D from '../utils/three_graph_2d';
import ThreeGraph3D from '../utils/three_graph_3d';

const MAP_MODE_2D = '2d';
const MAP_MODE_3D = '3d';
const ZOOM_IN_FACTOR = 0.6;
const ZOOM_OUT_FACTOR = 1.65;

export default defineComponent({
  name: 'GraphCanvas',
  compatConfig: { MODE: 3 },
  props: {
    nodes: {
      type: Array,
      required: true,
    },
    edges: {
      type: Array,
      required: true,
    },
    selectedNodeId: {
      type: String,
      required: false,
      default: null,
    },
    nodeStyleMap: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    darkMode: {
      type: Boolean,
      required: false,
      default: true,
    },
    mapMode: {
      type: String,
      required: false,
      default: MAP_MODE_3D,
      validator: (v) => v === MAP_MODE_2D || v === MAP_MODE_3D,
    },
    labelsVisible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['node-select', 'node-hover', 'node-expand', 'init-error'],
  expose: [
    'setFullData',
    'addData',
    'searchNodes',
    'zoomIn',
    'zoomOut',
    'highlightByTypes',
    'setNodeLoading',
  ],
  data() {
    return {
      graph: null,
      resizeObserver: null,
    };
  },
  watch: {
    selectedNodeId(id) {
      if (!this.graph) return;
      if (id == null) {
        this.graph.deselectNode();
        return;
      }
      const idx = this.nodes.findIndex((n) => n.id === id);
      if (idx >= 0) this.graph.selectNode(idx);
    },
    mapMode() {
      this.rebuildGraph();
    },
    labelsVisible(visible) {
      this.graph?.setLabelsVisible(visible);
    },
  },
  created() {
    // Plain instance fields — not reactive. Nothing in the template reads them
    // and they hold Three.js Vector3s and position Maps, so Vue deep-observing
    // them would be pure overhead (same reason graph/resizeObserver use markRaw).
    this.layoutCaches = { [MAP_MODE_3D]: null, [MAP_MODE_2D]: null };
    this.cameraCaches = { [MAP_MODE_3D]: null, [MAP_MODE_2D]: null };
  },
  mounted() {
    if (!this.initGraph()) return;

    this.resizeObserver = markRaw(
      new ResizeObserver((entries) => {
        const { width, height } = entries[0].contentRect;
        if (width > 0 && height > 0) {
          this.graph?.resize(width, height);
        }
      }),
    );
    this.resizeObserver.observe(this.$el);

    // Resize after the next tick so the flex layout has settled and the
    // renderer captures the final container dimensions rather than any
    // intermediate size that existed at mount time.
    nextTick(() => {
      const { offsetWidth, offsetHeight } = this.$el;
      if (offsetWidth > 0 && offsetHeight > 0) {
        this.graph?.resize(offsetWidth, offsetHeight);
      }
    });

    if (this.nodes.length > 0) {
      this.graph.setData(this.nodes, this.edges);
    }
  },
  beforeUnmount() {
    this.cleanupCanvas();
  },
  // Vue 2 + compat MODE 3 fires beforeDestroy on $destroy, not beforeUnmount.
  // Aliased so spec wrapper.destroy() exercises the same cleanup path.
  beforeDestroy() {
    this.cleanupCanvas();
  },
  methods: {
    cleanupCanvas() {
      if (this.resizeObserver) {
        this.resizeObserver.disconnect();
        this.resizeObserver = null;
      }
      if (this.graph) {
        this.graph.dispose();
        this.graph = null;
      }
    },
    initGraph() {
      try {
        const options = { nodeStyleMap: this.nodeStyleMap, darkMode: this.darkMode };
        const GraphClass = this.mapMode === MAP_MODE_2D ? ThreeGraph2D : ThreeGraph3D;
        this.graph = markRaw(new GraphClass(this.$refs.canvas, options));
        this.graph.init();
        this.graph.setLabelsVisible(this.labelsVisible);
        this.graph.onNodeHover((node, position) => this.$emit('node-hover', node, position));
        this.graph.onNodeSelect((node) => this.$emit('node-select', node));
        this.graph.onNodeExpand((node) => this.$emit('node-expand', node));
        return true;
      } catch (error) {
        Sentry.captureException(error);
        this.$emit('init-error', error);
        return false;
      }
    },

    rebuildGraph() {
      // Snapshot layout and camera state from the outgoing graph before disposing.
      if (this.graph?.nodes?.length > 0) {
        const outgoingMode = this.graph instanceof ThreeGraph3D ? MAP_MODE_3D : MAP_MODE_2D;
        this.layoutCaches[outgoingMode] = {
          positions: new Map(
            this.graph.nodes.map((n) => [n.id, n.position ? { ...n.position } : null]),
          ),
          nodeCount: this.graph.nodes.length,
        };
        this.cameraCaches[outgoingMode] = this.graph.getCameraState?.() ?? null;
      }
      if (this.graph) this.graph.dispose();
      this.graph = null;
      if (!this.initGraph()) return;
      if (this.nodes.length > 0) {
        const cached = this.layoutCaches[this.mapMode];
        const positionCache = cached?.nodeCount === this.nodes.length ? cached.positions : null;
        this.graph.setData(this.nodes, this.edges, positionCache);
        // Restore camera after setData (which may call fitCameraToGraph internally).
        const cachedCamera = this.cameraCaches[this.mapMode];
        if (cachedCamera) this.graph.setCameraState?.(cachedCamera);
      }
    },

    setFullData() {
      // New data set — caches from previous sessions are stale.
      this.layoutCaches = { [MAP_MODE_3D]: null, [MAP_MODE_2D]: null };
      this.cameraCaches = { [MAP_MODE_3D]: null, [MAP_MODE_2D]: null };
      this.graph.setData(this.nodes, this.edges);
    },

    addData(newNodes, newEdges) {
      // Expansion adds nodes the other mode has never seen — invalidate its cache.
      const otherMode = this.mapMode === MAP_MODE_2D ? MAP_MODE_3D : MAP_MODE_2D;
      this.layoutCaches[otherMode] = null;
      this.graph.addData(newNodes, newEdges);
      // In 3D, addData() places new nodes in a ring around their parent as a
      // placeholder. relayout() redistributes everything on the Fibonacci spiral
      // for proper global distribution. 2D skips this (ThreeGraph2D has no
      // relayout) — it already calls computeFlatTopologicalLayout inside addData().
      this.graph.relayout?.();
    },

    searchNodes(query) {
      return this.graph.searchNodes(query);
    },

    zoomIn() {
      this.graph.zoomBy(ZOOM_IN_FACTOR);
    },

    zoomOut() {
      this.graph.zoomBy(ZOOM_OUT_FACTOR);
    },

    highlightByTypes(activeTypes) {
      this.graph.highlightByTypes(activeTypes);
    },

    setNodeLoading(nodeIndex, loading) {
      this.graph.setNodeLoading(nodeIndex, loading);
    },
  },
});
</script>

<template>
  <div class="gl-relative gl-h-full gl-w-full" data-testid="graph-canvas">
    <div
      v-show="graph"
      ref="canvas"
      class="gl-h-full gl-w-full gl-cursor-grab"
      data-testid="graph-canvas-3d"
    ></div>
  </div>
</template>
