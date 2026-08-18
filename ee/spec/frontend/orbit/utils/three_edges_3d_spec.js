import { buildGlobeConnections } from 'ee/orbit/utils/three_edges_3d';

jest.mock('three', () => {
  function Vec3(x = 0, y = 0, z = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.clone = jest.fn(() => new Vec3(this.x, this.y, this.z));
    this.normalize = jest.fn(() => this);
    this.dot = jest.fn(() => 0.5);
    this.add = jest.fn(() => this);
    this.sub = jest.fn(() => this);
    this.multiplyScalar = jest.fn(() => this);
  }

  function MockBufferGeometry() {
    this.setFromPoints = jest.fn(() => this);
    this.setAttribute = jest.fn();
    this.dispose = jest.fn();
  }

  function MockLine(geometry, material) {
    this.geometry = geometry;
    this.material = material;
  }

  function MockMaterial() {
    this.dispose = jest.fn();
  }

  function MockCurve() {
    this.getPoint = jest.fn(() => ({ x: 0, y: 0, z: 0, copy: jest.fn() }));
    this.getPoints = jest.fn(() => []);
  }

  return {
    Vector3: Vec3,
    BufferGeometry: MockBufferGeometry,
    Float32BufferAttribute: jest.fn(),
    LineBasicMaterial: MockMaterial,
    Line: MockLine,
    LineCurve3: MockCurve,
    QuadraticBezierCurve3: MockCurve,
    CatmullRomCurve3: MockCurve,
    ShaderMaterial: function MockShader(opts) {
      this.uniforms = opts?.uniforms;
    },
    Points: function MockPoints(geometry, material) {
      this.geometry = geometry;
      this.material = material;
      this.position = { copy: jest.fn() };
    },
    Color: function MockColor() {
      this.clone = jest.fn(() => this);
    },
  };
});

jest.mock('ee/orbit/utils/three_labels', () => ({
  createEdgeLabelSprite: jest.fn(() => ({
    visible: false,
    position: { copy: jest.fn() },
  })),
}));

jest.mock('ee/orbit/utils/three_nodes', () => ({
  disposeGroupChildren: jest.fn(),
}));

const buildGroup = () => ({
  add: jest.fn(),
  clear: jest.fn(),
  children: [],
});

const buildNode = (x, y, z) => ({ position: { x, y, z } });

describe('buildGlobeConnections', () => {
  let groups;

  beforeEach(() => {
    jest.clearAllMocks();
    groups = {
      connectionsGroup: buildGroup(),
      labelsGroup: buildGroup(),
    };
  });

  it('builds one curve per unique pair', () => {
    const nodes = [buildNode(1, 0, 0), buildNode(0, 1, 0), buildNode(0, 0, 1)];
    const edges = [
      { source: 0, target: 1 },
      { source: 1, target: 0 },
      { source: 0, target: 2 },
    ];

    const result = buildGlobeConnections({
      edges,
      nodes,
      darkMode: true,
      ...groups,
    });

    expect(result.connections).toHaveLength(2);
  });

  it('omits self-loops and dangling edges', () => {
    const nodes = [buildNode(1, 0, 0), buildNode(0, 1, 0)];
    const edges = [
      { source: 0, target: 0 },
      { source: 0, target: 9 },
      { source: 0, target: 1 },
    ];

    const result = buildGlobeConnections({
      edges,
      nodes,
      darkMode: true,
      ...groups,
    });

    expect(result.connections).toHaveLength(1);
  });

  it('does not attach an arrow (3D mode uses curve rendering only)', () => {
    const nodes = [buildNode(1, 0, 0), buildNode(0, 1, 0)];
    const edges = [{ source: 0, target: 1 }];

    const result = buildGlobeConnections({
      edges,
      nodes,
      darkMode: true,
      ...groups,
    });

    expect(result.connections[0].arrow).toBeNull();
    // Just one Line added; no arrow mesh.
    expect(groups.connectionsGroup.add).toHaveBeenCalledTimes(1);
  });

  it('emits a label sprite when the edge declares a type', () => {
    // eslint-disable-next-line global-require
    const labels = require('ee/orbit/utils/three_labels');
    const nodes = [buildNode(1, 0, 0), buildNode(0, 1, 0)];
    const edges = [{ source: 0, target: 1, type: 'OWNS' }];

    buildGlobeConnections({
      edges,
      nodes,
      darkMode: false,
      ...groups,
    });

    expect(labels.createEdgeLabelSprite).toHaveBeenCalledWith('OWNS', false);
  });
});
