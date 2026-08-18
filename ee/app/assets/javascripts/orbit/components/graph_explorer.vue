<script>
import { defineComponent } from 'vue';
import { GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { darkModeEnabled } from '~/lib/utils/color_utils';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import { executeOrbitNamedQuery, executeOrbitQuery, fetchOrbitTemplates } from '../api/orbit_api';
import {
  ENTITY_TYPE_COLORS,
  ENTITY_TYPE_NAMES,
  NAMED_QUERY_EXPAND_NEIGHBORS,
  TAB_GRAPH,
  TAB_TABLE,
} from '../constants';
import {
  aggregationRowsToTable,
  graphNodesToRows,
  mergeNeighborNodes,
  toGraphId,
  transformGraphResponse,
} from '../utils/graph_transform';
import {
  buildNodeStyleMap,
  entityColorsFromSchema,
  entityNamesFromSchema,
} from '../utils/node_style_map';
import { withCache, FIVE_MINUTES_MS } from '../utils/orbit_cache';
import GraphFilterBar from './graph_filter_bar.vue';
import GraphLegend from './graph_legend.vue';
import ExplorerNodeSidebar from './explorer_node_sidebar.vue';
import ExplorerQueryPanel from './explorer_query_panel.vue';
import ExplorerTablePanel from './explorer_table_panel.vue';
import GraphCanvas from './graph_canvas.vue';
import NodeDetailOverlay from './node_detail_overlay.vue';

// Cap on neighbor rows returned for the batched initial-group expansion.
// Capping rows keeps the first render cheap regardless of how many groups
// the user is in.
const INITIAL_NEIGHBOR_LIMIT = 500;
// GKG NodeSelector.node_ids has maxItems 500; clamp the source IDs too so
// users in 500+ groups don't hit a 4xx before the page renders.
const INITIAL_NODE_IDS_CAP = 500;
// Per-node limit when a user double-clicks to expand a single node.
const EXPAND_NEIGHBOR_LIMIT = 50;
const GROUP_ENTITY = 'Group';

const ORDERED_LEGEND_TYPES = Object.freeze([
  'group',
  'project',
  'user',
  'mergerequest',
  'workitem',
  'pipeline',
  'vulnerability',
  'note',
  'milestone',
  'label',
  'branch',
  'file',
  'directory',
  'definition',
]);

export default defineComponent({
  name: 'GraphExplorer',
  compatConfig: { MODE: 3 },
  components: {
    GlLoadingIcon,
    GraphFilterBar,
    GraphLegend,
    ExplorerNodeSidebar,
    ExplorerQueryPanel,
    ExplorerTablePanel,
    GraphCanvas,
    NodeDetailOverlay,
  },
  mixins: [InternalEvents.mixin()],
  isDarkMode: darkModeEnabled(),
  TAB_GRAPH,
  TAB_TABLE,
  props: {
    initialNodes: {
      type: Array,
      required: false,
      default: () => [],
    },
    initialEdges: {
      type: Array,
      required: false,
      default: () => [],
    },
    schema: {
      type: Object,
      required: false,
      default: null,
    },
    activeTypeFilters: {
      type: Set,
      required: false,
      default: () => new Set(),
    },
    instanceMapRequest: {
      type: Object,
      required: false,
      default: null,
    },
    advancedOpen: {
      type: Boolean,
      required: false,
      default: false,
    },
    filterOpen: {
      type: Boolean,
      required: false,
      default: false,
    },
    view: {
      type: String,
      required: false,
      default: TAB_GRAPH,
    },
    mapMode: {
      type: String,
      required: false,
      default: '3d',
    },
    initialQuery: {
      type: Object,
      required: false,
      default: null,
    },
  },
  emits: [
    'close-filter',
    'close-query',
    'node-counts-change',
    'update-active-type-filters',
    'loading-change',
  ],
  data() {
    return {
      templates: [],
      templatesLoaded: false,
      queryText: this.initialQuery || {},
      selectedTemplate: null,
      loading: false,
      selectedNode: null,
      hoveredNode: null,
      hoveredPosition: null,
      searchQuery: '',
      expandedNodeIds: {},
      hintDismissed: false,
      nodes: [],
      edges: [],
      aggregationRows: [],
      highlightedTypes: new Set(),
      labelsVisible: true,
      queryError: null,
      queryErrorDetails: null,
    };
  },
  computed: {
    templateItems() {
      return this.templates.map(({ name, description }) => ({ value: name, text: description }));
    },
    schemaNodes() {
      return this.schema?.nodes || [];
    },
    stringifiedQueryText() {
      if (typeof this.queryText === 'string') return this.queryText;
      return JSON.stringify(this.queryText, null, 2);
    },
    isQueryEmpty() {
      return typeof this.queryText === 'string'
        ? this.queryText.trim().length === 0
        : Object.keys(this.queryText || {}).length === 0;
    },
    tableRows() {
      return this.aggregationRows.length > 0 ? this.aggregationRows : graphNodesToRows(this.nodes);
    },
    nodeStyleMap() {
      return buildNodeStyleMap(this.schemaNodes);
    },
    entityColors() {
      return { ...ENTITY_TYPE_COLORS, ...entityColorsFromSchema(this.schemaNodes) };
    },
    entityNames() {
      return { ...ENTITY_TYPE_NAMES, ...entityNamesFromSchema(this.schemaNodes) };
    },
    selectedNodeId() {
      return this.selectedNode ? this.selectedNode.id : null;
    },
    typeCounts() {
      const counts = {};
      for (const n of this.nodes) {
        if (n.type) {
          const t = n.type.toLowerCase();
          counts[t] = (counts[t] || 0) + 1;
        }
      }
      return counts;
    },
    legendItems() {
      const types =
        this.schemaNodes.length > 0
          ? ORDERED_LEGEND_TYPES.filter((t) => this.entityColors[t])
          : ORDERED_LEGEND_TYPES.filter((t) => this.typeCounts[t] && this.entityColors[t]);

      return types.map((t) => ({
        type: t,
        color: this.entityColors[t],
        name: this.entityNames[t] || t,
        count: this.typeCounts[t] || null,
      }));
    },
  },
  watch: {
    advancedOpen: {
      immediate: true,
      handler(open) {
        if (open) this.fetchTemplates();
      },
    },
    instanceMapRequest(req) {
      if (req) this.executeInstanceMapQuery(req);
    },
    highlightedTypes(filters) {
      this.$nextTick(() => {
        this.$refs.graphCanvas?.highlightByTypes(filters);
      });
    },
    initialNodes: {
      immediate: true,
      handler(nodes) {
        this.syncInitialGraph(nodes, this.initialEdges);
      },
    },
    initialEdges(edges) {
      this.edges = edges;
    },
    typeCounts: {
      immediate: true,
      handler(counts) {
        this.$emit('node-counts-change', counts);
      },
    },
    loading(val) {
      this.$emit('loading-change', val);
    },
  },
  mounted() {
    if (this.instanceMapRequest) {
      this.executeInstanceMapQuery(this.instanceMapRequest);
    }
  },
  methods: {
    syncInitialGraph(nodes, edges) {
      this.nodes = nodes;
      this.edges = edges;
      this.expandedNodeIds = {};
      this.selectedNode = null;

      if (nodes.length === 0) return;

      this.$nextTick(() => {
        this.$refs.graphCanvas?.setFullData();
        if (!this.instanceMapRequest) {
          this.autoExpandInitialNodes();
        }
      });
    },
    async autoExpandInitialNodes() {
      const groupNodes = this.initialNodes.filter((n) => n.type === 'group' && n.properties?.id);
      if (groupNodes.length === 0) return;

      const ids = groupNodes
        .map((n) => Number(n.properties?.id))
        .filter((id) => Number.isFinite(id))
        .slice(0, INITIAL_NODE_IDS_CAP);
      if (ids.length === 0) return;

      const cacheKey = `initial-neighbors:${GROUP_ENTITY}:${[...ids].sort().join(',')}:${INITIAL_NEIGHBOR_LIMIT}`;

      this.loading = true;
      try {
        const response = await withCache(cacheKey, FIVE_MINUTES_MS, async () => {
          const { data } = await executeOrbitNamedQuery(NAMED_QUERY_EXPAND_NEIGHBORS, {
            parameters: { entity: GROUP_ENTITY, node_ids: ids, limit: INITIAL_NEIGHBOR_LIMIT },
          });
          return data?.result || {};
        });

        const { newNodes, newEdges } = mergeNeighborNodes(response, this.nodes, this.nodeStyleMap);

        if (newNodes.length > 0) {
          this.nodes = [...this.nodes, ...newNodes];
          this.edges = [...this.edges, ...newEdges];
          this.$refs.graphCanvas?.addData(newNodes, newEdges);
        }

        const expanded = { ...this.expandedNodeIds };
        for (const node of groupNodes) expanded[node.id] = true;
        this.expandedNodeIds = expanded;
      } catch (err) {
        createAlert({
          message: err.message || s__('Orbit|Failed to load initial graph neighbors.'),
        });
      } finally {
        this.loading = false;
      }
    },
    async fetchTemplates() {
      if (this.templatesLoaded) return;

      try {
        const { data } = await fetchOrbitTemplates();
        this.templates = data;
        this.templatesLoaded = true;
        this.selectDefaultTemplate();
      } catch (err) {
        createAlert({
          message: err.message || s__('Orbit|Failed to load query templates.'),
        });
      }
    },
    selectDefaultTemplate() {
      if (this.selectedTemplate || !this.isQueryEmpty) return;

      const [firstTemplate] = this.templates;
      if (firstTemplate) this.onTemplateSelect(firstTemplate.name);
    },
    clearQuery() {
      this.queryText = {};
      this.selectedTemplate = null;
      this.aggregationRows = [];
      this.dismissQueryError();
    },
    dismissQueryError() {
      this.queryError = null;
      this.queryErrorDetails = null;
    },
    onTemplateSelect(value) {
      const template = this.templates.find((t) => t.name === value);
      this.selectedTemplate = value;
      this.queryText = template?.raw_query || '';
      this.dismissQueryError();
    },
    onQueryChange(value) {
      // The editor re-emits programmatic value updates (template select,
      // instance-map queries); only a genuine edit deselects the template.
      if (value !== this.stringifiedQueryText) {
        this.selectedTemplate = null;
      }
      try {
        this.queryText = JSON.parse(value);
      } catch {
        this.queryText = value;
      }
    },
    parseQuery() {
      if (typeof this.queryText === 'object' && this.queryText !== null) {
        return this.queryText;
      }
      try {
        return JSON.parse(this.queryText);
      } catch {
        this.queryError = s__('Orbit|Invalid JSON query. Please check the syntax.');
        this.queryErrorDetails = null;
        return null;
      }
    },
    async executeCurrentQuery() {
      this.dismissQueryError();

      let request;
      if (this.selectedTemplate) {
        request = () => executeOrbitNamedQuery(this.selectedTemplate);
      } else {
        const parsedQuery = this.parseQuery();
        if (!parsedQuery) return;
        request = () => executeOrbitQuery(parsedQuery);
      }

      this.trackEvent('click_orbit_execute_query');
      this.loading = true;
      try {
        const { data } = await request();
        this.expandedNodeIds = {};
        this.selectedNode = null;

        const result = data?.result || {};
        const { nodes, edges } = transformGraphResponse(result, this.nodeStyleMap);
        this.nodes = nodes;
        this.edges = edges;
        this.aggregationRows = aggregationRowsToTable(result.rows);

        if (nodes.length > 0) {
          this.$nextTick(() => {
            this.$refs.graphCanvas?.setFullData();
          });
        }
      } catch (err) {
        const status = err.response?.status;
        const serverMessage = err.response?.data?.message || err.message || null;
        const isValidation = status >= 400 && status < 500;
        this.queryError = isValidation
          ? s__('Orbit|Invalid query. Check query parameters and try again.')
          : s__('Orbit|Failed to execute query. Please try again.');
        this.queryErrorDetails = isValidation ? serverMessage : null;
      } finally {
        this.loading = false;
      }
    },
    onNodeSelect(node) {
      this.trackEvent('click_orbit_map_node', { label: this.mapMode });
      this.selectedNode = node;
      this.hintDismissed = true;
    },
    onNodeHover(node, position) {
      this.hoveredNode = node;
      this.hoveredPosition = position;
    },
    onNodeExpand(node) {
      this.trackEvent('click_orbit_expand_map_node', { label: this.mapMode });
      this.expandNode(node);
    },
    closeSidebar() {
      this.selectedNode = null;
    },
    resolveEntityType(lowercaseType) {
      return this.entityNames[lowercaseType] || ENTITY_TYPE_NAMES[lowercaseType] || lowercaseType;
    },
    async expandNode(node) {
      if (this.expandedNodeIds[node.id]) return;

      const entityType = this.resolveEntityType(node.type || 'user');
      const numericId = Number(node.properties?.id);
      if (!Number.isFinite(numericId)) return;

      this.loading = true;
      this.$refs.graphCanvas?.setNodeLoading(node.index, true);
      try {
        const { data } = await executeOrbitNamedQuery(NAMED_QUERY_EXPAND_NEIGHBORS, {
          parameters: { entity: entityType, node_ids: [numericId], limit: EXPAND_NEIGHBOR_LIMIT },
        });

        const response = data.result || {};
        const canvas = this.$refs.graphCanvas;
        const graphNodes = this.nodes;
        const { newNodes, newEdges } = mergeNeighborNodes(response, graphNodes, this.nodeStyleMap);

        if (newNodes.length > 0) {
          this.nodes = [...this.nodes, ...newNodes];
          this.edges = [...this.edges, ...newEdges];
          canvas?.addData(newNodes, newEdges);
        }

        this.expandedNodeIds = { ...this.expandedNodeIds, [node.id]: true };
      } catch (err) {
        createAlert({
          message: err.message || s__('Orbit|Failed to expand node neighbors.'),
        });
      } finally {
        this.loading = false;
        this.$refs.graphCanvas?.setNodeLoading(node.index, false);
      }
    },
    onRowClick(row) {
      if (!row.type || row.id === undefined) return;

      const graphId = toGraphId(row.type, row.id);
      const match = this.nodes.find((n) => n.id === graphId);
      if (!match) {
        createAlert({ message: s__('Orbit|Could not locate the selected node in the graph.') });
        return;
      }
      this.selectedNode = match;
    },
    zoomIn() {
      this.$refs.graphCanvas?.zoomIn();
    },
    zoomOut() {
      this.$refs.graphCanvas?.zoomOut();
    },
    onLegendTypeSelect(type) {
      const isSolo = this.highlightedTypes.size === 1 && this.highlightedTypes.has(type);
      if (isSolo) {
        this.highlightedTypes = new Set();
        return;
      }
      this.trackEvent('click_orbit_highlight_legend_type', { label: type });
      const updated = new Set();
      updated.add(type);
      this.highlightedTypes = updated;
    },
    restoreInitialGraph() {
      this.searchQuery = '';
      this.nodes = this.initialNodes;
      this.edges = this.initialEdges;
      this.expandedNodeIds = {};
      this.selectedNode = null;
      this.$nextTick(() => {
        this.$refs.graphCanvas?.setFullData();
        this.autoExpandInitialNodes();
      });
    },
    onClearFilters() {
      this.restoreInitialGraph();
      this.$emit('close-filter');
    },
    async executeGraphSearch({ text, field }) {
      const activeType = this.activeTypeFilters.size === 1 ? [...this.activeTypeFilters][0] : null;
      if (!activeType) return;

      const entityName = this.resolveEntityType(activeType);
      await this.executeInstanceMapQuery({
        entityType: entityName,
        filters: { [field]: text },
      });
    },
    async executeInstanceMapQuery({ entityType, filters = {} }) {
      const nodeFilters = {};
      for (const [key, value] of Object.entries(filters)) {
        if (Array.isArray(value)) {
          nodeFilters[key] = { op: 'in', value };
        } else if (typeof value === 'string') {
          nodeFilters[key] = { op: 'contains', value };
        } else {
          nodeFilters[key] = { op: 'eq', value };
        }
      }

      // GKG rejects traversal queries without selectivity. When the caller
      // doesn't provide a filter (e.g. "Show in Map" from the schema page),
      // fall back to `id > 0` which (a) passes the selectivity check and
      // (b) matches every row regardless of how the backend numbers ids.
      // id_range was tried first but its 100k span misses entities like
      // MergeRequest where ids start at 1_000_000+.
      const effectiveFilters =
        Object.keys(nodeFilters).length > 0 ? nodeFilters : { id: { op: 'gt', value: 0 } };

      const query = {
        query_type: 'traversal',
        node: {
          id: 'n',
          entity: entityType,
          columns: '*',
          filters: effectiveFilters,
        },
        limit: 50,
      };

      this.selectedTemplate = null;
      this.queryText = query;
      await this.executeCurrentQuery();
    },
  },
});
</script>

<template>
  <div data-testid="graph-explorer" class="gl-flex gl-flex-col gl-gap-5">
    <!-- Advanced panel (query editor) -->
    <explorer-query-panel
      v-if="advancedOpen"
      :query-text="stringifiedQueryText"
      :loading="loading"
      :template-items="templateItems"
      :selected-template="selectedTemplate"
      :error-message="queryError"
      :error-details="queryErrorDetails"
      @update:query-text="onQueryChange"
      @execute="executeCurrentQuery"
      @clear="clearQuery"
      @close="$emit('close-query')"
      @template-select="onTemplateSelect"
      @dismiss-error="dismissQueryError"
    />

    <graph-filter-bar
      v-if="filterOpen"
      :search-query="searchQuery"
      :legend-items="legendItems"
      :active-type-filters="activeTypeFilters"
      :schema-nodes="schemaNodes"
      @update-search-query="searchQuery = $event"
      @update-active-type-filters="$emit('update-active-type-filters', $event)"
      @search-graph="executeGraphSearch"
      @clear-filters="onClearFilters"
    />

    <explorer-table-panel
      v-if="view === $options.TAB_TABLE"
      :rows="tableRows"
      :loading="loading"
      class="gl-min-w-0 gl-flex-1"
      @row-click="onRowClick"
    />

    <div
      v-else
      class="orbit-graph-container gl-flex gl-min-w-0 gl-flex-1 gl-flex-col gl-overflow-hidden gl-rounded-lg"
    >
      <div class="gl-flex gl-min-h-0 gl-flex-1 gl-flex-col">
        <!-- Globe viewport -->
        <div
          class="gl-relative gl-min-h-0 gl-flex-1 gl-overflow-hidden"
          @mousedown="hintDismissed = true"
        >
          <!-- Legend overlay (bottom-left) -->
          <div
            class="gl-pointer-events-none gl-absolute gl-bottom-3 gl-left-3 gl-top-3 gl-z-3 gl-flex gl-flex-col gl-justify-end"
            data-testid="graph-legend-panel"
          >
            <graph-legend
              class="gl-pointer-events-auto gl-min-h-0"
              :items="legendItems"
              :active-type-filters="highlightedTypes"
              is-compact
              :labels-visible="labelsVisible"
              @select-type="onLegendTypeSelect"
              @update-labels-visible="labelsVisible = $event"
              @zoom-in="zoomIn"
              @zoom-out="zoomOut"
            />
          </div>

          <!-- Expand handled by parent panel -->
          <gl-loading-icon v-if="loading && nodes.length === 0" size="lg" class="gl-mt-20" />

          <graph-canvas
            v-else
            ref="graphCanvas"
            :nodes="nodes"
            :edges="edges"
            :selected-node-id="selectedNodeId"
            :node-style-map="nodeStyleMap"
            :dark-mode="$options.isDarkMode"
            :map-mode="mapMode"
            :labels-visible="labelsVisible"
            @node-select="onNodeSelect"
            @node-hover="onNodeHover"
            @node-expand="onNodeExpand"
          />

          <node-detail-overlay
            :node="hoveredNode"
            :position="hoveredPosition"
            :entity-colors="entityColors"
            :entity-names="entityNames"
            :all-nodes="nodes"
          />

          <explorer-node-sidebar
            v-if="selectedNode"
            :node="selectedNode"
            :entity-colors="entityColors"
            :entity-names="entityNames"
            @close="closeSidebar"
          />
        </div>
      </div>
    </div>
  </div>
</template>
