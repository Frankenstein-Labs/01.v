import {
  buildNodeMarkers,
  highlightSubgraph,
  resetHighlighting,
  disposeGroupChildren,
} from 'ee/orbit/utils/three_nodes';
import { buildAdjacencyMap } from 'ee/orbit/utils/graph_layout';

jest.mock('three', () => {
  const Color = jest.fn(function MockColor(r, g, b) {
    if (typeof r === 'string') {
      this.r = 0.5;
      this.g = 0.5;
      this.b = 0.5;
    } else {
      this.r = r ?? 0;
      this.g = g ?? 0;
      this.b = b ?? 0;
    }
    this.copy = jest.fn();
    this.setRGB = jest.fn();
  });

  const MockBufferGeometry = jest.fn(function MockBG() {
    this.attributes = {};
    this.attrWrappers = {};
    this.setAttribute = jest.fn((name, a) => {
      this.attributes[name] = a;
      this.attrWrappers[name] = {
        array: a.array,
        needsUpdate: false,
        setXYZ: jest.fn(),
        setX: jest.fn(),
      };
    });
    this.getAttribute = jest.fn((name) => this.attrWrappers[name]);
    this.dispose = jest.fn();
  });

  const Float32BufferAttribute = jest.fn(function MockF32BA(arr, itemSize) {
    this.array = new Float32Array(arr);
    this.itemSize = itemSize;
  });

  const ShaderMaterial = jest.fn(function MockSM() {
    this.dispose = jest.fn();
  });

  const Points = jest.fn(function MockPoints(geo, mat) {
    this.geometry = geo;
    this.material = mat;
    this.renderOrder = 0;
  });

  return {
    Color,
    BufferGeometry: MockBufferGeometry,
    Float32BufferAttribute,
    ShaderMaterial,
    Points,
  };
});

jest.mock('ee/orbit/utils/three_labels', () => ({
  createNodeLabelSprite: jest.fn(() => ({
    position: { set: jest.fn() },
    material: { opacity: 1 },
    userData: {},
  })),
}));

const createMockGroup = () => ({
  children: [],
  add: jest.fn(function mockAdd(child) {
    this.children.push(child);
  }),
  clear: jest.fn(function mockClear() {
    this.children = [];
  }),
});

const createMockRenderer = () => ({
  getPixelRatio: jest.fn(() => 1),
});

describe('three_nodes', () => {
  const makeNodes = (count) =>
    Array.from({ length: count }, (_, i) => ({
      id: String(i),
      index: i,
      type: i % 2 === 0 ? 'class' : 'method',
      label: `node-${i}`,
      position: { x: i, y: i * 2, z: i * 3 },
      connections: new Set(i > 0 ? [i - 1] : []),
    }));

  describe('buildNodeMarkers', () => {
    it('returns null for empty nodes', () => {
      const result = buildNodeMarkers({
        nodes: [],
        nodeStyleMap: {},
        darkMode: true,
        globeGroup: createMockGroup(),
        renderer: createMockRenderer(),
        nodeLabelsGroup: createMockGroup(),
      });

      expect(result).toBeNull();
    });

    it('creates geometry with position, color, and size attributes', () => {
      const nodes = makeNodes(3);
      const globeGroup = createMockGroup();

      const result = buildNodeMarkers({
        nodes,
        nodeStyleMap: {},
        darkMode: true,
        globeGroup,
        renderer: createMockRenderer(),
        nodeLabelsGroup: createMockGroup(),
      });

      expect(result.nodeGeometry).toBeDefined();
      expect(result.nodeGeometry.setAttribute).toHaveBeenCalledWith('position', expect.any(Object));
      expect(result.nodeGeometry.setAttribute).toHaveBeenCalledWith('color', expect.any(Object));
      expect(result.nodeGeometry.setAttribute).toHaveBeenCalledWith('size', expect.any(Object));
    });

    it('adds nodeMarkers to the globeGroup', () => {
      const nodes = makeNodes(2);
      const globeGroup = createMockGroup();

      buildNodeMarkers({
        nodes,
        nodeStyleMap: {},
        darkMode: true,
        globeGroup,
        renderer: createMockRenderer(),
        nodeLabelsGroup: createMockGroup(),
      });

      expect(globeGroup.add).toHaveBeenCalled();
    });

    it('returns originalNodeColors and originalNodeSizes', () => {
      const nodes = makeNodes(3);

      const result = buildNodeMarkers({
        nodes,
        nodeStyleMap: {},
        darkMode: true,
        globeGroup: createMockGroup(),
        renderer: createMockRenderer(),
        nodeLabelsGroup: createMockGroup(),
      });

      expect(result.originalNodeColors).toBeInstanceOf(Float32Array);
      expect(result.originalNodeColors).toHaveLength(9);
      expect(result.originalNodeSizes).toBeInstanceOf(Float32Array);
      expect(result.originalNodeSizes).toHaveLength(3);
    });
  });

  describe('highlightSubgraph', () => {
    it('dims disconnected nodes in dark mode', () => {
      const nodes = makeNodes(3);
      const edges = [{ source: 0, target: 1, type: 'test' }];
      const adj = buildAdjacencyMap(nodes, edges);

      const globeGroup = createMockGroup();
      const labelsGroup = createMockGroup();
      const { nodeGeometry, originalNodeColors } = buildNodeMarkers({
        nodes,
        nodeStyleMap: {},
        darkMode: true,
        globeGroup,
        renderer: createMockRenderer(),
        nodeLabelsGroup: labelsGroup,
      });

      const colorAttr = nodeGeometry.getAttribute('color');

      highlightSubgraph({
        nodeIndex: 0,
        adjacencyMap: adj,
        nodes,
        nodeGeometry,
        originalNodeColors,
        nodeLabelsGroup: labelsGroup,
        connections: [],
        darkMode: true,
      });

      // Disconnected nodes are dimmed to 15% of original rather than zeroed out.
      // Original color for node 2 is ~0.5 per channel → 0.5 × 0.15 = 0.075.
      const baseIdx = 2 * 3;
      expect(colorAttr.setXYZ).toHaveBeenCalledWith(
        2,
        originalNodeColors[baseIdx] * 0.15,
        originalNodeColors[baseIdx + 1] * 0.15,
        originalNodeColors[baseIdx + 2] * 0.15,
      );
    });
  });

  describe('resetHighlighting', () => {
    it('restores original colors', () => {
      const nodes = makeNodes(2);
      const globeGroup = createMockGroup();
      const labelsGroup = createMockGroup();
      const { nodeGeometry, originalNodeColors } = buildNodeMarkers({
        nodes,
        nodeStyleMap: {},
        darkMode: true,
        globeGroup,
        renderer: createMockRenderer(),
        nodeLabelsGroup: labelsGroup,
      });

      const colorAttr = nodeGeometry.getAttribute('color');

      resetHighlighting({
        nodes,
        nodeGeometry,
        originalNodeColors,
        connections: [],
        nodeLabelsGroup: labelsGroup,
      });

      expect(colorAttr.setXYZ).toHaveBeenCalledWith(
        0,
        originalNodeColors[0],
        originalNodeColors[1],
        originalNodeColors[2],
      );
    });

    it('is a no-op when nodeGeometry is null', () => {
      expect(() =>
        resetHighlighting({
          nodes: [],
          nodeGeometry: null,
          originalNodeColors: null,
          connections: [],
          nodeLabelsGroup: createMockGroup(),
        }),
      ).not.toThrow();
    });
  });

  describe('disposeGroupChildren', () => {
    it('calls dispose on each child geometry and material', () => {
      const child = {
        geometry: { dispose: jest.fn() },
        material: { dispose: jest.fn(), map: { dispose: jest.fn() } },
      };
      const group = { children: [child] };

      disposeGroupChildren(group);

      expect(child.geometry.dispose).toHaveBeenCalled();
      expect(child.material.dispose).toHaveBeenCalled();
      expect(child.material.map.dispose).toHaveBeenCalled();
    });
  });
});
