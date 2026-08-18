import GraphScene from 'ee/orbit/utils/three_scene';

const mockUpdate = jest.fn();
const mockDispose = jest.fn();

jest.mock('three', () => {
  const Scene = jest.fn(function MockScene() {
    this.traverse = jest.fn();
  });

  const PerspectiveCamera = jest.fn(function MockPC(fov, aspect) {
    this.fov = fov;
    this.aspect = aspect;
    this.position = {
      z: 0,
      clone: jest.fn(() => ({ sub: jest.fn(() => ({ normalize: jest.fn() })) })),
    };
    this.up = { set: jest.fn() };
    this.lookAt = jest.fn();
    this.updateProjectionMatrix = jest.fn();
  });

  const WebGLRenderer = jest.fn(function MockRenderer() {
    this.domElement = global.document.createElement('canvas');
    this.setSize = jest.fn();
    this.setPixelRatio = jest.fn();
    this.render = jest.fn();
    this.dispose = jest.fn();
    this.getPixelRatio = jest.fn(() => 1);
  });

  return {
    Scene,
    PerspectiveCamera,
    WebGLRenderer,
    MOUSE: { ROTATE: 0, DOLLY: 1, PAN: 2 },
  };
});

jest.mock('three/examples/jsm/controls/OrbitControls', () => ({
  OrbitControls: jest.fn(function MockOC() {
    this.minDistance = 0;
    this.maxDistance = 0;
    this.enableKeys = true;
    this.enableDamping = false;
    this.dampingFactor = 0;
    this.enableRotate = true;
    this.screenSpacePanning = false;
    this.mouseButtons = {};
    this.target = { set: jest.fn() };
    this.enabled = true;
    this.update = mockUpdate;
    this.dispose = mockDispose;
  }),
}));

describe('GraphScene', () => {
  let container;
  let graphScene;

  beforeEach(() => {
    container = document.createElement('div');
    Object.defineProperty(container, 'offsetWidth', { value: 800 });
    Object.defineProperty(container, 'offsetHeight', { value: 600 });
    graphScene = new GraphScene(container);
    graphScene.init();
  });

  afterEach(() => {
    mockUpdate.mockClear();
    mockDispose.mockClear();
  });

  describe('init', () => {
    it('creates scene, camera, renderer, and controls', () => {
      expect(graphScene.scene).toBeDefined();
      expect(graphScene.camera).toBeDefined();
      expect(graphScene.renderer).toBeDefined();
      expect(graphScene.controls).toBeDefined();
    });

    it('appends the renderer canvas to the container', () => {
      expect(container.contains(graphScene.renderer.domElement)).toBe(true);
    });
  });

  describe('setMode2D', () => {
    it('disables rotation', () => {
      graphScene.setMode2D();

      expect(graphScene.controls.enableRotate).toBe(false);
    });

    it('enables screen-space panning', () => {
      graphScene.setMode2D();

      expect(graphScene.controls.screenSpacePanning).toBe(true);
    });

    it('calls controls.update', () => {
      graphScene.setMode2D();

      expect(mockUpdate).toHaveBeenCalled();
    });
  });

  describe('setMode3D', () => {
    it('enables rotation', () => {
      graphScene.setMode2D();
      graphScene.setMode3D();

      expect(graphScene.controls.enableRotate).toBe(true);
    });

    it('disables screen-space panning', () => {
      graphScene.setMode2D();
      graphScene.setMode3D();

      expect(graphScene.controls.screenSpacePanning).toBe(false);
    });
  });

  describe('resize', () => {
    it('updates camera aspect ratio', () => {
      graphScene.resize(1024, 768);

      expect(graphScene.camera.aspect).toBeCloseTo(1024 / 768);
    });

    it('calls updateProjectionMatrix', () => {
      graphScene.resize(1024, 768);

      expect(graphScene.camera.updateProjectionMatrix).toHaveBeenCalled();
    });

    it('updates renderer size', () => {
      graphScene.resize(1024, 768);

      expect(graphScene.renderer.setSize).toHaveBeenCalledWith(1024, 768);
    });

    it('is a no-op when renderer is null', () => {
      graphScene.renderer = null;

      expect(() => graphScene.resize(800, 600)).not.toThrow();
    });
  });

  describe('dispose', () => {
    it('disposes renderer and controls', () => {
      graphScene.dispose();

      expect(graphScene.renderer.dispose).toHaveBeenCalled();
      expect(mockDispose).toHaveBeenCalled();
    });
  });
});
