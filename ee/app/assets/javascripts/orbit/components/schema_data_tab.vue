<script>
import { defineComponent } from 'vue';
import {
  GlBadge,
  GlButton,
  GlCollapse,
  GlIcon,
  GlLoadingIcon,
  GlSearchBoxByType,
  GlTooltipDirective,
} from '@gitlab/ui';
import { forceSimulation, forceLink, forceManyBody, forceCenter, forceCollide } from 'd3';
import iconsPath from '@gitlab/svgs/dist/icons.svg';
// s__ resolves through Vue's translate mixin in the template; eslint can't see it.
// eslint-disable-next-line no-unused-vars
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import { ENTITY_TYPE_ICONS, DEFAULT_NODE_COLOR } from '../constants';
import { buildNodeStyleMap } from '../utils/node_style_map';
import { buildNodeDomainMap, buildDomainColorMap, resolveNodeColor } from '../utils/schema_mappers';

const R_BASE = 26;
const R_MAX = 40;
const PAD = 80;
const DOMAIN_PAD = 30;
const DOMAIN_LABEL_OFFSET = 18;

const HIER_Y = {
  group: -220,
  project: -100,
  user: -100,
  mergerequest: 20,
  workitem: 20,
  pipeline: 20,
  note: 20,
  milestone: 100,
  label: 100,
  vulnerability: 140,
  stage: 140,
  mergerequestdiff: 140,
  branch: 140,
  vulnerabilityoccurrence: 220,
  finding: 220,
  securityscan: 220,
  job: 220,
  mergerequestdifffile: 220,
  directory: 220,
  vulnerabilityscanner: 300,
  vulnerabilityidentifier: 300,
  file: 300,
  definition: 380,
  importedsymbol: 380,
};
const DOMAIN_X = {
  core: -200,
  code_review: -30,
  plan: 140,
  ci: 300,
  security: -380,
  source_code: 480,
};
const DOMAIN_ORDER = ['core', 'code_review', 'plan', 'ci', 'security', 'source_code'];

export default defineComponent({
  name: 'SchemaDataTab',
  compatConfig: { MODE: 3 },
  entityIcons: ENTITY_TYPE_ICONS,
  components: { GlBadge, GlButton, GlCollapse, GlIcon, GlLoadingIcon, GlSearchBoxByType },
  directives: { GlTooltip: GlTooltipDirective },
  mixins: [InternalEvents.mixin()],
  props: {
    schema: {
      type: Object,
      required: false,
      default: null,
    },
    graphStats: {
      type: Object,
      required: false,
      default: null,
    },
    initialEntity: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['show-instances'],
  data() {
    return {
      selectedNode: null,
      selectedEdge: null,
      filterQuery: '',
      nodeStyleMap: {},
      graphNodes: [],
      graphLinks: [],
      svgViewBox: [-500, -350, 1000, 750],
      vbBase: null,
      zoomLevel: 1,
      dragTarget: null,
      didDrag: false,
      dragStart: null,
      panStart: null,
      panVbStart: null,
      savedViewBox: null,
      savedZoomLevel: null,
      hoveredLinkKey: null,
      nodesOpen: true,
      relationshipsOpen: true,
      navPanelWidth: 300,
      resizing: false,
      resizeStartX: 0,
      resizeStartWidth: 0,
    };
  },
  computed: {
    loading() {
      return !this.schema;
    },
    nodeDomainMap() {
      return buildNodeDomainMap(this.schema?.nodes);
    },
    domainColorMap() {
      return buildDomainColorMap(this.schema?.nodes, this.nodeStyleMap);
    },
    allNodes() {
      return this.schema?.nodes || [];
    },
    allEdges() {
      return this.schema?.edges || [];
    },
    nodeMap() {
      const m = {};
      for (const n of this.graphNodes) m[n.id] = n;
      return m;
    },
    domainBounds() {
      const byDomain = {};
      for (const n of this.graphNodes) {
        if (!byDomain[n.domain]) byDomain[n.domain] = [];
        byDomain[n.domain].push(n);
      }
      return Object.entries(byDomain).map(([domain, dns]) => {
        let x0 = Infinity;
        let y0 = Infinity;
        let x1 = -Infinity;
        let y1 = -Infinity;
        for (const n of dns) {
          x0 = Math.min(x0, n.x - n.r - DOMAIN_PAD);
          y0 = Math.min(y0, n.y - n.r - DOMAIN_PAD);
          x1 = Math.max(x1, n.x + n.r + DOMAIN_PAD);
          y1 = Math.max(y1, n.y + n.r + DOMAIN_PAD);
        }
        const color = this.domainColorMap[domain] || DEFAULT_NODE_COLOR;
        return {
          domain,
          x: x0,
          y: y0 - DOMAIN_LABEL_OFFSET,
          w: x1 - x0,
          h: y1 - y0 + DOMAIN_LABEL_OFFSET,
          color,
        };
      });
    },
    connectedNodeIds() {
      if (!this.selectedNode) return null;
      const ids = new Set([this.selectedNode]);
      for (const l of this.graphLinks) {
        if (l.sourceId === this.selectedNode) ids.add(l.targetId);
        if (l.targetId === this.selectedNode) ids.add(l.sourceId);
      }
      return ids;
    },
    activeEdgeIds() {
      if (!this.selectedEdge) return null;
      const e = this.allEdges.find((x) => x.name === this.selectedEdge);
      if (!e) return null;
      const pairs = new Set();
      for (const v of e.variants || []) {
        pairs.add(`${v.source_type}::${v.target_type}`);
        pairs.add(`${v.target_type}::${v.source_type}`);
      }
      return pairs;
    },
    visibleEdgeLabels() {
      if (!this.selectedNode && !this.selectedEdge && !this.hoveredLinkKey) return [];
      if (!this.graphLinks.length) return [];
      const spacing = 14;
      return this.graphLinks
        .filter((l) => this.isLinkHighlighted(l) || this.linkKey(l) === this.hoveredLinkKey)
        .flatMap((l) => {
          const src = this.nodeMap[l.sourceId];
          const tgt = this.nodeMap[l.targetId];
          if (!src || !tgt) return [];
          const pt = this.arcMidpoint(src, tgt);
          const startOffset = -((l.labels.length - 1) * spacing) / 2;
          return l.labels.map((text, j) => ({
            x: pt.x,
            y: pt.y + startOffset + j * spacing,
            text,
            w: text.length * 4.5,
          }));
        });
    },
    nodesByDomain() {
      const g = {};
      for (const n of this.allNodes) {
        const d = n.domain || 'other';
        if (!g[d]) g[d] = [];
        g[d].push(n);
      }
      return DOMAIN_ORDER.filter((d) => g[d]).map((d) => [d, g[d]]);
    },
    filteredNodesByDomain() {
      const q = this.filterQuery.toLowerCase().trim();
      return this.nodesByDomain
        .map(([domain, nodes]) => {
          let filtered = nodes;
          if (q) {
            filtered = filtered.filter(
              (n) => n.name.toLowerCase().includes(q) || domain.includes(q),
            );
          }
          return [domain, filtered];
        })
        .filter(([, fns]) => fns.length > 0);
    },
    filteredEdges() {
      const q = this.filterQuery.toLowerCase().trim();
      let edges = this.allEdges;
      if (q) {
        edges = edges.filter((e) => e.name.toLowerCase().includes(q));
      }
      return edges;
    },
    connectedNodes() {
      if (!this.connectedNodeIds) return [];
      return this.allNodes.filter(
        (n) => n.name !== this.selectedNode && this.connectedNodeIds.has(n.name),
      );
    },
    edgeRelatedNodes() {
      if (!this.detailEdge) return [];
      const names = new Set();
      for (const v of this.detailEdge.variants || []) {
        names.add(v.source_type);
        names.add(v.target_type);
      }
      return this.allNodes.filter((n) => names.has(n.name));
    },
    detailNode() {
      return this.selectedNode ? this.allNodes.find((n) => n.name === this.selectedNode) : null;
    },
    detailEdge() {
      return this.selectedEdge ? this.allEdges.find((e) => e.name === this.selectedEdge) : null;
    },
    svgViewBoxStr() {
      return this.svgViewBox.join(' ');
    },
  },
  watch: {
    schema: {
      handler(val) {
        if (val) {
          this.zoomLevel = 1;
          this.vbBase = null;
          this.selectedNode = null;
          this.selectedEdge = null;
          this.savedViewBox = null;
          this.savedZoomLevel = null;
          this.nodeStyleMap = buildNodeStyleMap(val.nodes);
          this.buildGraph();
          this.applyInitialEntity();
        }
      },
      immediate: true,
    },
    initialEntity() {
      this.applyInitialEntity();
    },
  },
  mounted() {
    this.$nextTick(() => {
      this.fitViewBox();
    });
    window.addEventListener('resize', this.onWindowResize);
  },
  beforeUnmount() {
    this.teardownDocumentListeners();
    window.removeEventListener('resize', this.onWindowResize);
  },
  methods: {
    onWindowResize() {
      this.fitViewBox();
    },
    buildGraph() {
      const degree = this.countNodeDegrees();
      const nodes = this.seedNodes(degree);
      const links = this.buildLinks(nodes);

      this.runSimulation(nodes, links);

      this.graphNodes = this.normalizeNodes(nodes);
      this.graphLinks = this.toRenderableLinks(links);

      this.fitViewBox();
    },
    countNodeDegrees() {
      const counts = {};
      for (const e of this.allEdges) {
        for (const v of e.variants || []) {
          counts[v.source_type] = (counts[v.source_type] || 0) + 1;
          counts[v.target_type] = (counts[v.target_type] || 0) + 1;
        }
      }
      return counts;
    },
    seedNodes(degree) {
      return this.allNodes.map((n) => {
        const k = n.name.toLowerCase();
        return {
          id: n.name,
          icon: ENTITY_TYPE_ICONS[k] || null,
          color: this.nodeColor(n),
          count: this.nodeCount(n.name),
          domain: n.domain,
          r: Math.min(R_MAX, R_BASE + (degree[n.name] || 0) * 1.2),
          x: (DOMAIN_X[n.domain] ?? 0) + (Math.random() - 0.5) * 40,
          y: (HIER_Y[k] ?? 0) + (Math.random() - 0.5) * 15,
        };
      });
    },
    buildLinks(nodes) {
      const nodeIds = new Set(nodes.map((n) => n.id));
      const linkMap = new Map();
      for (const e of this.allEdges) {
        for (const v of e.variants || []) {
          if (nodeIds.has(v.source_type) && nodeIds.has(v.target_type)) {
            const key =
              v.source_type === v.target_type
                ? `${v.source_type}::self`
                : [v.source_type, v.target_type].sort().join('::');
            if (!linkMap.has(key)) {
              linkMap.set(key, { source: v.source_type, target: v.target_type, labels: [e.name] });
            } else if (!linkMap.get(key).labels.includes(e.name)) {
              linkMap.get(key).labels.push(e.name);
            }
          }
        }
      }
      return [...linkMap.values()];
    },
    runSimulation(nodes, links) {
      try {
        const sim = forceSimulation(nodes)
          .force(
            'link',
            forceLink(links)
              .id((d) => d.id)
              .distance(160),
          )
          .force('charge', forceManyBody().strength(-600))
          .force('center', forceCenter(0, 50))
          .force(
            'collide',
            forceCollide((d) => d.r + 16),
          )
          .stop();
        for (let i = 0; i < 300; i += 1) {
          for (const n of nodes) {
            n.vy += ((HIER_Y[n.id.toLowerCase()] ?? 0) - n.y) * 0.02;
            n.vx += ((DOMAIN_X[n.domain] ?? 0) - n.x) * 0.008;
          }
          sim.tick();
        }
      } catch {
        // fall back to seeded positions on simulation failure
      }
    },
    normalizeNodes(nodes) {
      return nodes.map((n) => ({
        id: n.id,
        icon: n.icon,
        color: n.color,
        count: n.count,
        domain: n.domain,
        r: n.r,
        x: Number.isFinite(n.x) ? n.x : 0,
        y: Number.isFinite(n.y) ? n.y : 0,
      }));
    },
    toRenderableLinks(links) {
      return links
        .map((l) => {
          const sId = l.source?.id ?? l.source;
          const tId = l.target?.id ?? l.target;
          if (!this.nodeMap[sId] || !this.nodeMap[tId]) return null;
          return { labels: l.labels, sourceId: sId, targetId: tId };
        })
        .filter(Boolean);
    },
    fitViewBox() {
      if (!this.graphNodes.length) return;
      let x0 = Infinity;
      let y0 = Infinity;
      let x1 = -Infinity;
      let y1 = -Infinity;
      for (const b of this.domainBounds) {
        x0 = Math.min(x0, b.x);
        y0 = Math.min(y0, b.y);
        x1 = Math.max(x1, b.x + b.w);
        y1 = Math.max(y1, b.y + b.h);
      }
      let cx = x0 - PAD;
      let cy = y0 - PAD;
      let cw = x1 - x0 + PAD * 2;
      let ch = y1 - y0 + PAD * 2;

      // Expand the shorter dimension so the viewBox matches the panel's aspect
      // ratio. With preserveAspectRatio="xMidYMid meet" this makes the graph
      // fill the panel in both directions and stay centered.
      const svg = this.$refs.svgEl;
      const rect = svg && svg.getBoundingClientRect();
      if (rect && rect.width > 0 && rect.height > 0) {
        const panelAspect = rect.width / rect.height;
        const contentAspect = cw / ch;
        if (panelAspect > contentAspect) {
          const newW = ch * panelAspect;
          cx -= (newW - cw) / 2;
          cw = newW;
        } else {
          const newH = cw / panelAspect;
          cy -= (newH - ch) / 2;
          ch = newH;
        }
      }

      const newBase = [cx, cy, cw, ch];

      if (this.zoomLevel === 1 || !this.vbBase) {
        // Unzoomed or initial fit: snap to the full fitted view.
        this.svgViewBox = newBase;
        this.vbBase = newBase;
        this.zoomLevel = 1;
      } else {
        // Zoomed/panned: update the base for the new aspect ratio but keep the
        // user's current zoom level centered on the same graph-space point.
        const [vx, vy, vw, vh] = this.svgViewBox;
        const centerX = vx + vw / 2;
        const centerY = vy + vh / 2;
        const newW = cw / this.zoomLevel;
        const newH = ch / this.zoomLevel;
        this.vbBase = newBase;
        this.svgViewBox = [centerX - newW / 2, centerY - newH / 2, newW, newH];
      }
    },
    resetView() {
      this.zoomLevel = 1;
      this.fitViewBox();
    },
    svgPoint(e) {
      const svg = this.$refs.svgEl;
      if (!svg) return null;
      const pt = svg.createSVGPoint();
      pt.x = e.clientX;
      pt.y = e.clientY;
      const ctm = svg.getScreenCTM();
      if (!ctm) return null;
      return pt.matrixTransform(ctm.inverse());
    },
    onWheel(e) {
      e.preventDefault();
      if (!this.vbBase) return;
      // Zoom toward the cursor so the point under the pointer stays put,
      // instead of snapping toward the viewBox center.
      const pt = this.svgPoint(e);
      const [vx, vy, vw, vh] = this.svgViewBox;
      const anchorX = pt ? pt.x : vx + vw / 2;
      const anchorY = pt ? pt.y : vy + vh / 2;

      const factor = e.deltaY < 0 ? 0.93 : 1.07; // scroll up = zoom in (smaller viewBox)
      const baseW = this.vbBase[2];
      let newW = vw * factor;
      const minW = baseW / 5;
      const maxW = baseW / 0.3;
      newW = Math.max(minW, Math.min(maxW, newW));
      const ratio = newW / vw;
      const newH = vh * ratio;

      const fx = (anchorX - vx) / vw;
      const fy = (anchorY - vy) / vh;
      this.svgViewBox = [anchorX - fx * newW, anchorY - fy * newH, newW, newH];
      this.zoomLevel = baseW / newW;
    },
    onNodeMousedown(e, node) {
      e.stopPropagation();
      this.dragTarget = node;
      this.didDrag = false;
      this.dragStart = { cx: e.clientX, cy: e.clientY };
    },
    clientToSvgScale() {
      const svg = this.$refs.svgEl;
      if (!svg) return 1;
      const rect = svg.getBoundingClientRect();
      return this.svgViewBox[2] / rect.width;
    },
    onSvgMousedown(e) {
      this.panStart = { cx: e.clientX, cy: e.clientY };
      this.panVbStart = [...this.svgViewBox];
    },
    onSvgMousemove(e) {
      const scale = this.clientToSvgScale();
      if (this.dragTarget) {
        // Require a small movement before treating this as a drag, so a plain
        // click selects the node without nudging it around.
        if (!this.didDrag && this.dragStart) {
          const moved = Math.hypot(e.clientX - this.dragStart.cx, e.clientY - this.dragStart.cy);
          if (moved < 5) return;
        }
        const pt = this.svgPoint(e);
        if (!pt) return;
        this.dragTarget.x = pt.x;
        this.dragTarget.y = pt.y;
        this.didDrag = true;
        return;
      }
      if (this.panStart) {
        const dx = (this.panStart.cx - e.clientX) * scale;
        const dy = (this.panStart.cy - e.clientY) * scale;
        const [vx, vy, vw, vh] = this.panVbStart;
        this.svgViewBox = [vx + dx, vy + dy, vw, vh];
      }
    },
    onSvgMouseup() {
      this.dragTarget = null;
      this.dragStart = null;
      this.panStart = null;
      this.panVbStart = null;
    },
    arcMidpoint(src, tgt) {
      if (src.id === tgt.id) {
        return { x: src.x + src.r * 0.7 + 40, y: src.y };
      }
      const mx = (src.x + tgt.x) / 2;
      const my = (src.y + tgt.y) / 2;
      const dx = tgt.x - src.x;
      const dy = tgt.y - src.y;
      const chord = Math.sqrt(dx * dx + dy * dy);
      if (chord < 1) return { x: mx, y: my };
      const r = chord * 0.8;
      const halfChord = chord / 2;
      const sagitta = halfChord < r ? r - Math.sqrt(r * r - halfChord * halfChord) : 0;
      const nx = dy / chord;
      const ny = -dx / chord;
      return { x: mx + nx * sagitta, y: my + ny * sagitta };
    },
    arcPath(link) {
      const src = this.nodeMap[link.sourceId];
      const tgt = this.nodeMap[link.targetId];
      if (!src || !tgt) return '';
      if (link.sourceId === link.targetId) {
        const lo = 20;
        const x1 = src.x + src.r * 0.7;
        const y1 = src.y - src.r * 0.7;
        const x2 = src.x + src.r * 0.7;
        const y2 = src.y + src.r * 0.7;
        return `M${x1},${y1}C${x1 + lo * 2},${y1 - lo},${x2 + lo * 2},${y2 + lo},${x2},${y2}`;
      }
      const dx = tgt.x - src.x;
      const dy = tgt.y - src.y;
      const dr = Math.sqrt(dx * dx + dy * dy) * 0.8;
      if (dr < 1) return `M${src.x},${src.y}L${tgt.x},${tgt.y}`;
      return `M${src.x},${src.y}A${dr},${dr} 0 0,1 ${tgt.x},${tgt.y}`;
    },
    iconHref(name) {
      return `${iconsPath}#${name}`;
    },
    nodeColor(node) {
      return resolveNodeColor(node.name, {
        nodeStyleMap: this.nodeStyleMap,
        domainColorMap: this.domainColorMap,
        nodeDomainMap: this.nodeDomainMap,
      });
    },
    nodeCount(name) {
      return this.graphStats?.[name.toLowerCase()] ?? null;
    },
    fmtCount(n) {
      return n == null ? '' : Number(n).toLocaleString();
    },
    saveCurrentView() {
      this.savedViewBox = [...this.svgViewBox];
      this.savedZoomLevel = this.zoomLevel;
    },
    restoreSavedView() {
      if (!this.savedViewBox) return;
      this.svgViewBox = this.savedViewBox;
      this.zoomLevel = this.savedZoomLevel;
      this.savedViewBox = null;
      this.savedZoomLevel = null;
    },
    zoomToSelection() {
      if (!this.connectedNodeIds) return;
      const nodes = this.graphNodes.filter((n) => this.connectedNodeIds.has(n.id));
      if (!nodes.length) return;

      // Label text extends ~24px below node bottom; add a fixed pad so labels are visible.
      const LABEL_PAD = 28;
      let x0 = Infinity;
      let y0 = Infinity;
      let x1 = -Infinity;
      let y1 = -Infinity;
      for (const n of nodes) {
        x0 = Math.min(x0, n.x - n.r);
        y0 = Math.min(y0, n.y - n.r);
        x1 = Math.max(x1, n.x + n.r);
        y1 = Math.max(y1, n.y + n.r + LABEL_PAD);
      }

      const contentW = x1 - x0;
      const contentH = y1 - y0;
      const pad = Math.max(30, contentW * 0.15, contentH * 0.15);
      let cx = x0 - pad;
      let cy = y0 - pad;
      let cw = contentW + pad * 2;
      let ch = contentH + pad * 2;

      // Match panel aspect ratio to avoid letterboxing.
      const svg = this.$refs.svgEl;
      const rect = svg && svg.getBoundingClientRect();
      if (rect && rect.width > 0 && rect.height > 0) {
        const panelAspect = rect.width / rect.height;
        const contentAspect = cw / ch;
        if (panelAspect > contentAspect) {
          const newW = ch * panelAspect;
          cx -= (newW - cw) / 2;
          cw = newW;
        } else {
          const newH = cw / panelAspect;
          cy -= (newH - ch) / 2;
          ch = newH;
        }
      }

      this.svgViewBox = [cx, cy, cw, ch];
      this.zoomLevel = this.vbBase ? this.vbBase[2] / cw : 1;
    },
    selectNode(id) {
      if (this.didDrag) {
        this.didDrag = false;
        return;
      }
      if (this.selectedNode !== id) {
        this.trackEvent('click_orbit_schema_item', { label: 'entity' });
      }
      this.selectedEdge = null;
      if (this.selectedNode === id) {
        this.selectedNode = null;
        this.restoreSavedView();
      } else {
        if (!this.selectedNode) this.saveCurrentView();
        this.selectedNode = id;
        this.zoomToSelection();
      }
    },
    selectEdge(name) {
      if (this.selectedEdge !== name) {
        this.trackEvent('click_orbit_schema_item', { label: 'relationship' });
      }
      this.selectedNode = null;
      this.selectedEdge = this.selectedEdge === name ? null : name;
    },
    linkKey(link) {
      return `${link.sourceId}::${link.targetId}`;
    },
    applyInitialEntity() {
      if (!this.initialEntity) return;
      const target = this.allNodes.find(
        (n) => n.name.toLowerCase() === this.initialEntity.toLowerCase(),
      );
      if (target) {
        this.selectedEdge = null;
        this.selectedNode = target.name;
      }
    },
    onResizeStart(e) {
      this.resizing = true;
      this.resizeStartX = e.clientX;
      this.resizeStartWidth = this.navPanelWidth;
      document.addEventListener('mousemove', this.onResizeMove);
      document.addEventListener('mouseup', this.onResizeEnd);
    },
    onResizeMove(e) {
      if (!this.resizing) return;
      const delta = e.clientX - this.resizeStartX;
      this.navPanelWidth = Math.max(200, Math.min(500, this.resizeStartWidth + delta));
    },
    onResizeEnd() {
      this.resizing = false;
      document.removeEventListener('mousemove', this.onResizeMove);
      document.removeEventListener('mouseup', this.onResizeEnd);
    },
    teardownDocumentListeners() {
      document.removeEventListener('mousemove', this.onResizeMove);
      document.removeEventListener('mouseup', this.onResizeEnd);
    },
    isLinkHighlighted(link) {
      const touchesNode =
        !this.selectedNode ||
        link.sourceId === this.selectedNode ||
        link.targetId === this.selectedNode;
      if (this.activeEdgeIds) {
        return touchesNode && this.activeEdgeIds.has(`${link.sourceId}::${link.targetId}`);
      }
      if (this.selectedNode) {
        return link.sourceId === this.selectedNode || link.targetId === this.selectedNode;
      }
      return false;
    },
    linkOpacity(link) {
      if (!this.selectedNode && !this.selectedEdge) return 0.15;
      return this.isLinkHighlighted(link) ? 0.5 : 0.03;
    },
    isNodeDimmed(id) {
      if (!this.selectedNode && !this.selectedEdge) return false;
      const ids = new Set();
      for (const l of this.graphLinks) {
        if (this.isLinkHighlighted(l)) {
          ids.add(l.sourceId);
          ids.add(l.targetId);
        }
      }
      if (this.selectedNode) ids.add(this.selectedNode);
      return !ids.has(id);
    },
    nodeRelationships(name) {
      const r = [];
      for (const e of this.allEdges) {
        for (const v of e.variants || []) {
          if (v.source_type === name || v.target_type === name) {
            r.push({
              name: e.name,
              dir: v.source_type === name ? 'outgoing' : 'incoming',
              other: v.source_type === name ? v.target_type : v.source_type,
            });
          }
        }
      }
      return r;
    },
    groupedNodeRelationships(name) {
      const rels = this.nodeRelationships(name);
      const grouped = new Map();
      for (const r of rels) {
        const key = `${r.dir}::${r.name}`;
        if (!grouped.has(key)) {
          grouped.set(key, { name: r.name, dir: r.dir, others: [] });
        }
        grouped.get(key).others.push(r.other);
      }
      return [...grouped.values()];
    },
  },
});
</script>

<template>
  <div class="gl-flex gl-min-h-0 gl-flex-1 gl-flex-col" data-testid="schema-data-tab">
    <gl-loading-icon v-if="loading" size="lg" class="gl-my-6" />

    <div
      v-else-if="schema"
      class="gl-flex gl-min-h-0 gl-flex-1 gl-flex-col gl-gap-y-5 gl-overflow-auto lg:gl-flex-row lg:gl-gap-y-0 lg:gl-overflow-hidden"
    >
      <!-- Left panel: Navigation / Filters -->
      <div
        class="orbit-nav-panel gl-flex gl-shrink-0 gl-flex-col lg:gl-overflow-hidden"
        :style="{ '--nav-panel-width': navPanelWidth + 'px' }"
      >
        <div class="gl-mb-3 gl-shrink-0 gl-px-2 gl-pt-2">
          <gl-search-box-by-type
            :value="filterQuery"
            :placeholder="s__('Orbit|Search entities and relationships')"
            @input="filterQuery = $event"
          />
        </div>

        <div
          class="gl-flex gl-min-h-0 gl-flex-1 gl-flex-col gl-gap-5 gl-overflow-y-auto gl-overflow-x-hidden gl-p-2"
        >
          <div>
            <gl-button
              class="gl-mb-3"
              size="small"
              category="tertiary"
              :icon="nodesOpen ? 'chevron-down' : 'chevron-right'"
              @click="nodesOpen = !nodesOpen"
            >
              {{ s__('Orbit|Entities') }}
            </gl-button>
            <gl-collapse :visible="nodesOpen" class="gl-pl-4">
              <div
                v-for="[domain, domainNodes] in filteredNodesByDomain"
                :key="domain"
                class="gl-mb-3"
              >
                <p class="gl-mb-1 gl-mt-0 gl-text-sm gl-text-subtle">{{ domain }}</p>
                <div class="gl-flex gl-flex-wrap gl-gap-3">
                  <button
                    v-for="node in domainNodes"
                    :key="node.name"
                    type="button"
                    class="gl-flex gl-cursor-pointer gl-items-center gl-gap-2 gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-px-2 gl-py-1 gl-text-sm"
                    :class="
                      selectedNode === node.name ? 'gl-bg-strong gl-font-bold' : 'gl-bg-default'
                    "
                    :data-testid="`schema-entity-${node.name}`"
                    @click="selectNode(node.name)"
                  >
                    <gl-icon
                      v-if="$options.entityIcons[node.name.toLowerCase()]"
                      :name="$options.entityIcons[node.name.toLowerCase()]"
                      :size="12"
                      :style="{ color: nodeColor(node) }"
                    />
                    <span
                      v-else
                      class="gl-inline-block gl-h-2 gl-w-2 gl-flex-shrink-0 gl-rounded-full"
                      :style="{ backgroundColor: nodeColor(node) }"
                    ></span>
                    {{ node.name }}
                  </button>
                </div>
              </div>
            </gl-collapse>
          </div>

          <div>
            <gl-button
              class="gl-mb-3"
              size="small"
              category="tertiary"
              :icon="relationshipsOpen ? 'chevron-down' : 'chevron-right'"
              @click="relationshipsOpen = !relationshipsOpen"
            >
              {{ s__('Orbit|Relationships') }}
            </gl-button>
            <gl-collapse :visible="relationshipsOpen" class="gl-pl-4">
              <div class="gl-flex gl-flex-wrap gl-gap-3">
                <button
                  v-for="edge in filteredEdges"
                  :key="edge.name"
                  type="button"
                  class="gl-border gl-rounded-base gl-px-2 gl-py-1 gl-text-sm"
                  :class="
                    selectedEdge === edge.name ? 'gl-bg-strong gl-font-bold' : 'gl-bg-default'
                  "
                  :data-testid="`schema-relationship-${edge.name}`"
                  @click="selectEdge(edge.name)"
                >
                  {{ edge.name }}
                </button>
              </div>
            </gl-collapse>
          </div>
        </div>
      </div>

      <!-- Resize handle -->
      <div
        class="orbit-resize-handle gl-hidden gl-shrink-0 gl-cursor-col-resize gl-items-center gl-justify-center lg:gl-flex"
        @mousedown.prevent="onResizeStart"
      >
        <div class="orbit-resize-line gl-h-full"></div>
      </div>

      <!-- Graph panel -->
      <div
        ref="graphPanel"
        class="orbit-graph-panel gl-relative gl-min-w-0 gl-flex-1 gl-overflow-hidden gl-rounded-lg gl-border-1 gl-border-solid gl-border-default gl-bg-subtle lg:gl-min-h-0"
        style="min-height: 24rem"
      >
        <gl-button
          v-if="zoomLevel !== 1"
          v-gl-tooltip
          size="small"
          category="secondary"
          icon="redo"
          class="gl-absolute gl-bottom-3 gl-left-3 gl-z-1"
          :title="s__('Orbit|Reset zoom')"
          :aria-label="s__('Orbit|Reset zoom')"
          data-testid="reset-view"
          @click="resetView"
        />
        <svg
          ref="svgEl"
          :viewBox="svgViewBoxStr"
          preserveAspectRatio="xMidYMid meet"
          class="gl-absolute gl-inset-0 gl-block"
          style="width: 100%; height: 100%"
          :style="{ cursor: dragTarget ? 'grabbing' : 'grab' }"
          @wheel.prevent="onWheel"
          @mousedown="onSvgMousedown"
          @mousemove="onSvgMousemove"
          @mouseup="onSvgMouseup"
          @mouseleave="onSvgMouseup"
        >
          <!-- Edges -->
          <g
            v-for="(link, i) in graphLinks"
            :key="'e' + i"
            class="gl-cursor-pointer"
            @click.stop="selectEdge(link.labels[0])"
            @mouseenter="hoveredLinkKey = linkKey(link)"
            @mouseleave="hoveredLinkKey = null"
          >
            <!-- invisible thick hit area -->
            <path
              :d="arcPath(link)"
              fill="none"
              stroke="transparent"
              stroke-width="14"
              stroke-linecap="round"
              pointer-events="stroke"
            />
            <!-- visible line -->
            <path
              :d="arcPath(link)"
              fill="none"
              stroke="currentColor"
              :stroke-opacity="linkKey(link) === hoveredLinkKey ? 0.7 : linkOpacity(link)"
              :stroke-width="isLinkHighlighted(link) || linkKey(link) === hoveredLinkKey ? 2 : 1"
              pointer-events="none"
            />
          </g>

          <!-- Edge labels on highlighted edges (placed on the path via textPath) -->
          <g v-for="(lbl, i) in visibleEdgeLabels" :key="'el' + i" class="gl-pointer-events-none">
            <rect
              :x="lbl.x - lbl.w / 2 - 4"
              :y="lbl.y - 6"
              :width="lbl.w + 8"
              height="12"
              rx="6"
              ry="6"
              class="orbit-edge-label-bg"
            />
            <text
              :x="lbl.x"
              :y="lbl.y + 3"
              text-anchor="middle"
              font-size="7"
              font-weight="600"
              fill="currentColor"
              fill-opacity="0.85"
            >
              {{ lbl.text }}
            </text>
          </g>

          <!-- Nodes -->
          <g
            v-for="node in graphNodes"
            :key="node.id"
            class="gl-cursor-pointer"
            :opacity="isNodeDimmed(node.id) ? 0.1 : 1"
            :transform="`translate(${node.x},${node.y})`"
            @click.stop="selectNode(node.id)"
            @mousedown.stop="onNodeMousedown($event, node)"
          >
            <circle
              v-if="selectedNode === node.id"
              :r="node.r + 4"
              fill="none"
              stroke="currentColor"
              stroke-opacity="0.6"
              stroke-width="2.5"
            />
            <circle :r="node.r" :fill="node.color || '#6B7280'" />
            <use
              v-if="node.icon"
              :href="iconHref(node.icon)"
              :x="-node.r * 0.4"
              :y="-node.r * 0.4"
              :width="node.r * 0.8"
              :height="node.r * 0.8"
              fill="white"
              fill-opacity="0.95"
            />
            <text
              v-if="!node.icon"
              text-anchor="middle"
              dominant-baseline="central"
              font-size="8"
              font-weight="600"
              fill="white"
            >
              {{ node.id.length > 12 ? node.id.slice(0, 11) + '...' : node.id }}
            </text>
            <!-- Label below node -->
            <text
              :y="node.r + 13"
              text-anchor="middle"
              font-size="11"
              font-weight="600"
              fill="currentColor"
              fill-opacity="0.8"
            >
              {{ node.id.length > 14 ? node.id.slice(0, 13) + '...' : node.id }}
            </text>
            <text
              v-if="node.count != null"
              :y="node.r + 21"
              text-anchor="middle"
              font-size="7"
              fill="currentColor"
              fill-opacity="0.4"
            >
              {{ fmtCount(node.count) }}
            </text>
          </g>
        </svg>
      </div>

      <!-- Right panel: Details (only when selected) -->
      <div
        v-if="detailNode || detailEdge"
        class="orbit-detail-panel gl-flex gl-w-48 gl-shrink-0 gl-flex-col gl-overflow-hidden"
      >
        <div
          class="gl-flex gl-max-h-full gl-flex-col gl-rounded-lg gl-border-1 gl-border-solid gl-border-default gl-bg-default"
        >
          <template v-if="detailNode">
            <!-- Header (fixed) -->
            <div class="gl-shrink-0 gl-p-3">
              <div class="gl-flex gl-items-center gl-justify-between gl-gap-2">
                <div class="gl-flex gl-items-center gl-gap-2">
                  <gl-icon
                    v-if="$options.entityIcons[detailNode.name.toLowerCase()]"
                    :name="$options.entityIcons[detailNode.name.toLowerCase()]"
                    :size="14"
                    :style="{ color: nodeColor(detailNode) }"
                  />
                  <span
                    v-else
                    class="gl-inline-block gl-h-3 gl-w-3 gl-rounded-full"
                    :style="{ backgroundColor: nodeColor(detailNode) }"
                  ></span>
                  <span class="!gl-text-sm gl-font-semibold">{{ detailNode.name }}</span>
                </div>
                <gl-button
                  variant="link"
                  class="gl-text-sm"
                  icon="earth"
                  data-testid="show-in-map-link"
                  @click="$emit('show-instances', { entityType: detailNode.name, filters: {} })"
                >
                  {{ s__('Orbit|Show in map') }}
                </gl-button>
              </div>
            </div>
            <!-- Body (scrollable) -->
            <div
              class="gl-border-t gl-min-h-0 gl-flex-1 gl-overflow-y-auto gl-border-default gl-px-3 gl-pb-3 gl-pt-3"
            >
              <div class="gl-flex gl-flex-col gl-gap-5">
                <p v-if="detailNode.description" class="gl-mb-0 gl-mt-0 gl-text-sm gl-text-subtle">
                  {{ detailNode.description }}
                </p>
                <div v-if="detailNode.properties && detailNode.properties.length">
                  <p class="gl-mb-1 gl-mt-0 gl-text-sm gl-font-bold">
                    {{ s__('Orbit|Properties') }}
                  </p>
                  <div
                    v-for="p in detailNode.properties"
                    :key="p.name"
                    class="gl-border-b gl-flex gl-items-center gl-gap-2 gl-border-default gl-py-1 last:gl-border-b-0"
                  >
                    <span class="gl-flex-1 gl-text-sm">{{ p.name }}</span>
                    <span class="gl-text-sm gl-text-subtle">{{ p.data_type }}</span>
                    <gl-badge v-if="p.filterable" size="sm" variant="success">{{
                      s__('Orbit|filterable')
                    }}</gl-badge>
                  </div>
                </div>
                <div v-if="connectedNodes.length">
                  <p class="gl-mb-1 gl-mt-0 gl-text-sm gl-font-bold">
                    {{ s__('Orbit|Connected Entities') }}
                  </p>
                  <div class="gl-flex gl-flex-wrap gl-gap-2">
                    <button
                      v-for="cn in connectedNodes"
                      :key="cn.name"
                      type="button"
                      class="gl-flex gl-cursor-pointer gl-items-center gl-gap-2 gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-bg-default gl-px-2 gl-py-1 gl-text-sm gl-text-subtle"
                      @click="selectNode(cn.name)"
                    >
                      <gl-icon
                        v-if="$options.entityIcons[cn.name.toLowerCase()]"
                        :name="$options.entityIcons[cn.name.toLowerCase()]"
                        :size="12"
                        :style="{ color: nodeColor(cn) }"
                      />
                      <span
                        v-else
                        class="gl-inline-block gl-h-2 gl-w-2 gl-flex-shrink-0 gl-rounded-full"
                        :style="{ backgroundColor: nodeColor(cn) }"
                      ></span>
                      {{ cn.name }}
                    </button>
                  </div>
                </div>
                <div v-if="groupedNodeRelationships(detailNode.name).length">
                  <p class="gl-mb-1 gl-mt-0 gl-text-sm gl-font-bold">
                    {{ s__('Orbit|Relationships') }}
                  </p>
                  <div
                    v-for="(r, i) in groupedNodeRelationships(detailNode.name)"
                    :key="i"
                    class="gl-flex gl-flex-wrap gl-items-center gl-gap-3 gl-py-1 gl-text-sm"
                  >
                    <template v-if="r.dir === 'outgoing'">
                      <span class="gl-text-subtle">{{ detailNode.name }}</span>
                      <gl-icon name="arrow-right" :size="10" class="gl-text-subtle" />
                      <span
                        class="gl-cursor-pointer gl-font-semibold hover:gl-text-link"
                        @click="selectEdge(r.name)"
                        >{{ r.name }}</span
                      >
                      <gl-icon name="arrow-right" :size="10" class="gl-text-subtle" />
                      <span
                        v-for="other in r.others"
                        :key="other"
                        class="gl-cursor-pointer gl-text-subtle hover:gl-text-link"
                        @click="selectNode(other)"
                        >{{ other }}</span
                      >
                    </template>
                    <template v-else>
                      <span
                        v-for="other in r.others"
                        :key="other"
                        class="gl-cursor-pointer gl-text-subtle hover:gl-text-link"
                        @click="selectNode(other)"
                        >{{ other }}</span
                      >
                      <gl-icon name="arrow-right" :size="10" class="gl-text-subtle" />
                      <span
                        class="gl-cursor-pointer gl-font-semibold hover:gl-text-link"
                        @click="selectEdge(r.name)"
                        >{{ r.name }}</span
                      >
                      <gl-icon name="arrow-right" :size="10" class="gl-text-subtle" />
                      <span class="gl-text-subtle">{{ detailNode.name }}</span>
                    </template>
                  </div>
                </div>
                <p class="gl-mb-0 gl-mt-0 gl-text-sm" data-testid="total-indexed">
                  <span class="gl-font-bold">{{ s__('Orbit|Total indexed:') }}</span>
                  <span class="gl-font-semibold gl-tabular-nums gl-text-default">{{
                    nodeCount(detailNode.name) != null ? fmtCount(nodeCount(detailNode.name)) : '-'
                  }}</span>
                </p>
              </div>
            </div>
          </template>
          <template v-if="detailEdge">
            <!-- Header (fixed) -->
            <div class="gl-shrink-0 gl-p-3">
              <span class="gl-text-sm gl-font-semibold">{{ detailEdge.name }}</span>
            </div>
            <!-- Body (scrollable) -->
            <div
              class="gl-border-t gl-min-h-0 gl-flex-1 gl-overflow-y-auto gl-border-default gl-px-3 gl-pb-3 gl-pt-3"
            >
              <div class="gl-flex gl-flex-col gl-gap-5">
                <p v-if="detailEdge.description" class="gl-mb-0 gl-mt-0 gl-text-sm gl-text-subtle">
                  {{ detailEdge.description }}
                </p>
                <div>
                  <div
                    v-for="(v, i) in detailEdge.variants || []"
                    :key="i"
                    class="gl-flex gl-items-center gl-gap-2 gl-py-1 gl-text-sm"
                  >
                    <span
                      class="gl-inline-block gl-h-2 gl-w-2 gl-rounded-full"
                      :style="{ backgroundColor: nodeColor({ name: v.source_type }) }"
                    ></span>
                    <span
                      class="gl-cursor-pointer hover:gl-text-link"
                      @click="selectNode(v.source_type)"
                      >{{ v.source_type }}</span
                    >
                    <gl-icon name="arrow-right" :size="10" class="gl-text-subtle" />
                    <span
                      class="gl-inline-block gl-h-2 gl-w-2 gl-rounded-full"
                      :style="{ backgroundColor: nodeColor({ name: v.target_type }) }"
                    ></span>
                    <span
                      class="gl-cursor-pointer hover:gl-text-link"
                      @click="selectNode(v.target_type)"
                      >{{ v.target_type }}</span
                    >
                  </div>
                </div>
                <div v-if="edgeRelatedNodes.length">
                  <p class="gl-mb-1 gl-mt-0 gl-text-sm gl-font-bold">
                    {{ s__('Orbit|Related Entities') }}
                  </p>
                  <div class="gl-flex gl-flex-wrap gl-gap-2">
                    <button
                      v-for="rn in edgeRelatedNodes"
                      :key="rn.name"
                      type="button"
                      class="gl-flex gl-cursor-pointer gl-items-center gl-gap-2 gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-bg-default gl-px-2 gl-py-1 gl-text-sm gl-text-subtle"
                      @click="selectNode(rn.name)"
                    >
                      <gl-icon
                        v-if="$options.entityIcons[rn.name.toLowerCase()]"
                        :name="$options.entityIcons[rn.name.toLowerCase()]"
                        :size="12"
                        :style="{ color: nodeColor(rn) }"
                      />
                      <span
                        v-else
                        class="gl-inline-block gl-h-2 gl-w-2 gl-flex-shrink-0 gl-rounded-full"
                        :style="{ backgroundColor: nodeColor(rn) }"
                      ></span>
                      {{ rn.name }}
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </template>
        </div>
      </div>
    </div>
  </div>
</template>
