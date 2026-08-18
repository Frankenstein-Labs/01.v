/**
 * Positions graph nodes on a 3D sphere (or 2D plane) using type-based clustering,
 * force-directed attraction, and repulsion.
 * Pipeline: placeNodeClusters -> applyAttraction -> applyRepulsion.
 */
import { forceSimulation, forceLink, forceManyBody, forceCollide, forceX, forceY } from 'd3';
import { GRAPH_DEFAULTS, ENTITY_TYPE_COLORS } from '../constants';

const {
  GLOBE_RADIUS,
  NODE_HEIGHT,
  CLUSTER_SPREAD,
  MIN_NODE_DISTANCE,
  LAYOUT_ATTRACTION_ITERATIONS,
  LAYOUT_REPULSION_ITERATIONS,
  CAP_THETA_MIN,
  CAP_THETA_MAX,
  CAP_N_LOW,
  CAP_N_HIGH,
  CAP_SPREAD_FLOOR,
} = GRAPH_DEFAULTS;

const SPHERE_RADIUS = GLOBE_RADIUS * NODE_HEIGHT;

// Normalize / vector thresholds
const ZERO_LENGTH_THRESHOLD = 0.0001;
const CROSS_PRODUCT_MIN_LENGTH = 0.1;

// Cluster layout tuning
const CLUSTER_RADIUS_MIN = 0.3;
const CLUSTER_RADIUS_VARIANCE = 0.7;
const SPREAD_LOG_MULTIPLIER = 0.5;

// Attraction / repulsion tuning
const SINGLE_NEIGHBOR_PULL = 0.8;
const MULTI_NEIGHBOR_PULL = 0.3;
const REPULSION_PUSH_FACTOR = 0.5;
const REPULSION_PUSH_MIN = 0.01;
const OVERLAP_THRESHOLD = 0.001;

// d3-force simulation parameters
const D3_LINK_DISTANCE = 80;
const D3_CHARGE_SMALL = -200;
const D3_CHARGE_LARGE = -800;
const D3_SMALL_GRAPH_THRESHOLD = 15;
const D3_SIMULATION_TICKS = 600;
const D3_COLLIDE_RADIUS = 8.0;
const D3_CENTERING_STRENGTH = 0.03;

// 2D target extent for the main cluster mass (p90 normalization — isolated outliers extend further).
// Larger radius = more physical space between nodes = readable labels without zooming.
const FLAT_TARGET_RADIUS = 50;
// Diameter used to scatter initial positions across [-radius, +radius]
// Percentile of node extents used for normalization — prevents isolated outlier nodes from
// compressing the main clusters.
const FLAT_NORMALIZE_PERCENTILE = 0.9;
// Below this extent the layout is effectively at the origin; skip rescaling to avoid div-by-zero
const MIN_NORMALIZE_EXTENT = 0.01;

// --- Vector math primitives ---

/** Vector cross product of two {x, y, z} objects. */
export function cross(a, b) {
  return {
    x: a.y * b.z - a.z * b.y,
    y: a.z * b.x - a.x * b.z,
    z: a.x * b.y - a.y * b.x,
  };
}

/** Euclidean length of a {x, y, z} vector. */
export function vecLen(v) {
  return Math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

/** Normalize a {x, y, z} position to the given radius (target length). */
export function normalize(pos, radius) {
  const len = Math.sqrt(pos.x * pos.x + pos.y * pos.y + pos.z * pos.z);
  if (len < ZERO_LENGTH_THRESHOLD) return { x: 0, y: radius, z: 0 };
  const scale = radius / len;
  return { x: pos.x * scale, y: pos.y * scale, z: pos.z * scale };
}

/** Euclidean distance between two points after normalizing both to unit length. */
export function distance(a, b) {
  const na = normalize(a, 1);
  const nb = normalize(b, 1);
  const dx = na.x - nb.x;
  const dy = na.y - nb.y;
  const dz = na.z - nb.z;
  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

/** Linear interpolation between two {x, y, z} points by factor t. */
export function lerp(a, b, t) {
  return {
    x: a.x + (b.x - a.x) * t,
    y: a.y + (b.y - a.y) * t,
    z: a.z + (b.z - a.z) * t,
  };
}

const GOLDEN_ANGLE = Math.PI * (3 - Math.sqrt(5));

export function smoothstep(t) {
  return t * t * (3 - 2 * t);
}

/**
 * Computes the zoom-based visibility multiplier for a single label.
 * Returns 1 when hovered or when zoomed in past zoomInFull, 0 when zoomed out
 * past zoomOutHide with degree 0, and a smooth transition in between.
 * Pure function — no Three.js dependency — so it can be unit-tested in isolation.
 */
export function computeZoomLabelVisibility({
  normalizedDegree,
  zoomFactor,
  zoomInFull,
  zoomOutHide,
  fadeWidth,
  isHovered,
}) {
  if (isHovered || zoomFactor <= zoomInFull) return 1;
  const range = zoomOutHide - zoomInFull;
  const minRatio = Math.max(0, Math.min(1, (zoomFactor - zoomInFull) / (range || 1)));
  const t = Math.max(0, Math.min(1, (normalizedDegree - minRatio) / (fadeWidth || 0.2) + 0.5));
  return smoothstep(t);
}

const BACK_FACE_DEGENERATE_LENGTH = 1e-6;

/**
 * Returns the opacity multiplier for a label based on whether it is on the
 * front or back face of the sphere relative to the camera. Pure math — no
 * three.js dependency, so it can be unit-tested in isolation.
 *
 * Smoothly fades from `baseOpacity` (label faces away from camera) to 1
 * (label faces camera) as the cosine of the label-normal vs. camera-vector
 * angle traverses [lo, lo + range].
 *
 * Returns 1 when the geometry is degenerate (label exactly at sphere center
 * or at camera position), since facing cannot be determined.
 */
export function computeBackFaceOpacity({
  labelWorld,
  sphereCenter,
  cameraPos,
  range,
  lo,
  baseOpacity,
}) {
  const nx = labelWorld.x - sphereCenter.x;
  const ny = labelWorld.y - sphereCenter.y;
  const nz = labelWorld.z - sphereCenter.z;
  const vx = cameraPos.x - labelWorld.x;
  const vy = cameraPos.y - labelWorld.y;
  const vz = cameraPos.z - labelWorld.z;
  const nLen = Math.sqrt(nx * nx + ny * ny + nz * nz);
  const vLen = Math.sqrt(vx * vx + vy * vy + vz * vz);
  if (nLen < BACK_FACE_DEGENERATE_LENGTH || vLen < BACK_FACE_DEGENERATE_LENGTH) return 1;

  const dot = (nx * vx + ny * vy + nz * vz) / (nLen * vLen);
  const tRaw = (dot - lo) / (range || 1);
  const t = Math.max(0, Math.min(1, tRaw));
  return baseOpacity + (1 - baseOpacity) * smoothstep(t);
}

/**
 * Returns the spherical-cap half-angle (radians) for placing type anchors,
 * given total node count. Small N → narrow front-facing cap; large N → full sphere.
 */
export function capHalfAngle(n) {
  if (n <= CAP_N_LOW) return CAP_THETA_MIN;
  if (n >= CAP_N_HIGH) return CAP_THETA_MAX;
  const t = (n - CAP_N_LOW) / (CAP_N_HIGH - CAP_N_LOW);
  return CAP_THETA_MIN + smoothstep(t) * (CAP_THETA_MAX - CAP_THETA_MIN);
}

// 1-slot memo: setData() re-runs the layout on every graph rebuild and on
// 2D↔3D toggle with the same nodes, so caching the most recent result lets
// us skip the sort and trig on the common case.
let typeAnchorsMemo = null;

/**
 * Distributes type anchors on a Fibonacci/golden-angle spiral within a spherical cap
 * centered on +z (camera-facing). Equal-area placement: cosθ_i = 1 − (1 − cosθ_max)·(i+0.5)/T.
 * Types are sorted alphabetically so anchor positions are deterministic across reloads
 * and independent of input ordering.
 */
export function computeTypeAnchors(types, totalNodes, radius) {
  const key = `${types.join('|')}|${totalNodes}|${radius}`;
  if (typeAnchorsMemo && typeAnchorsMemo.key === key) {
    return typeAnchorsMemo.value;
  }

  const sorted = [...types].sort();
  const T = sorted.length;
  const thetaMax = capHalfAngle(totalNodes);
  const cosThetaMax = Math.cos(thetaMax);
  const anchors = new Map();
  for (let i = 0; i < T; i += 1) {
    const cosTheta = 1 - (1 - cosThetaMax) * ((i + 0.5) / T);
    const sinTheta = Math.sqrt(Math.max(0, 1 - cosTheta * cosTheta));
    const phi = i * GOLDEN_ANGLE;
    anchors.set(sorted[i], {
      x: radius * sinTheta * Math.cos(phi),
      y: radius * sinTheta * Math.sin(phi),
      z: radius * cosTheta,
    });
  }

  const value = { anchors, thetaMax };
  typeAnchorsMemo = { key, value };
  return value;
}

// --- Graph traversal ---

/** Builds a bidirectional adjacency map from node indices and edges. */
export function buildAdjacencyMap(nodes, edges) {
  const adj = new Map();
  nodes.forEach((n, i) => adj.set(i, new Set()));
  edges.forEach((e) => {
    if (adj.has(e.source) && adj.has(e.target)) {
      adj.get(e.source).add(e.target);
      adj.get(e.target).add(e.source);
    }
  });
  return adj;
}

/** Breadth-first search from a node index. Returns Map of nodeIndex -> distance. */
export function runBFS(startIndex, adjacencyMap) {
  if (typeof startIndex !== 'number') {
    throw new TypeError(`runBFS: startIndex must be a number, got ${typeof startIndex}`);
  }
  if (!(adjacencyMap instanceof Map)) {
    throw new TypeError('runBFS: adjacencyMap must be a Map');
  }

  const distances = new Map();
  distances.set(startIndex, 0);
  const queue = [startIndex];
  let head = 0;

  while (head < queue.length) {
    const current = queue[head];
    head += 1;
    const currentDist = distances.get(current);
    const neighbors = adjacencyMap.get(current);
    if (neighbors) {
      neighbors.forEach((neighbor) => {
        if (!distances.has(neighbor)) {
          distances.set(neighbor, currentDist + 1);
          queue.push(neighbor);
        }
      });
    }
  }

  return distances;
}

// --- Layout algorithms ---

function groupNodesByType(nodes) {
  const typeGroups = Object.create(null);
  nodes.forEach((node, i) => {
    const key = (node.type || node.domain || 'default').toLowerCase();
    if (!typeGroups[key]) typeGroups[key] = [];
    typeGroups[key].push(i);
  });
  return typeGroups;
}

/**
 * Groups nodes by connected component using undirected BFS.
 * Each component gets one anchor for Fibonacci placement.
 *
 * Directed-forest root detection (in-degree = 0) fails for pure cycles and
 * components whose entry points were filtered out of the query result — every
 * node falls through to the singleton branch and per-component grouping is
 * lost. Treating edges as undirected handles cycles, multi-parent graphs, and
 * any component regardless of its in-degree distribution.
 *
 * Returns a plain object mapping string(componentStartIdx) → node index array.
 */
export function groupNodesBySubtree(nodes, edges) {
  if (nodes.length === 0) return {};

  const adj = new Map();
  nodes.forEach((_, i) => adj.set(i, []));
  edges.forEach((e) => {
    adj.get(e.source)?.push(e.target);
    adj.get(e.target)?.push(e.source);
  });

  const visited = new Set();
  const groups = Object.create(null);

  nodes.forEach((_, start) => {
    if (visited.has(start)) return;
    const component = [];
    const queue = [start];
    visited.add(start);
    let head = 0;
    while (head < queue.length) {
      const curr = queue[head];
      head += 1;
      component.push(curr);
      for (const neighbor of adj.get(curr) || []) {
        if (!visited.has(neighbor)) {
          visited.add(neighbor);
          queue.push(neighbor);
        }
      }
    }
    groups[String(start)] = component;
  });

  return groups;
}

function placeClusterRing(nodes, { indices, center, spreadFactor = 1 }) {
  const centerNorm = normalize(center, 1);

  const up = { x: 0, y: 1, z: 0 };
  let t1 = cross(centerNorm, up);
  if (vecLen(t1) < CROSS_PRODUCT_MIN_LENGTH) {
    t1 = cross(centerNorm, { x: 1, y: 0, z: 0 });
  }
  t1 = normalize(t1, 1);
  const t2 = normalize(cross(centerNorm, t1), 1);

  const clusterSize = indices.length;
  const spreadScale = 1 + Math.log2(Math.max(clusterSize, 1)) * SPREAD_LOG_MULTIPLIER;
  for (let i = 0; i < clusterSize; i += 1) {
    const idx = indices[i];
    const angle = (i / clusterSize) * Math.PI * 2;
    const r =
      CLUSTER_SPREAD *
      spreadScale *
      spreadFactor *
      (CLUSTER_RADIUS_MIN + Math.random() * CLUSTER_RADIUS_VARIANCE);
    const ox = Math.cos(angle) * r;
    const oy = Math.sin(angle) * r;

    const pos = {
      x: centerNorm.x + t1.x * ox + t2.x * oy,
      y: centerNorm.y + t1.y * ox + t2.y * oy,
      z: centerNorm.z + t1.z * ox + t2.z * oy,
    };
    nodes[idx].position = normalize(pos, SPHERE_RADIUS); // eslint-disable-line no-param-reassign -- mutates in-place by design
  }
}

/**
 * Distributes nodes on a Fibonacci spiral within a spherical cap.
 * When edges are provided and form a tree, each connected subtree gets its own
 * Fibonacci anchor (one per root) for better global distribution. Without edges,
 * falls back to type-based clustering.
 * @mutates nodes — positions are set in place for performance.
 */
export function placeNodeClusters(nodes, edges = []) {
  const groups = edges.length > 0 ? groupNodesBySubtree(nodes, edges) : groupNodesByType(nodes);
  const keys = Object.keys(groups);
  const { anchors, thetaMax } = computeTypeAnchors(keys, nodes.length, SPHERE_RADIUS);

  const capRatio = (thetaMax - CAP_THETA_MIN) / (CAP_THETA_MAX - CAP_THETA_MIN);
  const clampedRatio = Math.max(0, Math.min(1, capRatio));
  const spreadFactor = CAP_SPREAD_FLOOR + (1 - CAP_SPREAD_FLOOR) * clampedRatio;

  Object.entries(groups).forEach(([key, indices]) => {
    placeClusterRing(nodes, { indices, center: anchors.get(key), spreadFactor });
  });
}

function averageNeighborPosition(nodes, neighbors) {
  const positions = [];
  neighbors.forEach((ni) => {
    if (nodes[ni].position) positions.push(nodes[ni].position);
  });
  if (positions.length === 0) return null;

  const avg = { x: 0, y: 0, z: 0 };
  positions.forEach((p) => {
    avg.x += p.x;
    avg.y += p.y;
    avg.z += p.z;
  });
  avg.x /= positions.length;
  avg.y /= positions.length;
  avg.z /= positions.length;
  return normalize(avg, SPHERE_RADIUS);
}

/**
 * Pulls connected nodes closer together on the sphere surface.
 * @mutates nodes — positions are set in place for performance.
 */
export function applyAttraction(nodes, adj, pullScale = 1) {
  for (let iter = 0; iter < LAYOUT_ATTRACTION_ITERATIONS; iter += 1) {
    for (let i = 0; i < nodes.length; i += 1) {
      const neighbors = adj.get(i);
      if (neighbors && neighbors.size > 0) {
        const target = averageNeighborPosition(nodes, neighbors);
        if (target) {
          const pull =
            (neighbors.size === 1 ? SINGLE_NEIGHBOR_PULL : MULTI_NEIGHBOR_PULL) * pullScale;
          // eslint-disable-next-line no-param-reassign -- mutates in-place by design
          nodes[i].position = normalize(lerp(nodes[i].position, target, pull), SPHERE_RADIUS);
        }
      }
    }
  }
}

function computePushDirection(posA, posB, d) {
  if (d > OVERLAP_THRESHOLD) {
    const na = normalize(posA, 1);
    const nb = normalize(posB, 1);
    return normalize({ x: na.x - nb.x, y: na.y - nb.y, z: na.z - nb.z }, 1);
  }
  return normalize({ x: Math.random() - 0.5, y: Math.random() - 0.5, z: Math.random() - 0.5 }, 1);
}

function pushedPosition(pos, pushNorm, pushStrength) {
  return normalize(
    {
      x: pos.x + pushNorm.x * pushStrength * SPHERE_RADIUS,
      y: pos.y + pushNorm.y * pushStrength * SPHERE_RADIUS,
      z: pos.z + pushNorm.z * pushStrength * SPHERE_RADIUS,
    },
    SPHERE_RADIUS,
  );
}

/**
 * Pushes overlapping nodes apart to prevent visual collisions.
 * @mutates nodes — positions are set in place for performance.
 */
export function applyRepulsion(nodes) {
  for (let iter = 0; iter < LAYOUT_REPULSION_ITERATIONS; iter += 1) {
    for (let a = 0; a < nodes.length; a += 1) {
      if (nodes[a].position) {
        for (let b = a + 1; b < nodes.length; b += 1) {
          if (nodes[b].position) {
            const d = distance(nodes[a].position, nodes[b].position);
            if (d < MIN_NODE_DISTANCE) {
              const pushStrength =
                (MIN_NODE_DISTANCE - d) * REPULSION_PUSH_FACTOR + REPULSION_PUSH_MIN;
              const pushNorm = computePushDirection(nodes[a].position, nodes[b].position, d);
              nodes[a].position = pushedPosition(nodes[a].position, pushNorm, pushStrength); // eslint-disable-line no-param-reassign -- mutates in-place by design
            }
          }
        }
      }
    }
  }
}

/**
 * Main entry point: positions all nodes on the globe by type cluster,
 * then refines with attraction/repulsion passes.
 * @mutates nodes — positions are set in place for performance.
 */
export function computeSphereLayout(nodes, edges, { pullScale = 1 } = {}) {
  const adj = buildAdjacencyMap(nodes, edges);
  placeNodeClusters(nodes, edges);
  applyAttraction(nodes, adj, pullScale);
  applyRepulsion(nodes);
}

function normalizeToRadius(nodes, targetRadius) {
  const extents = [];
  for (const n of nodes) {
    if (n.position) {
      extents.push(Math.max(Math.abs(n.position.x), Math.abs(n.position.y)));
    }
  }
  if (extents.length === 0) return;
  extents.sort((a, b) => a - b);
  // Use p90 so isolated outlier nodes don't compress the main cluster.
  const refExtent =
    extents[Math.min(Math.floor(extents.length * FLAT_NORMALIZE_PERCENTILE), extents.length - 1)];
  if (refExtent < MIN_NORMALIZE_EXTENT) return;
  const scale = targetRadius / refExtent;
  for (const n of nodes) {
    if (n.position) {
      n.position.x *= scale;
      n.position.y *= scale;
    }
  }
}

/**
 * Positions nodes for 2D view using d3-force simulation seeded with
 * topology-aware initial positions. Each connected subtree gets a Fibonacci
 * spiral center; nodes within a subtree start near that center so the
 * simulation settles into topology-respecting clusters without needing
 * a pure random start.
 * @mutates nodes — positions are set in place for performance.
 */
export function computeFlatTopologicalLayout(nodes, edges) {
  if (nodes.length === 0) return;

  const groups = groupNodesBySubtree(nodes, edges);
  const entries = Object.entries(groups);
  const n = entries.length;

  // Seed each node near its subtree center so d3 starts from a structured state.
  const centerScale = FLAT_TARGET_RADIUS * 1.5;
  const seedX = new Float64Array(nodes.length);
  const seedY = new Float64Array(nodes.length);
  entries.forEach(([, indices], i) => {
    const cr = centerScale * Math.sqrt((i + 0.5) / n);
    const cphi = i * GOLDEN_ANGLE;
    const cx = cr * Math.cos(cphi);
    const cy = cr * Math.sin(cphi);
    const innerSpread = Math.max(4, Math.sqrt(indices.length) * 3);
    indices.forEach((nodeIdx, j) => {
      const nr = innerSpread * Math.sqrt((j + 0.5) / indices.length);
      const nphi = j * GOLDEN_ANGLE + i;
      seedX[nodeIdx] = cx + nr * Math.cos(nphi);
      seedY[nodeIdx] = cy + nr * Math.sin(nphi);
    });
  });

  const simNodes = nodes.map((node, i) => ({ index: i, x: seedX[i], y: seedY[i] }));
  const simLinks = (edges || []).map((e) => ({ source: e.source, target: e.target }));

  const simulation = forceSimulation(simNodes)
    .force(
      'link',
      forceLink(simLinks)
        .id((d) => d.index)
        .distance(D3_LINK_DISTANCE),
    )
    .force(
      'charge',
      forceManyBody().strength(
        nodes.length < D3_SMALL_GRAPH_THRESHOLD ? D3_CHARGE_SMALL : D3_CHARGE_LARGE,
      ),
    )
    .force('collide', forceCollide(D3_COLLIDE_RADIUS).strength(1))
    .force('x', forceX(0).strength(D3_CENTERING_STRENGTH))
    .force('y', forceY(0).strength(D3_CENTERING_STRENGTH))
    .stop();

  for (let i = 0; i < D3_SIMULATION_TICKS; i += 1) simulation.tick();

  for (let i = 0; i < simNodes.length; i += 1) {
    // eslint-disable-next-line no-param-reassign -- mutates in-place by design
    nodes[i].position = { x: simNodes[i].x, y: simNodes[i].y, z: 0 };
  }

  normalizeToRadius(nodes, FLAT_TARGET_RADIUS);
}

// --- Node styling ---

/**
 * Resolves a node's display color from its type, falling back to the default palette.
 * The first fallback (|| 'default') handles missing type/domain.
 * The second fallback (|| .default) handles types not in the color map.
 */
export function getNodeColor(node) {
  const key = (node.type || node.domain || 'default').toLowerCase();
  return ENTITY_TYPE_COLORS[key] || ENTITY_TYPE_COLORS.default;
}

/** Sinusoidal ease-in-out for smooth camera animation. */
export function easeInOutSine(t) {
  return -(Math.cos(Math.PI * t) - 1) / 2;
}
