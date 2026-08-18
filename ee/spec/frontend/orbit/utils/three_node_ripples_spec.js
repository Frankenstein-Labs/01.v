import { createRipple, tickRipple, disposeRipple } from 'ee/orbit/utils/three_node_ripples';

jest.mock('three', () => {
  function MockBufferAttribute(array) {
    this.array = Array.isArray(array) ? [...array] : [];
    this.dispose = jest.fn();
  }
  function MockBufferGeometry() {
    this.attributes = {};
    this.setAttribute = jest.fn(function setAttribute(name, attr) {
      this.attributes[name] = attr;
    });
    this.dispose = jest.fn();
  }
  function MockColor(r, g, b) {
    this.r = r;
    this.g = g;
    this.b = b;
  }
  function MockShaderMaterial(opts) {
    this.uniforms = opts.uniforms;
    this.transparent = opts.transparent;
    this.dispose = jest.fn();
  }
  function MockPoints(geometry, material) {
    this.geometry = geometry;
    this.material = material;
  }
  return {
    BufferGeometry: MockBufferGeometry,
    Float32BufferAttribute: MockBufferAttribute,
    Color: MockColor,
    ShaderMaterial: MockShaderMaterial,
    Points: MockPoints,
  };
});

describe('three_node_ripples', () => {
  const buildArgs = () => ({
    position: { x: 1, y: 2, z: 3 },
    color: [1, 0.5, 0],
    baseSize: 12,
    pixelRatio: 2,
  });

  describe('createRipple', () => {
    it('returns a Points mesh with size, color, opacity uniforms', () => {
      const ripple = createRipple(buildArgs());

      expect(ripple.mesh).toBeDefined();
      expect(ripple.baseSize).toBe(12);
      expect(typeof ripple.startTime).toBe('number');

      const { uniforms } = ripple.mesh.material;
      expect(uniforms.size.value).toBe(12);
      expect(uniforms.pixelRatio.value).toBe(2);
      expect(uniforms.color.value).toMatchObject({ r: 1, g: 0.5, b: 0 });
      expect(uniforms.opacity.value).toBeGreaterThan(0);
    });

    it('writes the source position into the geometry', () => {
      const ripple = createRipple(buildArgs());

      expect(ripple.mesh.geometry.setAttribute).toHaveBeenCalledWith(
        'position',
        expect.objectContaining({ array: [1, 2, 3] }),
      );
    });
  });

  describe('tickRipple', () => {
    it('grows the size and fades the opacity over the cycle', () => {
      const ripple = createRipple(buildArgs());
      const baseSize = ripple.mesh.material.uniforms.size.value;
      const initialOpacity = ripple.mesh.material.uniforms.opacity.value;

      jest.spyOn(Date, 'now').mockReturnValue(ripple.startTime + 600);
      tickRipple(ripple);

      expect(ripple.mesh.material.uniforms.size.value).toBeGreaterThan(baseSize);
      expect(ripple.mesh.material.uniforms.opacity.value).toBeLessThan(initialOpacity);

      Date.now.mockRestore();
    });

    it('wraps the cycle so the ripple loops while loading persists', () => {
      const ripple = createRipple(buildArgs());

      jest.spyOn(Date, 'now').mockReturnValue(ripple.startTime + 1500);
      tickRipple(ripple);
      const sizeAfterWrap = ripple.mesh.material.uniforms.size.value;

      // 1500ms past start with a 1200ms period leaves us 300ms into the next
      // cycle — earlier than the 600ms point above, so the size should be smaller.
      jest.spyOn(Date, 'now').mockReturnValue(ripple.startTime + 600);
      tickRipple(ripple);
      const sizeMidCycle = ripple.mesh.material.uniforms.size.value;

      expect(sizeAfterWrap).toBeLessThan(sizeMidCycle);

      Date.now.mockRestore();
    });
  });

  describe('disposeRipple', () => {
    it('disposes the ripple geometry and material', () => {
      const ripple = createRipple(buildArgs());

      disposeRipple(ripple);

      expect(ripple.mesh.geometry.dispose).toHaveBeenCalled();
      expect(ripple.mesh.material.dispose).toHaveBeenCalled();
    });
  });
});
