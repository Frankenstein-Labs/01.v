import { buildFlatConnections } from 'ee/orbit/utils/three_edges_2d';

jest.mock('three', () => {
  function Vec3(x = 0, y = 0, z = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.clone = jest.fn(() => new Vec3(this.x, this.y, this.z));
    this.normalize = jest.fn(() => this);
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

  function MockMesh(geometry) {
    this.geometry = geometry;
    this.position = { copy: jest.fn() };
    this.quaternion = { setFromUnitVectors: jest.fn() };
  }

  function MockConeGeometry() {
    this.dispose = jest.fn();
  }

  function MockCurve() {
    this.getPoint = jest.fn(() => new Vec3());
    this.getPoints = jest.fn(() => []);
  }

  return {
    Vector3: Vec3,
    BufferGeometry: MockBufferGeometry,
    Float32BufferAttribute: jest.fn(),
    LineBasicMaterial: MockMaterial,
    MeshBasicMaterial: MockMaterial,
    ShaderMaterial: function MockShader(opts) {
      this.uniforms = opts?.uniforms;
      this.dispose = jest.fn();
    },
    Line: MockLine,
    Mesh: MockMesh,
    ConeGeometry: MockConeGeometry,
    Points: function MockPoints(geometry, material) {
      this.geometry = geometry;
      this.material = material;
      this.position = { copy: jest.fn() };
    },
    Color: function MockColor() {
      this.clone = jest.fn(() => this);
    },
    LineCurve3: MockCurve,
    QuadraticBezierCurve3: MockCurve,
    CatmullRomCurve3: MockCurve,
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

const buildNode = (x, y) => ({ position: { x, y, z: 0 } });

describe('buildFlatConnections', () => {
  let groups;

  beforeEach(() => {
    jest.clearAllMocks();
    groups = {
      connectionsGroup: buildGroup(),
      labelsGroup: buildGroup(),
    };
  });

  it('returns one connection per unique node pair', () => {
    const nodes = [buildNode(0, 0), buildNode(1, 0), buildNode(0, 1)];
    const edges = [
      { source: 0, target: 1, type: 'foo' },
      { source: 1, target: 0, type: 'foo' },
      { source: 0, target: 2, type: 'bar' },
    ];

    const result = buildFlatConnections({
      edges,
      nodes,
      darkMode: true,
      ...groups,
    });

    expect(result.connections).toHaveLength(2);
  });

  it('skips edges with missing endpoints or self-loops', () => {
    const nodes = [buildNode(0, 0), buildNode(1, 0)];
    const edges = [
      { source: 0, target: 0 },
      { source: 0, target: 5 },
      { source: 0, target: 1 },
    ];

    const result = buildFlatConnections({
      edges,
      nodes,
      darkMode: true,
      ...groups,
    });

    expect(result.connections).toHaveLength(1);
  });

  it('attaches a directional arrow per connection', () => {
    const nodes = [buildNode(0, 0), buildNode(1, 0)];
    const edges = [{ source: 0, target: 1 }];

    const result = buildFlatConnections({
      edges,
      nodes,
      darkMode: true,
      ...groups,
    });

    expect(result.connections[0].arrow).toBeDefined();
    // Line + arrow added to the connections group.
    expect(groups.connectionsGroup.add).toHaveBeenCalledTimes(2);
  });

  it('creates an edge label only when the edge has a type', () => {
    // eslint-disable-next-line global-require
    const labels = require('ee/orbit/utils/three_labels');
    const nodes = [buildNode(0, 0), buildNode(1, 0), buildNode(0, 1)];
    const edges = [
      { source: 0, target: 1, type: 'CONNECTS' },
      { source: 0, target: 2 },
    ];

    buildFlatConnections({
      edges,
      nodes,
      darkMode: true,
      ...groups,
    });

    expect(labels.createEdgeLabelSprite).toHaveBeenCalledTimes(1);
    expect(labels.createEdgeLabelSprite).toHaveBeenCalledWith('CONNECTS', true);
  });
});
