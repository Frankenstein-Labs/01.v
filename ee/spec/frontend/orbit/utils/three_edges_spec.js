import { createStraightLine, createArcCurve } from 'ee/orbit/utils/three_edges';

const mockGetPoint = jest.fn(() => ({ x: 0, y: 0, z: 0, copy: jest.fn() }));
const mockGetPoints = jest.fn(() => []);

jest.mock('three', () => {
  const Vec3 = jest.fn(function MockV3(x = 0, y = 0, z = 0) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.clone = jest.fn(() => new Vec3(this.x, this.y, this.z));
    this.normalize = jest.fn(() => this);
    this.dot = jest.fn(() => 0.5);
    this.add = jest.fn(() => this);
    this.sub = jest.fn(() => this);
    this.multiplyScalar = jest.fn(() => this);
    this.copy = jest.fn();
    this.set = jest.fn();
  });

  function MockColor(r = 0, g = 0, b = 0) {
    this.r = r;
    this.g = g;
    this.b = b;
    this.clone = jest.fn(() => new MockColor(r, g, b));
  }

  const LineCurve3 = jest.fn(function MockLC3(start, end) {
    this.start = start;
    this.end = end;
    this.type = 'LineCurve3';
    this.getPoint = mockGetPoint;
    this.getPoints = mockGetPoints;
  });

  const QuadraticBezierCurve3 = jest.fn(function MockQBC3() {
    this.type = 'QuadraticBezierCurve3';
    this.getPoint = mockGetPoint;
    this.getPoints = mockGetPoints;
  });

  const CatmullRomCurve3 = jest.fn(function MockCRC3() {
    this.type = 'CatmullRomCurve3';
    this.getPoint = mockGetPoint;
    this.getPoints = mockGetPoints;
  });

  const BufferGeometry = jest.fn(function MockBG() {
    this.setAttribute = jest.fn();
    this.setFromPoints = jest.fn(() => this);
    this.dispose = jest.fn();
  });

  const Float32BufferAttribute = jest.fn();

  const ShaderMaterial = jest.fn(function MockSM(opts) {
    this.uniforms = opts.uniforms;
  });

  const Points = jest.fn(function MockPoints(geometry, material) {
    this.geometry = geometry;
    this.material = material;
    this.position = { copy: jest.fn() };
  });

  return {
    Vector3: Vec3,
    Color: MockColor,
    LineCurve3,
    QuadraticBezierCurve3,
    CatmullRomCurve3,
    BufferGeometry,
    Float32BufferAttribute,
    ShaderMaterial,
    Points,
  };
});

describe('three_edges shared primitives', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('createStraightLine', () => {
    it('returns a LineCurve3 between the two given points', () => {
      const start = { x: 0, y: 0, z: 0 };
      const end = { x: 1, y: 0, z: 0 };

      const curve = createStraightLine(start, end);

      expect(curve.type).toBe('LineCurve3');
      expect(curve.start).toBe(start);
      expect(curve.end).toBe(end);
    });
  });

  describe('createArcCurve', () => {
    let Vec3Mock;

    beforeEach(() => {
      // eslint-disable-next-line global-require
      Vec3Mock = require('three').Vector3;
    });

    it('returns a CatmullRomCurve3 for non-coincident points', () => {
      // Default mocked dot product is 0.5 so angle is acos(0.5) ≈ 1.04 rad,
      // which is well above the ARC_ANGLE_THRESHOLD.
      const start = new Vec3Mock(1, 0, 0);
      const end = new Vec3Mock(0, 1, 0);

      const curve = createArcCurve(start, end);

      expect(curve.type).toBe('CatmullRomCurve3');
    });

    it('returns a QuadraticBezierCurve3 for near-coincident points', () => {
      // Force the dot product to ~1 so angle is ~0 (below threshold). The
      // default mock returns a fresh Vec3 from clone(), so we override the
      // prototype to make every clone-and-normalize chain return 1.
      const start = new Vec3Mock(1, 0, 0);
      const end = new Vec3Mock(1, 0, 0);
      const cloned = new Vec3Mock(1, 0, 0);
      cloned.dot.mockReturnValue(0.9999999);
      start.clone.mockReturnValue(cloned);
      end.clone.mockReturnValue(cloned);

      const curve = createArcCurve(start, end);

      expect(curve.type).toBe('QuadraticBezierCurve3');
    });
  });
});
