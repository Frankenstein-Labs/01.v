// Builds Three.js point-sprite markers for graph nodes and handles BFS-based subgraph highlighting.
import * as THREE from 'three';
import { GRAPH_DEFAULTS } from '../constants';
import { NODE_VERTEX_SHADER, NODE_FRAGMENT_SHADER } from './graph_shaders';
import { runBFS, getNodeColor } from './graph_layout';
import { createNodeLabelSprite } from './three_labels';

const { NODE_BASE_SIZE, EDGE_OPACITY, BFS_OPACITY_DECAY, BFS_MIN_OPACITY } = GRAPH_DEFAULTS;

export const NODE_LABEL_OFFSET = 0.18;
const LIGHT_MODE_FADE = 0.88;
const LIGHT_MODE_COLOR_MIX = 0.3;
const DISCONNECTED_EDGE_OPACITY = 0.08;

// Node sizing
const NODE_SIZE_SCALE = 0.25;
const CONNECTION_SIZE_BOOST = 2;
const MAX_COUNT_SCALE = 1.15;
const COUNT_SCALE_DIVISOR = 10;
const LABEL_OFFSET_SCALE_FACTOR = 0.3;

// Hierarchy-based size multipliers: higher = larger nodes
const HIERARCHY_SIZE = {
  group: 1.3,
  project: 1.2,
  user: 1.2,
  mergerequest: 1.1,
  workitem: 1.1,
  pipeline: 1.3,
  vulnerability: 1.1,
  milestone: 1.0,
  label: 1.0,
  note: 0.9,
  branch: 0.9,
  directory: 0.9,
  file: 0.8,
  definition: 0.8,
  importedsymbol: 0.7,
  default: 1.0,
};

// BFS highlight tuning
const BFS_EDGE_OPACITY_SCALE = 0.6;
const DISCONNECTED_LABEL_OPACITY = 0.15;
const DISCONNECTED_NODE_DIM = 0.15;

// Render ordering
const NODE_RENDER_ORDER = 3;

/**
 * Stores a label's "intended" opacity (set by highlight / fade logic) so the
 * per-frame back-face dim in three_graph_3d.js can multiply it by a viewing-
 * angle factor without those two effects compounding across frames.
 */
/* eslint-disable no-param-reassign -- mutates label state by design */
export function setLabelIntendedOpacity(label, opacity) {
  label.material.opacity = opacity;
  if (!label.userData) label.userData = {};
  label.userData.intendedOpacity = opacity;
}
/* eslint-enable no-param-reassign */

/** Disposes all geometries and materials of a THREE.Group's children. */
export function disposeGroupChildren(group) {
  for (const child of group.children) {
    child.geometry?.dispose();
    if (child.material) {
      child.material.map?.dispose();
      child.material.dispose();
    }
  }
}

/** Creates point-sprite markers for all nodes with size scaled by connection count. */
export function buildNodeMarkers({
  nodes,
  nodeStyleMap,
  darkMode,
  globeGroup,
  renderer,
  nodeLabelsGroup,
  labelSizeMultiplier = 1,
}) {
  if (nodes.length === 0) return null;

  const positions = [];
  const nodeColors = [];
  const sizes = [];

  let maxConnections = 1;
  for (const n of nodes) {
    maxConnections = Math.max(maxConnections, n.connections.size);
  }

  // Scale nodes larger when there are fewer — improves visibility for small graphs
  const countScale = Math.min(MAX_COUNT_SCALE, 1 + COUNT_SCALE_DIVISOR / Math.max(nodes.length, 1));

  for (const node of nodes) {
    const pos = node.position || { x: 0, y: 0, z: 0 };
    positions.push(pos.x, pos.y, pos.z);

    const typeKey = (node.type || 'default').toLowerCase();
    const schemaStyle = nodeStyleMap[typeKey];
    const colorHex = schemaStyle?.color || getNodeColor(node);
    const color = new THREE.Color(colorHex);
    nodeColors.push(color.r, color.g, color.b);

    const rawSize = schemaStyle?.size || NODE_BASE_SIZE;
    const hierarchyKey = typeKey in HIERARCHY_SIZE ? typeKey : 'default';
    const hierarchyMult = HIERARCHY_SIZE[hierarchyKey];
    const baseSize = rawSize * NODE_SIZE_SCALE * countScale * hierarchyMult;
    const ratio = node.connections.size / maxConnections;
    const size = baseSize + ratio * CONNECTION_SIZE_BOOST;
    sizes.push(size);
    node.baseSize = size;
  }

  const originalNodeColors = new Float32Array(nodeColors);
  const originalNodeSizes = new Float32Array(sizes);

  const nodeGeometry = new THREE.BufferGeometry();
  nodeGeometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  nodeGeometry.setAttribute('color', new THREE.Float32BufferAttribute(nodeColors, 3));
  nodeGeometry.setAttribute('size', new THREE.Float32BufferAttribute(sizes, 1));

  const nodeMaterial = new THREE.ShaderMaterial({
    uniforms: {
      pixelRatio: { value: renderer.getPixelRatio() },
      darkMode: { value: darkMode ? 1.0 : 0.0 },
    },
    vertexShader: NODE_VERTEX_SHADER,
    fragmentShader: NODE_FRAGMENT_SHADER,
    transparent: true,
    depthTest: true,
    depthWrite: false,
  });

  const nodeMarkers = new THREE.Points(nodeGeometry, nodeMaterial);
  nodeMarkers.renderOrder = NODE_RENDER_ORDER;
  globeGroup.add(nodeMarkers);

  disposeGroupChildren(nodeLabelsGroup);
  nodeLabelsGroup.clear();
  const labelScale = countScale * labelSizeMultiplier;
  const labelOffset = NODE_LABEL_OFFSET * (1 + (countScale - 1) * LABEL_OFFSET_SCALE_FACTOR);
  let labelIdx = 0;
  for (const node of nodes) {
    if (!node.label || !node.position) {
      node.labelIndex = -1;
    } else {
      node.labelIndex = labelIdx;
      labelIdx += 1;
      const sprite = createNodeLabelSprite(node.label, darkMode, labelScale);
      sprite.position.set(node.position.x, node.position.y - labelOffset, node.position.z);
      sprite.userData.intendedOpacity = 1;
      sprite.userData.zoomVisibility = 1;
      nodeLabelsGroup.add(sprite);
    }
  }

  return {
    nodeGeometry,
    nodeMaterial,
    nodeMarkers,
    originalNodeColors,
    originalNodeSizes,
    maxDegree: maxConnections,
  };
}

/** Fades nodes, edges, and labels by BFS distance from the selected node. */
export function highlightSubgraph({
  nodeIndex,
  adjacencyMap,
  nodes,
  nodeGeometry,
  originalNodeColors,
  nodeLabelsGroup,
  connections,
  darkMode,
}) {
  if (!adjacencyMap || !nodeGeometry) return;

  const distances = runBFS(nodeIndex, adjacencyMap);
  const colorAttr = nodeGeometry.getAttribute('color');

  // Fade nodes by BFS distance
  for (let i = 0; i < nodes.length; i += 1) {
    const baseIdx = i * 3;
    if (distances.has(i)) {
      const dist = distances.get(i);
      const t = Math.max(BFS_MIN_OPACITY, 1.0 - dist * BFS_OPACITY_DECAY);
      if (darkMode) {
        colorAttr.setXYZ(
          i,
          originalNodeColors[baseIdx] * t,
          originalNodeColors[baseIdx + 1] * t,
          originalNodeColors[baseIdx + 2] * t,
        );
      } else {
        colorAttr.setXYZ(
          i,
          originalNodeColors[baseIdx] * t + LIGHT_MODE_FADE * (1 - t),
          originalNodeColors[baseIdx + 1] * t + LIGHT_MODE_FADE * (1 - t),
          originalNodeColors[baseIdx + 2] * t + LIGHT_MODE_FADE * (1 - t),
        );
      }
    } else if (darkMode) {
      colorAttr.setXYZ(
        i,
        originalNodeColors[baseIdx] * DISCONNECTED_NODE_DIM,
        originalNodeColors[baseIdx + 1] * DISCONNECTED_NODE_DIM,
        originalNodeColors[baseIdx + 2] * DISCONNECTED_NODE_DIM,
      );
    } else {
      colorAttr.setXYZ(
        i,
        originalNodeColors[baseIdx] * LIGHT_MODE_COLOR_MIX +
          LIGHT_MODE_FADE * (1 - LIGHT_MODE_COLOR_MIX),
        originalNodeColors[baseIdx + 1] * LIGHT_MODE_COLOR_MIX +
          LIGHT_MODE_FADE * (1 - LIGHT_MODE_COLOR_MIX),
        originalNodeColors[baseIdx + 2] * LIGHT_MODE_COLOR_MIX +
          LIGHT_MODE_FADE * (1 - LIGHT_MODE_COLOR_MIX),
      );
    }
  }
  colorAttr.needsUpdate = true;

  // Fade node labels
  for (let i = 0; i < nodes.length; i += 1) {
    const labelSprite =
      nodes[i].labelIndex >= 0 ? nodeLabelsGroup.children[nodes[i].labelIndex] : null;
    if (labelSprite) {
      if (distances.has(i)) {
        const dist = distances.get(i);
        setLabelIntendedOpacity(
          labelSprite,
          Math.max(BFS_MIN_OPACITY, 1.0 - dist * BFS_OPACITY_DECAY),
        );
      } else {
        setLabelIntendedOpacity(labelSprite, DISCONNECTED_LABEL_OPACITY);
      }
    }
  }

  // Fade edge connections
  for (const conn of connections) {
    const dA = distances.get(conn.source);
    const dB = distances.get(conn.target);
    if (dA === undefined || dB === undefined) {
      conn.line.material.opacity = DISCONNECTED_EDGE_OPACITY;
      if (conn.label) conn.label.visible = false;
    } else {
      const edgeDist = Math.max(dA, dB);
      conn.line.material.opacity =
        Math.max(BFS_MIN_OPACITY, 1.0 - edgeDist * BFS_OPACITY_DECAY) * BFS_EDGE_OPACITY_SCALE;
      if (conn.label) {
        const directlyConnected = dA === 0 || dB === 0;
        conn.label.visible = directlyConnected;
        conn.label.material.opacity = directlyConnected ? 1 : 0;
      }
    }
  }
}

/** Restores all nodes, edges, and labels to their default (unhighlighted) appearance. */
export function resetHighlighting({
  nodes,
  nodeGeometry,
  originalNodeColors,
  connections,
  nodeLabelsGroup,
}) {
  if (!nodeGeometry || !originalNodeColors) return;

  const colorAttr = nodeGeometry.getAttribute('color');
  for (let i = 0; i < nodes.length; i += 1) {
    const baseIdx = i * 3;
    colorAttr.setXYZ(
      i,
      originalNodeColors[baseIdx],
      originalNodeColors[baseIdx + 1],
      originalNodeColors[baseIdx + 2],
    );
  }
  colorAttr.needsUpdate = true;

  for (const nodeLabel of nodeLabelsGroup.children) {
    setLabelIntendedOpacity(nodeLabel, 1);
  }

  for (const conn of connections) {
    conn.line.material.opacity = EDGE_OPACITY;
    if (conn.label) {
      conn.label.visible = false;
      conn.label.material.opacity = 1;
    }
  }
}

const TYPE_DIM_FACTOR = 0.15;
const TYPE_DIM_LABEL_OPACITY = 0.15;
const TYPE_DIM_EDGE_OPACITY = 0.05;

/**
 * Highlights nodes whose type is in activeTypes. Non-matching nodes, their
 * labels, and edges that touch only non-matching nodes are faded. Passing
 * an empty/null set resets everything via resetHighlighting.
 */
export function highlightByTypes({
  activeTypes,
  nodes,
  nodeGeometry,
  originalNodeColors,
  nodeLabelsGroup,
  connections,
  darkMode,
}) {
  if (!nodeGeometry || !originalNodeColors) return;

  if (!activeTypes || activeTypes.size === 0) {
    resetHighlighting({
      nodes,
      nodeGeometry,
      originalNodeColors,
      connections,
      nodeLabelsGroup,
    });
    return;
  }

  const matches = (n) => n && n.type && activeTypes.has(n.type.toLowerCase());
  const colorAttr = nodeGeometry.getAttribute('color');

  for (let i = 0; i < nodes.length; i += 1) {
    const baseIdx = i * 3;
    if (matches(nodes[i])) {
      colorAttr.setXYZ(
        i,
        originalNodeColors[baseIdx],
        originalNodeColors[baseIdx + 1],
        originalNodeColors[baseIdx + 2],
      );
    } else if (darkMode) {
      colorAttr.setXYZ(
        i,
        originalNodeColors[baseIdx] * TYPE_DIM_FACTOR,
        originalNodeColors[baseIdx + 1] * TYPE_DIM_FACTOR,
        originalNodeColors[baseIdx + 2] * TYPE_DIM_FACTOR,
      );
    } else {
      colorAttr.setXYZ(
        i,
        originalNodeColors[baseIdx] * LIGHT_MODE_COLOR_MIX +
          LIGHT_MODE_FADE * (1 - LIGHT_MODE_COLOR_MIX),
        originalNodeColors[baseIdx + 1] * LIGHT_MODE_COLOR_MIX +
          LIGHT_MODE_FADE * (1 - LIGHT_MODE_COLOR_MIX),
        originalNodeColors[baseIdx + 2] * LIGHT_MODE_COLOR_MIX +
          LIGHT_MODE_FADE * (1 - LIGHT_MODE_COLOR_MIX),
      );
    }
  }
  colorAttr.needsUpdate = true;

  if (nodeLabelsGroup) {
    for (let i = 0; i < nodes.length; i += 1) {
      const { labelIndex } = nodes[i];
      if (labelIndex == null || labelIndex < 0) continue;
      const labelSprite = nodeLabelsGroup.children[labelIndex];
      if (!labelSprite) continue;
      setLabelIntendedOpacity(labelSprite, matches(nodes[i]) ? 1 : TYPE_DIM_LABEL_OPACITY);
    }
  }

  if (connections) {
    for (const conn of connections) {
      const touches = matches(nodes[conn.source]) || matches(nodes[conn.target]);
      conn.line.material.opacity = touches ? EDGE_OPACITY : TYPE_DIM_EDGE_OPACITY;
      if (conn.label) {
        conn.label.visible = false;
      }
    }
  }
}
