import GraphInteraction3D from 'ee/orbit/utils/three_interaction_3d';

jest.mock('three', () => {
  function Vec3(x = 0, y = 0, z = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.set = jest.fn();
    this.copy = jest.fn();
    this.clone = jest.fn(() => new Vec3(this.x, this.y, this.z));
    this.normalize = jest.fn(() => this);
    this.sub = jest.fn(() => this);
    this.dot = jest.fn(() => 0.5);
  }

  return {
    Vector3: Vec3,
    Plane: function Plane() {},
    Raycaster: function Raycaster() {
      this.setFromCamera = jest.fn();
      this.intersectObject = jest.fn(() => []);
      this.ray = { intersectPlane: jest.fn() };
    },
  };
});

jest.mock('ee/orbit/utils/three_edges', () => ({
  createArcCurve: jest.fn(() => ({ type: 'CatmullRomCurve3', getPoints: jest.fn(() => []) })),
  createStraightLine: jest.fn(),
}));

jest.mock('ee/orbit/utils/three_nodes', () => ({
  NODE_LABEL_OFFSET: 0.1,
}));

const buildGlobeGroup = () => ({
  localToWorld: jest.fn((v) => v),
  getWorldPosition: jest.fn(),
});

const buildInteraction = (overrides = {}) =>
  new GraphInteraction3D({
    renderer: { domElement: document.createElement('div') },
    camera: {
      position: { clone: jest.fn(() => ({ sub: jest.fn(() => ({ normalize: jest.fn() })) })) },
    },
    controls: {},
    globeGroup: buildGlobeGroup(),
    ...overrides,
  });

describe('GraphInteraction3D', () => {
  describe('isNodeVisible', () => {
    it('returns false when the node has no position', () => {
      const interaction = buildInteraction();

      expect(interaction.isNodeVisible({})).toBe(false);
    });

    it('returns true when the dot product between node-dir and camera-dir is positive', () => {
      const interaction = buildInteraction();
      // Mocked Vec3 returns dot = 0.5 by default which is > 0.
      expect(interaction.isNodeVisible({ position: { x: 1, y: 0, z: 0 } })).toBe(true);
    });
  });

  describe('getCurveForDrag', () => {
    it('returns an arc curve between the two endpoints', () => {
      // eslint-disable-next-line global-require
      const { createArcCurve } = require('ee/orbit/utils/three_edges');
      const interaction = buildInteraction();
      const start = { x: 1, y: 0, z: 0 };
      const end = { x: 0, y: 1, z: 0 };

      const curve = interaction.getCurveForDrag(start, end);

      expect(createArcCurve).toHaveBeenCalledWith(start, end);
      expect(curve.type).toBe('CatmullRomCurve3');
    });
  });
});
