import ThreeGraph2D from 'ee/orbit/utils/three_graph_2d';

const mockSceneInstance = {
  init: jest.fn(),
  dispose: jest.fn(),
  setMode2D: jest.fn(),
  setMode3D: jest.fn(),
  resize: jest.fn(),
  render: jest.fn(),
  scene: { add: jest.fn() },
  camera: {
    fov: 45,
    position: {
      set: jest.fn(),
      copy: jest.fn(() => mockSceneInstance.camera.position),
      add: jest.fn(() => mockSceneInstance.camera.position),
      sub: jest.fn(() => ({ length: jest.fn(() => 10), setLength: jest.fn() })),
      clone: jest.fn(() => ({
        sub: jest.fn(() => ({ length: jest.fn(() => 10), setLength: jest.fn() })),
      })),
      lerpVectors: jest.fn(),
      z: 50,
    },
    lookAt: jest.fn(),
  },
  renderer: { getPixelRatio: jest.fn(() => 2) },
  controls: {
    update: jest.fn(),
    target: { set: jest.fn() },
    minDistance: 1,
    maxDistance: 100,
  },
};

jest.mock('ee/orbit/utils/three_scene', () => {
  function MockGraphScene() {
    Object.assign(this, mockSceneInstance);
  }
  MockGraphScene.CAMERA_DEFAULT_Z = 50;
  return {
    __esModule: true,
    default: MockGraphScene,
    CAMERA_DEFAULT_Z: 50,
  };
});

const mockInteraction = {
  attach: jest.fn(),
  detach: jest.fn(),
  setContext: jest.fn(),
  onNodeHover: jest.fn(),
  onNodeSelect: jest.fn(),
  onNodeExpand: jest.fn(),
  onNodeSelectCallback: jest.fn(),
  hoveredNode: null,
};

jest.mock('ee/orbit/utils/three_interaction_2d', () => {
  return jest.fn().mockImplementation(() => mockInteraction);
});

jest.mock('ee/orbit/utils/three_nodes', () => ({
  buildNodeMarkers: jest.fn(() => ({
    nodeGeometry: { dispose: jest.fn() },
    nodeMaterial: { dispose: jest.fn() },
    nodeMarkers: {},
    originalNodeColors: [],
    originalNodeSizes: [],
  })),
  highlightSubgraph: jest.fn(),
  highlightByTypes: jest.fn(),
  resetHighlighting: jest.fn(),
  NODE_LABEL_OFFSET: 0.1,
}));

jest.mock('ee/orbit/utils/three_edges_2d', () => ({
  buildFlatConnections: jest.fn(() => ({ connections: [] })),
}));

jest.mock('ee/orbit/utils/three_node_ripples', () => ({
  createRipple: jest.fn(() => ({ mesh: { dispose: jest.fn() }, baseSize: 10, startTime: 0 })),
  tickRipple: jest.fn(),
  disposeRipple: jest.fn(),
  RIPPLE_RENDER_ORDER: 2,
}));

jest.mock('ee/orbit/utils/three_labels', () => ({
  clearLabelCache: jest.fn(),
}));

jest.mock('ee/orbit/utils/graph_layout', () => ({
  computeFlatTopologicalLayout: jest.fn(),
  buildAdjacencyMap: jest.fn(() => new Map()),
  easeInOutSine: jest.fn((t) => t),
  computeZoomLabelVisibility: jest.fn(() => 1),
}));

jest.mock('three', () => ({
  Group: function MockGroup() {
    this.add = jest.fn();
    this.remove = jest.fn();
    this.children = [];
    this.renderOrder = 0;
  },
  Vector3: function Vec3(x = 0, y = 0, z = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.set = jest.fn();
    this.clone = jest.fn(() => new Vec3(this.x, this.y, this.z));
  },
}));

describe('ThreeGraph2D', () => {
  let container;
  let graph;

  beforeEach(() => {
    jest.clearAllMocks();
    global.requestAnimationFrame = jest.fn();
    global.cancelAnimationFrame = jest.fn();
    container = document.createElement('div');
  });

  describe('constructor', () => {
    it('initializes with empty data and the given options', () => {
      graph = new ThreeGraph2D(container, {
        nodeStyleMap: { user: { color: 0xff0000 } },
        darkMode: false,
      });

      expect(graph.nodes).toEqual([]);
      expect(graph.edges).toEqual([]);
      expect(graph.darkMode).toBe(false);
      expect(graph.nodeStyleMap).toEqual({ user: { color: 0xff0000 } });
      expect(graph.active).toBe(true);
    });

    it('defaults darkMode to true and styleMap to empty', () => {
      graph = new ThreeGraph2D(container);

      expect(graph.darkMode).toBe(true);
      expect(graph.nodeStyleMap).toEqual({});
    });
  });

  describe('init', () => {
    beforeEach(() => {
      graph = new ThreeGraph2D(container);
      graph.init();
    });

    it('switches the scene to 2D mode', () => {
      expect(mockSceneInstance.setMode2D).toHaveBeenCalled();
    });

    it('attaches the interaction handler', () => {
      expect(mockInteraction.attach).toHaveBeenCalled();
    });

    it('starts the animation loop', () => {
      expect(global.requestAnimationFrame).toHaveBeenCalled();
    });

    it('replays pending hover/select/expand callbacks registered before init', () => {
      const hoverCb = jest.fn();
      const selectCb = jest.fn();
      const expandCb = jest.fn();
      const fresh = new ThreeGraph2D(container);

      fresh.onNodeHover(hoverCb);
      fresh.onNodeSelect(selectCb);
      fresh.onNodeExpand(expandCb);
      fresh.init();

      expect(mockInteraction.onNodeHover).toHaveBeenCalledWith(hoverCb);
      expect(mockInteraction.onNodeSelect).toHaveBeenCalledWith(selectCb);
      expect(mockInteraction.onNodeExpand).toHaveBeenCalledWith(expandCb);
    });
  });

  describe('setData', () => {
    beforeEach(() => {
      graph = new ThreeGraph2D(container);
      graph.init();
    });

    it('stores indexed nodes with empty connection sets', () => {
      const nodes = [
        { id: 'a', label: 'A' },
        { id: 'b', label: 'B' },
      ];
      const edges = [{ source: 0, target: 1 }];

      graph.setData(nodes, edges);

      expect(graph.nodes).toHaveLength(2);
      expect(graph.nodes[0].index).toBe(0);
      expect(graph.nodes[0].connections).toBeInstanceOf(Set);
      expect(graph.nodes[0].connections.has(1)).toBe(true);
      expect(graph.nodes[1].connections.has(0)).toBe(true);
      expect(graph.edges).toBe(edges);
    });

    it('clears the previous selection', () => {
      // Drive the initial selection through the public selectNode API instead
      // of mutating internal state, so the assertion exercises the same code
      // path that production hits.
      graph.setData([{ id: 'old', label: 'Old' }], []);
      graph.selectNode(0);
      expect(graph.selectedNode).not.toBeNull();

      graph.setData([{ id: 'a', label: 'A' }], []);

      expect(graph.selectedNode).toBeNull();
    });
  });

  describe('addData', () => {
    beforeEach(() => {
      graph = new ThreeGraph2D(container);
      graph.init();
      graph.setData(
        [
          { id: 'a', label: 'A' },
          { id: 'b', label: 'B' },
        ],
        [],
      );
    });

    it('appends new nodes after the existing ones', () => {
      graph.addData([{ id: 'c', label: 'C' }], []);

      expect(graph.nodes).toHaveLength(3);
      expect(graph.nodes[2].id).toBe('c');
    });
  });

  describe('searchNodes', () => {
    beforeEach(() => {
      graph = new ThreeGraph2D(container);
      graph.init();
      graph.setData(
        [
          { id: 'User_1', label: 'Administrator', type: 'user' },
          { id: 'User_2', label: 'Developer', type: 'user' },
          { id: 'Group_1', label: 'gitlab-org', type: 'group' },
        ],
        [],
      );
    });

    it('returns an empty list when the query is empty or too short', () => {
      expect(graph.searchNodes('')).toEqual([]);
      expect(graph.searchNodes('a')).toEqual([]);
    });

    it('matches against label, id, and type case-insensitively', () => {
      expect(graph.searchNodes('admin')).toHaveLength(1);
      expect(graph.searchNodes('user')).toHaveLength(2);
      expect(graph.searchNodes('group_1')).toHaveLength(1);
    });
  });

  describe('selectNode / deselectNode', () => {
    beforeEach(() => {
      graph = new ThreeGraph2D(container);
      graph.init();
      graph.setData(
        [
          { id: 'a', label: 'A' },
          { id: 'b', label: 'B' },
        ],
        [],
      );
    });

    it('selectNode stores the node and fires the select callback', () => {
      graph.selectNode(1);

      expect(graph.selectedNode).toBe(graph.nodes[1]);
      expect(mockInteraction.onNodeSelectCallback).toHaveBeenCalledWith(graph.nodes[1]);
    });

    it('selectNode with null deselects', () => {
      graph.selectNode(0);
      graph.selectNode(null);

      expect(graph.selectedNode).toBeNull();
    });

    it('selectNode is a no-op for an out-of-range index', () => {
      graph.selectNode(999);

      expect(graph.selectedNode).toBeNull();
    });

    it('deselectNode resets the selection and fires the callback with null', () => {
      [graph.selectedNode] = graph.nodes;
      graph.deselectNode();

      expect(graph.selectedNode).toBeNull();
      expect(mockInteraction.onNodeSelectCallback).toHaveBeenCalledWith(null);
    });
  });

  describe('setNodeLoading / ripples', () => {
    // eslint-disable-next-line global-require
    const ripples = require('ee/orbit/utils/three_node_ripples');

    beforeEach(() => {
      graph = new ThreeGraph2D(container);
      graph.init();
      graph.setData(
        [
          { id: 'a', label: 'A' },
          { id: 'b', label: 'B' },
        ],
        [],
      );
      graph.nodes[0].position = { x: 0, y: 0, z: 0 };
      graph.nodes[1].position = { x: 1, y: 1, z: 0 };
      graph.originalNodeColors = new Float32Array([1, 0, 0, 0, 1, 0]);
      graph.originalNodeSizes = new Float32Array([10, 20]);
    });

    it('creates a ripple when a node enters the loading state', () => {
      graph.setNodeLoading(1, true);

      expect(graph.ripples.has(1)).toBe(true);
      expect(ripples.createRipple).toHaveBeenCalledWith(
        expect.objectContaining({
          color: [0, 1, 0],
          baseSize: 20,
        }),
      );
    });

    it('does not create a duplicate ripple for the same node', () => {
      graph.setNodeLoading(1, true);
      graph.setNodeLoading(1, true);

      expect(ripples.createRipple).toHaveBeenCalledTimes(1);
    });

    it('disposes the ripple when loading clears', () => {
      graph.setNodeLoading(1, true);
      graph.setNodeLoading(1, false);

      expect(graph.ripples.has(1)).toBe(false);
      expect(ripples.disposeRipple).toHaveBeenCalledTimes(1);
    });

    it('advances every active ripple per frame', () => {
      graph.setNodeLoading(0, true);
      graph.setNodeLoading(1, true);
      graph.tickRipples();

      expect(ripples.tickRipple).toHaveBeenCalledTimes(2);
    });

    it('setData disposes any active ripples', () => {
      graph.setNodeLoading(0, true);
      ripples.disposeRipple.mockClear();

      graph.setData([{ id: 'c' }], []);

      expect(graph.ripples.size).toBe(0);
      expect(ripples.disposeRipple).toHaveBeenCalled();
    });
  });

  describe('zoomBy', () => {
    beforeEach(() => {
      graph = new ThreeGraph2D(container);
      graph.init();
    });

    it('updates controls when called with a finite factor', () => {
      graph.zoomBy(0.8);

      expect(mockSceneInstance.controls.update).toHaveBeenCalled();
    });

    it('is a no-op when the camera or controls are missing', () => {
      const orphan = new ThreeGraph2D(container);
      expect(() => orphan.zoomBy(1.25)).not.toThrow();
    });
  });

  describe('dispose', () => {
    beforeEach(() => {
      graph = new ThreeGraph2D(container);
      graph.init();
    });

    it('marks the graph inactive and disposes the scene + interaction', () => {
      graph.dispose();

      expect(graph.active).toBe(false);
      expect(mockInteraction.detach).toHaveBeenCalled();
      expect(mockSceneInstance.dispose).toHaveBeenCalled();
    });
  });
});
