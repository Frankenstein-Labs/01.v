import * as THREE from 'three';
import { GRAPH_DEFAULTS } from '../constants';
import {
  computeSphereLayout,
  buildAdjacencyMap,
  easeInOutSine,
  computeBackFaceOpacity,
  computeZoomLabelVisibility,
} from './graph_layout';
import { clearLabelCache } from './three_labels';
import GraphScene, { CAMERA_DEFAULT_Z } from './three_scene';
import { createGlobe, createCityLights } from './three_globe';
import {
  buildNodeMarkers,
  highlightSubgraph,
  highlightByTypes,
  resetHighlighting,
  NODE_LABEL_OFFSET,
} from './three_nodes';
import { buildGlobeConnections } from './three_edges_3d';
import GraphInteraction3D from './three_interaction_3d';
import { createRipple, tickRipple, disposeRipple, RIPPLE_RENDER_ORDER } from './three_node_ripples';

const {
  GLOBE_RADIUS,
  NODE_HEIGHT,
  IDLE_TIMEOUT_MS,
  AUTO_ROTATE_SPEED,
  ANIMATION_SPEED,
  COUNTER_SCALE_MIN_FACTOR,
  MIN_ZOOM_DISTANCE,
  MIN_SEARCH_LENGTH,
  BACK_LABEL_OPACITY,
  BACK_FACE_FADE_LO,
  BACK_FACE_FADE_HI,
  ZOOM_LABEL_IN_FULL,
  ZOOM_LABEL_OUT_HIDE,
  ZOOM_LABEL_FADE_WIDTH,
} = GRAPH_DEFAULTS;

const CONNECTIONS_RENDER_ORDER = 1;
const EDGE_LABELS_RENDER_ORDER = 4;
const NODE_LABELS_RENDER_ORDER = 5;

const CAMERA_ANIM_DURATION_MS = 800;

const EXPANSION_SPREAD_BASE = 0.35;
const EXPANSION_SPREAD_VARIANCE = 0.2;
const TANGENT_VECTOR_THRESHOLD = 0.1;
const INITIAL_FOCUS_H_OFFSET = Math.PI / 20; // ~9° horizontal rotation on initial focus
const INITIAL_FOCUS_V_OFFSET = -Math.PI / 36; // ~5° upward tilt on initial focus

const tmpLabelWorld = new THREE.Vector3();
const tmpSphereCenter = new THREE.Vector3();

export default class ThreeGraph3D {
  constructor(container, options = {}) {
    this.container = container;
    this.nodeStyleMap = options.nodeStyleMap || {};
    this.darkMode = options.darkMode !== false;
    this.nodes = [];
    this.edges = [];
    this.adjacencyMap = null;
    this.connections = [];
    this.ripples = new Map();
    this.selectedNode = null;
    this.animationId = null;
    this.cameraAnimationId = null;
    this.animationSpeed = ANIMATION_SPEED;
    this.active = true;

    this.originalNodeColors = null;
    this.originalNodeSizes = null;
    this.nodeGeometry = null;
    this.nodeMaterial = null;
    this.nodeMarkers = null;

    this.graphScene = new GraphScene(container);
    this.interaction = null;
    this.pendingCallbacks = { hover: null, select: null, expand: null };
  }

  init() {
    this.graphScene.init();
    this.graphScene.setMode3D();

    this.scene = this.graphScene.scene;
    this.camera = this.graphScene.camera;
    this.renderer = this.graphScene.renderer;
    this.controls = this.graphScene.controls;

    this.globeGroup = new THREE.Group();
    this.scene.add(this.globeGroup);

    createGlobe(this.globeGroup, this.darkMode);
    createCityLights(this.globeGroup, this.renderer, this.darkMode);

    this.connectionsGroup = new THREE.Group();
    this.connectionsGroup.renderOrder = CONNECTIONS_RENDER_ORDER;
    this.ripplesGroup = new THREE.Group();
    this.ripplesGroup.renderOrder = RIPPLE_RENDER_ORDER;
    this.labelsGroup = new THREE.Group();
    this.labelsGroup.renderOrder = EDGE_LABELS_RENDER_ORDER;
    this.nodeLabelsGroup = new THREE.Group();
    this.nodeLabelsGroup.renderOrder = NODE_LABELS_RENDER_ORDER;
    this.globeGroup.add(this.connectionsGroup);
    this.globeGroup.add(this.ripplesGroup);
    this.globeGroup.add(this.labelsGroup);
    this.globeGroup.add(this.nodeLabelsGroup);

    this.interaction = new GraphInteraction3D({
      renderer: this.renderer,
      camera: this.camera,
      controls: this.controls,
      globeGroup: this.globeGroup,
    });
    this.interaction.setContext({
      nodes: this.nodes,
      nodeGeometry: this.nodeGeometry,
      originalNodeSizes: this.originalNodeSizes,
      nodeLabelsGroup: this.nodeLabelsGroup,
      connections: this.connections,
      selectNode: (idx) => this.selectNode(idx),
      deselectNode: () => this.deselectNode(),
    });
    this.interaction.attach();

    if (this.pendingCallbacks.hover) this.interaction.onNodeHover(this.pendingCallbacks.hover);
    if (this.pendingCallbacks.select) this.interaction.onNodeSelect(this.pendingCallbacks.select);
    if (this.pendingCallbacks.expand) this.interaction.onNodeExpand(this.pendingCallbacks.expand);

    this.runAnimation();
  }

  dispose() {
    this.active = false;
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
    if (this.cameraAnimationId) {
      cancelAnimationFrame(this.cameraAnimationId);
      this.cameraAnimationId = null;
    }
    if (this.interaction) this.interaction.detach();
    this.clearRipples();
    this.graphScene.dispose();
    clearLabelCache();
  }

  pause() {
    this.active = false;
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
      this.animationId = null;
    }
  }

  resume() {
    if (this.active) return;
    this.active = true;
    this.runAnimation();
  }

  syncInteractionContext() {
    if (!this.interaction) return;
    this.interaction.setContext({
      nodes: this.nodes,
      nodeGeometry: this.nodeGeometry,
      originalNodeSizes: this.originalNodeSizes,
      nodeLabelsGroup: this.nodeLabelsGroup,
      connections: this.connections,
      selectNode: (idx) => this.selectNode(idx),
      deselectNode: () => this.deselectNode(),
    });
  }

  updateConnectionSets(edges) {
    for (const e of edges) {
      if (this.nodes[e.source] && this.nodes[e.target]) {
        this.nodes[e.source].connections.add(e.target);
        this.nodes[e.target].connections.add(e.source);
      }
    }
  }

  setData(nodes, edges, positionCache = null) {
    this.nodes = nodes.map((n, i) => ({ ...n, index: i, connections: new Set() }));
    this.edges = edges;

    this.updateConnectionSets(edges);
    this.adjacencyMap = buildAdjacencyMap(this.nodes, edges);

    if (positionCache) {
      for (const node of this.nodes) {
        node.position = positionCache.get(node.id) ?? null;
      }
      // If any node is missing a cached position, fall back to full layout.
      if (this.nodes.some((n) => !n.position)) computeSphereLayout(this.nodes, edges);
    } else {
      computeSphereLayout(this.nodes, edges);
    }

    this.buildNodeMarkers();
    this.buildConnections();

    this.clearRipples();
    this.selectedNode = null;
    if (this.interaction) this.interaction.hoveredNode = null;
  }

  addData(newNodes, newEdges) {
    const startIdx = this.nodes.length;
    const defaultPos = new THREE.Vector3(0, 0, GLOBE_RADIUS * NODE_HEIGHT);

    // Group new nodes by their existing-node parent so each cluster fans around
    // its own parent rather than all sharing newEdges[0]'s parent position.
    const childrenByParent = new Map();
    for (const edge of newEdges) {
      if (edge.source < startIdx && edge.target >= startIdx) {
        const rel = edge.target - startIdx;
        if (!childrenByParent.has(edge.source)) childrenByParent.set(edge.source, []);
        if (!childrenByParent.get(edge.source).includes(rel))
          childrenByParent.get(edge.source).push(rel);
      }
    }

    const positions = new Array(newNodes.length).fill(null);
    childrenByParent.forEach((childIndices, parentIdx) => {
      const pp = this.nodes[parentIdx]?.position;
      const parentPos = pp ? new THREE.Vector3(pp.x, pp.y, pp.z) : defaultPos;
      childIndices.forEach((rel, i) => {
        const angle = (i / childIndices.length) * Math.PI * 2;
        const spread = EXPANSION_SPREAD_BASE + Math.random() * EXPANSION_SPREAD_VARIANCE;
        positions[rel] = ThreeGraph3D.computeExpansionPosition(parentPos, angle, spread);
      });
    });
    for (let i = 0; i < newNodes.length; i += 1) {
      if (!positions[i]) {
        const angle = (i / newNodes.length) * Math.PI * 2;
        const spread = EXPANSION_SPREAD_BASE + Math.random() * EXPANSION_SPREAD_VARIANCE;
        positions[i] = ThreeGraph3D.computeExpansionPosition(defaultPos, angle, spread);
      }
    }

    const addedNodes = newNodes.map((n, i) => {
      const pos = positions[i];
      return {
        ...n,
        index: startIdx + i,
        connections: new Set(),
        position: { x: pos.x, y: pos.y, z: pos.z },
      };
    });

    this.nodes = this.nodes.concat(addedNodes);
    this.edges = this.edges.concat(newEdges);

    this.updateConnectionSets(newEdges);
    this.adjacencyMap = buildAdjacencyMap(this.nodes, this.edges);

    this.buildNodeMarkers();
    this.buildConnections();
  }

  relayout() {
    // pullScale=0.15: preserves Fibonacci distribution vs the default 0.8 which collapses
    // back-hemisphere nodes to their front-hemisphere parents after 5 attraction iterations.
    computeSphereLayout(this.nodes, this.edges, { pullScale: 0.15 });
    this.buildNodeMarkers();
    this.buildConnections();

    // Face the most connected node so the user sees the most relevant landmark first.
    let maxDeg = 0;
    let focusIdx = 0;
    for (let i = 0; i < this.nodes.length; i += 1) {
      if (this.nodes[i].connections.size > maxDeg) {
        maxDeg = this.nodes[i].connections.size;
        focusIdx = i;
      }
    }
    const focusNode = this.nodes[focusIdx];
    if (focusNode?.position) {
      const localPos = new THREE.Vector3(
        focusNode.position.x,
        focusNode.position.y,
        focusNode.position.z,
      );
      const dir = this.globeGroup.localToWorld(localPos.clone()).normalize();
      dir.applyAxisAngle(new THREE.Vector3(0, 1, 0), INITIAL_FOCUS_H_OFFSET);
      dir.applyAxisAngle(new THREE.Vector3(1, 0, 0), INITIAL_FOCUS_V_OFFSET);
      this.animateCamera(dir.multiplyScalar(CAMERA_DEFAULT_Z));
    }
  }

  static computeExpansionPosition(parentPos, angle, spread) {
    const dir = parentPos.clone().normalize();
    const up = new THREE.Vector3(0, 1, 0);
    let t1 = new THREE.Vector3().crossVectors(dir, up).normalize();
    if (t1.length() < TANGENT_VECTOR_THRESHOLD) {
      t1 = new THREE.Vector3().crossVectors(dir, new THREE.Vector3(1, 0, 0)).normalize();
    }
    const t2 = new THREE.Vector3().crossVectors(dir, t1).normalize();

    return dir
      .clone()
      .add(t1.clone().multiplyScalar(Math.cos(angle) * spread))
      .add(t2.clone().multiplyScalar(Math.sin(angle) * spread))
      .normalize()
      .multiplyScalar(GLOBE_RADIUS * NODE_HEIGHT);
  }

  buildNodeMarkers() {
    if (this.nodeMarkers) {
      this.globeGroup.remove(this.nodeMarkers);
      this.nodeGeometry?.dispose();
      this.nodeMaterial?.dispose();
    }

    if (this.nodes.length === 0) return;

    const result = buildNodeMarkers({
      nodes: this.nodes,
      nodeStyleMap: this.nodeStyleMap,
      darkMode: this.darkMode,
      globeGroup: this.globeGroup,
      renderer: this.renderer,
      nodeLabelsGroup: this.nodeLabelsGroup,
    });

    if (result) {
      this.nodeGeometry = result.nodeGeometry;
      this.nodeMaterial = result.nodeMaterial;
      this.nodeMarkers = result.nodeMarkers;
      this.originalNodeColors = result.originalNodeColors;
      this.originalNodeSizes = result.originalNodeSizes;
      this.maxDegree = result.maxDegree;
      this.syncInteractionContext();
    }
  }

  buildConnections() {
    const result = buildGlobeConnections({
      edges: this.edges,
      nodes: this.nodes,
      darkMode: this.darkMode,
      connectionsGroup: this.connectionsGroup,
      labelsGroup: this.labelsGroup,
    });
    this.connections = result.connections;
    this.syncInteractionContext();
  }

  selectNode(nodeIndex) {
    if (nodeIndex === null || nodeIndex === undefined) {
      this.deselectNode();
      return;
    }

    const node = this.nodes[nodeIndex];
    if (!node) return;

    this.selectedNode = node;
    this.highlightSubgraph(nodeIndex);
    this.navigateToNode(nodeIndex);

    if (this.interaction?.onNodeSelectCallback) {
      this.interaction.onNodeSelectCallback(node);
    }
  }

  deselectNode() {
    this.selectedNode = null;
    this.resetHighlighting();
    if (this.interaction?.onNodeSelectCallback) {
      this.interaction.onNodeSelectCallback(null);
    }
  }

  navigateToNode(nodeIndex) {
    const node = this.nodes[nodeIndex];
    if (!node?.position) return;

    const localPos = new THREE.Vector3(node.position.x, node.position.y, node.position.z);
    const worldPos = this.globeGroup.localToWorld(localPos.clone());
    const target = worldPos.normalize().multiplyScalar(CAMERA_DEFAULT_Z);
    this.animateCamera(target);
  }

  highlightSubgraph(nodeIndex) {
    highlightSubgraph({
      nodeIndex,
      adjacencyMap: this.adjacencyMap,
      nodes: this.nodes,
      nodeGeometry: this.nodeGeometry,
      originalNodeColors: this.originalNodeColors,
      originalNodeSizes: this.originalNodeSizes,
      nodeLabelsGroup: this.nodeLabelsGroup,
      connections: this.connections,
      darkMode: this.darkMode,
    });
  }

  resetHighlighting() {
    resetHighlighting({
      nodes: this.nodes,
      nodeGeometry: this.nodeGeometry,
      originalNodeColors: this.originalNodeColors,
      connections: this.connections,
      nodeLabelsGroup: this.nodeLabelsGroup,
    });
  }

  highlightByTypes(activeTypes) {
    highlightByTypes({
      activeTypes,
      nodes: this.nodes,
      nodeGeometry: this.nodeGeometry,
      originalNodeColors: this.originalNodeColors,
      nodeLabelsGroup: this.nodeLabelsGroup,
      connections: this.connections,
      darkMode: this.darkMode,
    });
  }

  getCameraState() {
    return {
      position: this.camera.position.clone(),
      target: this.controls.target.clone(),
    };
  }

  setCameraState({ position, target }) {
    if (this.cameraAnimationId) {
      cancelAnimationFrame(this.cameraAnimationId);
      this.cameraAnimationId = null;
    }
    this.camera.position.copy(position);
    this.controls.target.copy(target);
    // Call update twice: first pass sets internal state, second flushes damping velocity.
    this.controls.update();
    this.controls.update();
  }

  animateCamera(targetPos) {
    if (this.cameraAnimationId) {
      cancelAnimationFrame(this.cameraAnimationId);
      this.cameraAnimationId = null;
    }

    const startPos = this.camera.position.clone();
    const startTime = Date.now();

    const animate = () => {
      const elapsed = Date.now() - startTime;
      const t = Math.min(elapsed / CAMERA_ANIM_DURATION_MS, 1);
      const eased = easeInOutSine(t);
      this.camera.position.lerpVectors(startPos, targetPos, eased);
      this.camera.lookAt(this.graphScene.controls.target);
      this.controls.update();

      if (t < 1) {
        this.cameraAnimationId = requestAnimationFrame(animate);
      } else {
        this.cameraAnimationId = null;
      }
    };
    animate();
  }

  resize(width, height) {
    this.graphScene.resize(width, height);
  }

  zoomBy(factor) {
    if (!this.camera || !this.graphScene?.controls) return;
    const { controls } = this.graphScene;
    const { target } = controls;
    const offset = this.camera.position.clone().sub(target);
    const minDist = controls.minDistance ?? MIN_ZOOM_DISTANCE;
    const maxDist = controls.maxDistance ?? Infinity;
    const newLen = Math.max(minDist, Math.min(maxDist, offset.length() * factor));
    offset.setLength(newLen);
    this.camera.position.copy(target).add(offset);
    controls.update();
  }

  searchNodes(query) {
    if (!query || query.length < MIN_SEARCH_LENGTH) return [];
    const q = query.toLowerCase();
    return this.nodes.filter(
      (n) =>
        (n.label && n.label.toLowerCase().includes(q)) ||
        (n.type && n.type.toLowerCase().includes(q)) ||
        (n.id && String(n.id).toLowerCase().includes(q)),
    );
  }

  onNodeHover(callback) {
    this.pendingCallbacks.hover = callback;
    if (this.interaction) this.interaction.onNodeHover(callback);
  }

  onNodeSelect(callback) {
    this.pendingCallbacks.select = callback;
    if (this.interaction) this.interaction.onNodeSelect(callback);
  }

  onNodeExpand(callback) {
    this.pendingCallbacks.expand = callback;
    if (this.interaction) this.interaction.onNodeExpand(callback);
  }

  setLabelsVisible(visible) {
    if (this.nodeLabelsGroup) this.nodeLabelsGroup.visible = visible;
  }

  autoRotateGlobe() {
    const lastInteraction = this.interaction?.lastInteractionTime ?? Date.now();
    const idleTime = Date.now() - lastInteraction;
    if (idleTime > IDLE_TIMEOUT_MS && !this.selectedNode) {
      this.globeGroup.rotation.y += AUTO_ROTATE_SPEED;
    }
  }

  counterScaleLabels() {
    if (!this.nodeLabelsGroup) return;

    const camDist = this.camera.position.length();
    const factor = Math.max(COUNTER_SCALE_MIN_FACTOR, camDist / CAMERA_DEFAULT_Z);
    for (const label of this.nodeLabelsGroup.children) {
      if (!label.userData.baseScale) {
        label.userData.baseScale = { x: label.scale.x, y: label.scale.y };
        label.userData.nodePos = {
          x: label.position.x,
          y: label.position.y + NODE_LABEL_OFFSET,
          z: label.position.z,
        };
      }
      label.scale.set(label.userData.baseScale.x * factor, label.userData.baseScale.y * factor, 1);
      label.position.y = label.userData.nodePos.y - NODE_LABEL_OFFSET * factor;
    }
  }

  applyZoomLabelVisibility() {
    if (!this.nodeLabelsGroup || !this.camera) return;
    const zoomFactor = this.camera.position.length() / CAMERA_DEFAULT_Z;
    const maxDegree = this.maxDegree ?? 0;
    const hoveredIdx = this.interaction?.hoveredNode?.index ?? -1;
    const selectedIdx = this.selectedNode?.index ?? -1;

    for (let i = 0; i < this.nodes.length; i += 1) {
      const node = this.nodes[i];
      if (node.labelIndex < 0) continue;
      const label = this.nodeLabelsGroup.children[node.labelIndex];
      if (!label) continue;
      const normalizedDegree =
        maxDegree === 0 ? 1 : Math.log1p(node.connections.size) / Math.log1p(maxDegree);
      label.userData.zoomVisibility = computeZoomLabelVisibility({
        normalizedDegree,
        zoomFactor,
        zoomInFull: ZOOM_LABEL_IN_FULL,
        zoomOutHide: ZOOM_LABEL_OUT_HIDE,
        fadeWidth: ZOOM_LABEL_FADE_WIDTH,
        isHovered: node.index === hoveredIdx || node.index === selectedIdx,
      });
    }
  }

  dimBackFacingLabels() {
    if (!this.nodeLabelsGroup || !this.camera || !this.globeGroup?.getWorldPosition) return;

    this.globeGroup.getWorldPosition(tmpSphereCenter);
    const range = BACK_FACE_FADE_HI - BACK_FACE_FADE_LO;

    for (const label of this.nodeLabelsGroup.children) {
      if (!label.getWorldPosition) continue;
      label.getWorldPosition(tmpLabelWorld);

      const factor = computeBackFaceOpacity({
        labelWorld: tmpLabelWorld,
        sphereCenter: tmpSphereCenter,
        cameraPos: this.camera.position,
        range,
        lo: BACK_FACE_FADE_LO,
        baseOpacity: BACK_LABEL_OPACITY,
      });
      const intended = label.userData?.intendedOpacity ?? 1;
      const zoom = label.userData?.zoomVisibility ?? 1;
      label.material.opacity = intended * zoom * factor;
    }
  }

  setNodeLoading(nodeIndex, loading) {
    if (loading) this.startRipple(nodeIndex);
    else this.stopRipple(nodeIndex);
  }

  startRipple(nodeIndex) {
    if (this.ripples.has(nodeIndex)) return;
    const node = this.nodes[nodeIndex];
    if (!node?.position || !this.originalNodeColors || !this.originalNodeSizes) return;
    const baseIdx = nodeIndex * 3;
    const ripple = createRipple({
      position: node.position,
      color: [
        this.originalNodeColors[baseIdx],
        this.originalNodeColors[baseIdx + 1],
        this.originalNodeColors[baseIdx + 2],
      ],
      baseSize: this.originalNodeSizes[nodeIndex],
      pixelRatio: this.renderer?.getPixelRatio?.() ?? 1,
    });
    this.ripplesGroup.add(ripple.mesh);
    this.ripples.set(nodeIndex, ripple);
  }

  stopRipple(nodeIndex) {
    const ripple = this.ripples.get(nodeIndex);
    if (!ripple) return;
    this.ripplesGroup.remove(ripple.mesh);
    disposeRipple(ripple);
    this.ripples.delete(nodeIndex);
  }

  clearRipples() {
    for (const ripple of this.ripples.values()) {
      this.ripplesGroup.remove(ripple.mesh);
      disposeRipple(ripple);
    }
    this.ripples.clear();
  }

  tickRipples() {
    for (const ripple of this.ripples.values()) {
      tickRipple(ripple);
    }
  }

  runAnimation() {
    if (!this.active) return;
    this.animationId = requestAnimationFrame(() => this.runAnimation());

    this.counterScaleLabels();
    this.applyZoomLabelVisibility();
    this.dimBackFacingLabels();
    this.tickRipples();

    this.controls.update();
    this.graphScene.render();
  }
}
