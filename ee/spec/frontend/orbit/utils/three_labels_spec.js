import * as THREE from 'three';
import {
  createTextSprite,
  createNodeLabelSprite,
  clearLabelCache,
} from 'ee/orbit/utils/three_labels';

jest.mock('three', () => {
  const MockTexture = jest.fn();
  MockTexture.prototype.dispose = jest.fn();

  const MockSpriteMaterial = jest.fn();
  MockSpriteMaterial.prototype.dispose = jest.fn();

  const MockSprite = jest.fn();
  MockSprite.prototype.scale = { set: jest.fn() };
  MockSprite.prototype.renderOrder = 0;

  return {
    CanvasTexture: MockTexture,
    SpriteMaterial: MockSpriteMaterial,
    Sprite: jest.fn(() => ({
      scale: { set: jest.fn() },
      renderOrder: 0,
    })),
    LinearFilter: 'LinearFilter',
  };
});

describe('three_labels', () => {
  let mockCtx;

  beforeEach(() => {
    clearLabelCache();

    mockCtx = {
      font: '',
      fillStyle: '',
      textAlign: '',
      textBaseline: '',
      measureText: jest.fn(() => ({ width: 100 })),
      fillText: jest.fn(),
    };

    jest.spyOn(document, 'createElement').mockReturnValue({
      width: 0,
      height: 0,
      getContext: jest.fn(() => mockCtx),
    });
  });

  afterEach(() => {
    document.createElement.mockRestore();
  });

  describe('createTextSprite', () => {
    it('returns a sprite with the correct scale', () => {
      const sprite = createTextSprite('hello', {
        fontSize: 13,
        height: 28,
        scale: 0.004,
        color: 'white',
        bold: false,
      });

      expect(sprite).toBeDefined();
      expect(sprite.scale.set).toHaveBeenCalledWith(expect.any(Number), 28 * 0.004, 1);
    });

    it('uses the texture cache for repeated calls with the same key', () => {
      const opts = { fontSize: 13, height: 28, scale: 0.004, color: 'red', bold: false };

      createTextSprite('cached', opts);
      const callsBefore = THREE.CanvasTexture.mock.calls.length;

      createTextSprite('cached', opts);
      const callsAfter = THREE.CanvasTexture.mock.calls.length;

      expect(callsAfter).toBe(callsBefore);
    });

    it('creates a new texture for a different cache key', () => {
      const opts = { fontSize: 13, height: 28, scale: 0.004, color: 'blue', bold: false };

      createTextSprite('aaa', opts);
      const callsBefore = THREE.CanvasTexture.mock.calls.length;

      createTextSprite('bbb', opts);
      const callsAfter = THREE.CanvasTexture.mock.calls.length;

      expect(callsAfter).toBe(callsBefore + 1);
    });
  });

  describe('clearLabelCache', () => {
    it('empties the cache so subsequent calls create new textures', () => {
      const opts = { fontSize: 13, height: 28, scale: 0.004, color: 'green', bold: false };

      createTextSprite('clearme', opts);
      clearLabelCache();

      const callsBefore = THREE.CanvasTexture.mock.calls.length;
      createTextSprite('clearme', opts);
      const callsAfter = THREE.CanvasTexture.mock.calls.length;

      expect(callsAfter).toBe(callsBefore + 1);
    });
  });

  describe('createNodeLabelSprite', () => {
    it('delegates to createTextSprite with bold and correct scale', () => {
      const sprite = createNodeLabelSprite('Node', true);

      expect(sprite).toBeDefined();
      expect(sprite.scale.set).toHaveBeenCalled();
    });

    it('adjusts scale by sizeMultiplier', () => {
      const sprite1 = createNodeLabelSprite('A', true, 1);
      const sprite2 = createNodeLabelSprite('B', true, 2);

      const [, h1] = sprite1.scale.set.mock.calls[0];
      const [, h2] = sprite2.scale.set.mock.calls[0];

      expect(h2).toBeCloseTo(h1 * 2, 5);
    });
  });
});
