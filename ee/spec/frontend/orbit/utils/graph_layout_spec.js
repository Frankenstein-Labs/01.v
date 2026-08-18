import {
  computeSphereLayout,
  computeFlatTopologicalLayout,
  computeZoomLabelVisibility,
  groupNodesBySubtree,
  buildAdjacencyMap,
  runBFS,
  getNodeColor,
  capHalfAngle,
  computeTypeAnchors,
  computeBackFaceOpacity,
} from 'ee/orbit/utils/graph_layout';
import { GRAPH_DEFAULTS } from 'ee/orbit/constants';

describe('graph_layout', () => {
  const createNodes = (count) =>
    Array.from({ length: count }, (_, i) => ({
      id: String(i),
      type: i % 2 === 0 ? 'class' : 'method',
      domain: i % 3 === 0 ? 'code_review' : 'planning',
      position: null,
      connections: new Set(),
    }));

  const createEdges = (pairs) =>
    pairs.map(([source, target]) => ({ source, target, type: 'test' }));

  describe('computeSphereLayout', () => {
    it('assigns positions to all nodes', () => {
      const nodes = createNodes(10);
      const edges = createEdges([
        [0, 1],
        [1, 2],
        [2, 3],
      ]);

      computeSphereLayout(nodes, edges);

      nodes.forEach((node) => {
        expect(node.position).toBeDefined();
        expect(node.position.x).toBeDefined();
        expect(node.position.y).toBeDefined();
        expect(node.position.z).toBeDefined();
      });
    });

    it('places nodes on the sphere surface', () => {
      const nodes = createNodes(5);
      const edges = createEdges([[0, 1]]);

      computeSphereLayout(nodes, edges);

      nodes.forEach((node) => {
        const { x, y, z } = node.position;
        const radius = Math.sqrt(x * x + y * y + z * z);
        expect(radius).toBeGreaterThan(0);
      });
    });

    it('clusters nodes by domain', () => {
      let seed = 0.42;
      const mockRandom = jest.spyOn(Math, 'random').mockImplementation(() => {
        seed = (seed * 9301 + 49297) % 233280;
        return seed / 233280;
      });

      const nodes = [
        { id: '0', type: 'class', domain: 'code_review', position: null, connections: new Set() },
        { id: '1', type: 'class', domain: 'code_review', position: null, connections: new Set() },
        { id: '2', type: 'method', domain: 'planning', position: null, connections: new Set() },
        { id: '3', type: 'method', domain: 'planning', position: null, connections: new Set() },
      ];
      const edges = [];

      computeSphereLayout(nodes, edges);

      const dist01 = Math.sqrt(
        (nodes[0].position.x - nodes[1].position.x) ** 2 +
          (nodes[0].position.y - nodes[1].position.y) ** 2 +
          (nodes[0].position.z - nodes[1].position.z) ** 2,
      );
      const dist02 = Math.sqrt(
        (nodes[0].position.x - nodes[2].position.x) ** 2 +
          (nodes[0].position.y - nodes[2].position.y) ** 2 +
          (nodes[0].position.z - nodes[2].position.z) ** 2,
      );

      expect(dist01).toBeLessThan(dist02);

      mockRandom.mockRestore();
    });

    it('keeps all nodes on the front hemisphere when N is small', () => {
      const nodes = createNodes(5);

      computeSphereLayout(nodes, []);

      nodes.forEach((node) => {
        expect(node.position.z).toBeGreaterThan(0);
      });
    });

    it('spreads nodes across the full sphere when N is large', () => {
      const types = ['class', 'method', 'project', 'user', 'note', 'file', 'directory'];
      const nodes = Array.from({ length: GRAPH_DEFAULTS.CAP_N_HIGH }, (_, i) => ({
        id: String(i),
        type: types[i % types.length],
        domain: 'core',
        position: null,
        connections: new Set(),
      }));

      computeSphereLayout(nodes, []);

      const zs = nodes.map((n) => n.position.z);
      expect(Math.min(...zs)).toBeLessThan(0);
      expect(Math.max(...zs)).toBeGreaterThan(0);
    });
  });

  describe('capHalfAngle', () => {
    const { CAP_THETA_MIN, CAP_THETA_MAX, CAP_N_LOW, CAP_N_HIGH } = GRAPH_DEFAULTS;

    it('returns the minimum cap angle for N <= CAP_N_LOW', () => {
      expect(capHalfAngle(0)).toBe(CAP_THETA_MIN);
      expect(capHalfAngle(1)).toBe(CAP_THETA_MIN);
      expect(capHalfAngle(CAP_N_LOW)).toBe(CAP_THETA_MIN);
    });

    it('returns the maximum cap angle for N >= CAP_N_HIGH', () => {
      expect(capHalfAngle(CAP_N_HIGH)).toBe(CAP_THETA_MAX);
      expect(capHalfAngle(CAP_N_HIGH + 50)).toBe(CAP_THETA_MAX);
    });

    it('grows monotonically between the thresholds', () => {
      const samples = [];
      for (let n = CAP_N_LOW; n <= CAP_N_HIGH; n += 1) {
        samples.push(capHalfAngle(n));
      }
      for (let i = 1; i < samples.length; i += 1) {
        expect(samples[i]).toBeGreaterThanOrEqual(samples[i - 1]);
      }
    });
  });

  describe('computeBackFaceOpacity', () => {
    const sphereCenter = { x: 0, y: 0, z: 0 };
    const cameraPos = { x: 0, y: 0, z: 10 };
    const baseArgs = { sphereCenter, cameraPos, range: 1, lo: 0, baseOpacity: 0.2 };

    it('returns 1 (no fade) for a label fully facing the camera', () => {
      const labelWorld = { x: 0, y: 0, z: 1 };
      expect(computeBackFaceOpacity({ ...baseArgs, labelWorld })).toBe(1);
    });

    it('returns baseOpacity for a label fully facing away from the camera', () => {
      const labelWorld = { x: 0, y: 0, z: -1 };
      expect(computeBackFaceOpacity({ ...baseArgs, labelWorld })).toBe(baseArgs.baseOpacity);
    });

    it('returns a value between baseOpacity and 1 for partially-facing labels', () => {
      // Label at 45° from the camera-facing pole — front-facing but not flush.
      const labelWorld = { x: Math.SQRT1_2, y: 0, z: Math.SQRT1_2 };
      const factor = computeBackFaceOpacity({ ...baseArgs, labelWorld });
      expect(factor).toBeGreaterThan(baseArgs.baseOpacity);
      expect(factor).toBeLessThan(1);
    });

    it('returns 1 when the label coincides with the sphere center', () => {
      const labelWorld = { x: 0, y: 0, z: 0 };
      expect(computeBackFaceOpacity({ ...baseArgs, labelWorld })).toBe(1);
    });

    it('returns 1 when the label coincides with the camera', () => {
      const labelWorld = { ...cameraPos };
      expect(computeBackFaceOpacity({ ...baseArgs, labelWorld })).toBe(1);
    });
  });

  describe('computeTypeAnchors', () => {
    it('places anchors deterministically regardless of input order', () => {
      const a = computeTypeAnchors(['user', 'project', 'class'], 50, 5);
      const b = computeTypeAnchors(['class', 'user', 'project'], 50, 5);
      ['user', 'project', 'class'].forEach((type) => {
        expect(a.anchors.get(type)).toEqual(b.anchors.get(type));
      });
    });

    it('places all anchors on the sphere surface at the requested radius', () => {
      const radius = 5;
      const { anchors } = computeTypeAnchors(['a', 'b', 'c', 'd', 'e'], 100, radius);
      anchors.forEach(({ x, y, z }) => {
        expect(Math.sqrt(x * x + y * y + z * z)).toBeCloseTo(radius, 5);
      });
    });

    it('keeps anchors on the front hemisphere (z > 0) when N is small', () => {
      const { anchors, thetaMax } = computeTypeAnchors(['a', 'b', 'c'], 4, 5);
      expect(thetaMax).toBe(GRAPH_DEFAULTS.CAP_THETA_MIN);
      anchors.forEach(({ z }) => {
        expect(z).toBeGreaterThan(0);
      });
    });

    it('spans the full sphere when N is large', () => {
      const { anchors, thetaMax } = computeTypeAnchors(
        ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
        GRAPH_DEFAULTS.CAP_N_HIGH,
        5,
      );
      expect(thetaMax).toBe(GRAPH_DEFAULTS.CAP_THETA_MAX);
      const zs = Array.from(anchors.values()).map((p) => p.z);
      expect(Math.min(...zs)).toBeLessThan(0);
      expect(Math.max(...zs)).toBeGreaterThan(0);
    });
  });

  describe('computeFlatTopologicalLayout', () => {
    it('is a no-op for an empty node list', () => {
      expect(() => computeFlatTopologicalLayout([], [])).not.toThrow();
    });

    it('assigns z=0 to all nodes', () => {
      const nodes = createNodes(5);

      computeFlatTopologicalLayout(nodes, []);

      nodes.forEach((node) => {
        expect(node.position).toBeDefined();
        expect(node.position.z).toBe(0);
      });
    });

    it('assigns finite x/y for a single node with no edges', () => {
      const nodes = createNodes(1);

      computeFlatTopologicalLayout(nodes, []);

      expect(Number.isFinite(nodes[0].position.x)).toBe(true);
      expect(Number.isFinite(nodes[0].position.y)).toBe(true);
    });

    it('produces finite x/y for a mix of connected and isolated nodes', () => {
      const nodes = createNodes(10);
      const edges = createEdges([
        [0, 1],
        [1, 2],
        [3, 4],
      ]);

      expect(() => computeFlatTopologicalLayout(nodes, edges)).not.toThrow();

      nodes.forEach((node) => {
        expect(Number.isFinite(node.position.x)).toBe(true);
        expect(Number.isFinite(node.position.y)).toBe(true);
      });
    });
  });

  describe('computeZoomLabelVisibility', () => {
    const defaults = { zoomInFull: 0.6, zoomOutHide: 2.0, fadeWidth: 0.2 };

    it('returns 1 when hovered regardless of zoom or degree', () => {
      expect(
        computeZoomLabelVisibility({
          ...defaults,
          normalizedDegree: 0,
          zoomFactor: 5,
          isHovered: true,
        }),
      ).toBe(1);
    });

    it('returns 1 when zoomFactor is at the fully-zoomed-in threshold', () => {
      expect(
        computeZoomLabelVisibility({
          ...defaults,
          normalizedDegree: 0,
          zoomFactor: defaults.zoomInFull,
          isHovered: false,
        }),
      ).toBe(1);
    });

    it('returns 1 when zoomFactor is below the fully-zoomed-in threshold', () => {
      expect(
        computeZoomLabelVisibility({
          ...defaults,
          normalizedDegree: 0,
          zoomFactor: 0.3,
          isHovered: false,
        }),
      ).toBe(1);
    });

    it('returns 0 for a degree-0 node at maximum zoom-out', () => {
      // minRatio = 1, t = (0 - 1) / fadeWidth + 0.5 → clamped to 0
      expect(
        computeZoomLabelVisibility({
          ...defaults,
          normalizedDegree: 0,
          zoomFactor: defaults.zoomOutHide,
          isHovered: false,
        }),
      ).toBe(0);
    });

    it('returns smoothstep(0.5) ≈ 0.5 for a degree-1 node at maximum zoom-out', () => {
      // minRatio = 1, t = (1 - 1) / fadeWidth + 0.5 = 0.5
      expect(
        computeZoomLabelVisibility({
          ...defaults,
          normalizedDegree: 1,
          zoomFactor: defaults.zoomOutHide,
          isHovered: false,
        }),
      ).toBeCloseTo(0.5, 5);
    });

    it('returns 1 for a degree-1 node at mid-zoom where minRatio equals 0', () => {
      // zoomFactor = zoomInFull → early return 1, so use just above threshold
      // At zoomFactor slightly above zoomInFull, minRatio is small → degree-1 nodes fully visible
      const zoomFactor = defaults.zoomInFull + 0.001;
      const result = computeZoomLabelVisibility({
        ...defaults,
        normalizedDegree: 1,
        zoomFactor,
        isHovered: false,
      });
      expect(result).toBe(1);
    });

    it('returns a value in [0, 1] across the full transition range', () => {
      for (let zf = 0.6; zf <= 2.0; zf += 0.1) {
        for (let deg = 0; deg <= 1; deg += 0.25) {
          const result = computeZoomLabelVisibility({
            ...defaults,
            normalizedDegree: deg,
            zoomFactor: zf,
            isHovered: false,
          });
          expect(result).toBeGreaterThanOrEqual(0);
          expect(result).toBeLessThanOrEqual(1);
        }
      }
    });
  });

  describe('groupNodesBySubtree', () => {
    const makeNodes = (n) => Array.from({ length: n }, () => ({}));

    it('returns an empty object for zero nodes', () => {
      expect(groupNodesBySubtree([], [])).toEqual({});
    });

    it('returns a single group for one node with no edges', () => {
      const groups = groupNodesBySubtree(makeNodes(1), []);
      expect(Object.keys(groups)).toHaveLength(1);
      expect(Object.values(groups)[0]).toEqual([0]);
    });

    it('puts all nodes in one group for a connected tree', () => {
      // 0 → 1 → 2
      const edges = [
        { source: 0, target: 1 },
        { source: 1, target: 2 },
      ];
      const groups = groupNodesBySubtree(makeNodes(3), edges);
      expect(Object.keys(groups)).toHaveLength(1);
      expect(Object.values(groups)[0]).toHaveLength(3);
    });

    it('returns one singleton per disconnected node', () => {
      const groups = groupNodesBySubtree(makeNodes(3), []);
      expect(Object.keys(groups)).toHaveLength(3);
      Object.values(groups).forEach((g) => expect(g).toHaveLength(1));
    });

    it('assigns each subtree to its root when two trees are present', () => {
      // Tree 1: 0 → 1; Tree 2: 2 → 3
      const edges = [
        { source: 0, target: 1 },
        { source: 2, target: 3 },
      ];
      const groups = groupNodesBySubtree(makeNodes(4), edges);
      expect(Object.keys(groups)).toHaveLength(2);
      const sizes = Object.values(groups)
        .map((g) => g.length)
        .sort();
      expect(sizes).toEqual([2, 2]);
    });

    it('handles a multi-parent (diamond) without duplicating the shared child', () => {
      // 0 → 2, 1 → 2  (node 2 has two parents)
      const edges = [
        { source: 0, target: 2 },
        { source: 1, target: 2 },
      ];
      const groups = groupNodesBySubtree(makeNodes(3), edges);
      const allIndices = Object.values(groups).flat();
      // No duplicates
      expect(allIndices).toHaveLength(new Set(allIndices).size);
      // All nodes covered
      expect(allIndices).toHaveLength(3);
    });

    it('does not loop or throw on a cycle, and groups the cycle as one component', () => {
      // 0 → 1, 1 → 0: undirected BFS sees them as one connected component
      const edges = [
        { source: 0, target: 1 },
        { source: 1, target: 0 },
      ];
      expect(() => groupNodesBySubtree(makeNodes(2), edges)).not.toThrow();
      const groups = groupNodesBySubtree(makeNodes(2), edges);
      expect(Object.keys(groups)).toHaveLength(1);
      expect(Object.values(groups).flat()).toHaveLength(2);
    });
  });

  describe('buildAdjacencyMap', () => {
    it('creates correct adjacency sets', () => {
      const nodes = createNodes(3);
      const edges = createEdges([
        [0, 1],
        [1, 2],
      ]);

      const adj = buildAdjacencyMap(nodes, edges);

      expect(adj.get(0)).toEqual(new Set([1]));
      expect(adj.get(1)).toEqual(new Set([0, 2]));
      expect(adj.get(2)).toEqual(new Set([1]));
    });
  });

  describe('runBFS', () => {
    it('returns distance 0 for start node', () => {
      const nodes = createNodes(3);
      const edges = createEdges([
        [0, 1],
        [1, 2],
      ]);
      const adj = buildAdjacencyMap(nodes, edges);

      const distances = runBFS(0, adj);

      expect(distances.get(0)).toBe(0);
    });

    it('returns correct hop distances', () => {
      const nodes = createNodes(4);
      const edges = createEdges([
        [0, 1],
        [1, 2],
        [2, 3],
      ]);
      const adj = buildAdjacencyMap(nodes, edges);

      const distances = runBFS(0, adj);

      expect(distances.get(0)).toBe(0);
      expect(distances.get(1)).toBe(1);
      expect(distances.get(2)).toBe(2);
      expect(distances.get(3)).toBe(3);
    });

    it('does not include disconnected nodes', () => {
      const nodes = createNodes(4);
      const edges = createEdges([[0, 1]]);
      const adj = buildAdjacencyMap(nodes, edges);

      const distances = runBFS(0, adj);

      expect(distances.has(0)).toBe(true);
      expect(distances.has(1)).toBe(true);
      expect(distances.has(2)).toBe(false);
      expect(distances.has(3)).toBe(false);
    });
  });

  describe('getNodeColor', () => {
    it('returns color for known types', () => {
      expect(getNodeColor({ type: 'class' })).toBe('#A78BFA');
      expect(getNodeColor({ type: 'method' })).toBe('#EF4444');
    });

    it('returns default color for unknown types', () => {
      expect(getNodeColor({ type: 'unknown_type' })).toBe('#6B7280');
    });

    it('uses domain over type when available', () => {
      expect(getNodeColor({ domain: 'MergeRequest', type: 'class' })).toBe('#A78BFA');
    });
  });
});
