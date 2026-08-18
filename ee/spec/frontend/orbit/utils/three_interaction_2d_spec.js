import GraphInteraction2D from 'ee/orbit/utils/three_interaction_2d';

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
  createStraightLine: jest.fn(() => ({ type: 'LineCurve3', getPoints: jest.fn(() => []) })),
}));

jest.mock('ee/orbit/utils/three_nodes', () => ({
  NODE_LABEL_OFFSET: 0.1,
}));

const buildInteraction = () =>
  new GraphInteraction2D({
    renderer: { domElement: document.createElement('div') },
    camera: {},
    controls: {},
    globeGroup: {},
  });

describe('GraphInteraction2D', () => {
  describe('isNodeVisible', () => {
    it('returns true when the node has a position', () => {
      const interaction = buildInteraction();

      expect(interaction.isNodeVisible({ position: { x: 0, y: 0, z: 0 } })).toBe(true);
    });

    it('returns false when the node is missing a position', () => {
      const interaction = buildInteraction();

      expect(interaction.isNodeVisible({})).toBe(false);
      expect(interaction.isNodeVisible({ position: null })).toBe(false);
    });
  });

  describe('getCurveForDrag', () => {
    it('returns a straight line between the two endpoints', () => {
      // eslint-disable-next-line global-require
      const { createStraightLine } = require('ee/orbit/utils/three_edges');
      const interaction = buildInteraction();
      const start = { x: 0, y: 0, z: 0 };
      const end = { x: 1, y: 0, z: 0 };

      const curve = interaction.getCurveForDrag(start, end);

      expect(createStraightLine).toHaveBeenCalledWith(start, end);
      expect(curve.type).toBe('LineCurve3');
    });
  });
});
