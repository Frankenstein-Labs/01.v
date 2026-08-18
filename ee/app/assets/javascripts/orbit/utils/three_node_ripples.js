// Loading-state ripple: a soft filled disc that copies a node's color and
// position, grows outward and fades out, looping while the node is loading.
import * as THREE from 'three';
import { RIPPLE_VERTEX_SHADER, RIPPLE_FRAGMENT_SHADER } from './graph_shaders';

const RIPPLE_GROWTH_FACTOR = 2.5;
const RIPPLE_PERIOD_MS = 1200;
const RIPPLE_INITIAL_OPACITY = 0.7;
const RIPPLE_RENDER_ORDER = 2;

export { RIPPLE_RENDER_ORDER };

/**
 * Creates a Points mesh that mirrors the source node's appearance and is
 * positioned at the node's local coordinates. Returns the mesh plus the
 * per-ripple state needed to drive the per-frame animation.
 */
export function createRipple({ position, color, baseSize, pixelRatio }) {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute(
    'position',
    new THREE.Float32BufferAttribute([position.x, position.y, position.z], 3),
  );
  const material = new THREE.ShaderMaterial({
    uniforms: {
      pixelRatio: { value: pixelRatio },
      size: { value: baseSize },
      color: { value: new THREE.Color(color[0], color[1], color[2]) },
      opacity: { value: RIPPLE_INITIAL_OPACITY },
    },
    vertexShader: RIPPLE_VERTEX_SHADER,
    fragmentShader: RIPPLE_FRAGMENT_SHADER,
    transparent: true,
    depthTest: false,
    depthWrite: false,
  });
  const mesh = new THREE.Points(geometry, material);
  return { mesh, baseSize, startTime: Date.now() };
}

/** Advances a ripple's size and opacity uniforms based on wall-clock time. */
export function tickRipple(ripple) {
  const phase = ((Date.now() - ripple.startTime) % RIPPLE_PERIOD_MS) / RIPPLE_PERIOD_MS;
  const { uniforms } = ripple.mesh.material;
  uniforms.size.value = ripple.baseSize * (1 + (RIPPLE_GROWTH_FACTOR - 1) * phase);
  uniforms.opacity.value = RIPPLE_INITIAL_OPACITY * (1 - phase);
}

/** Releases the GPU resources owned by a ripple mesh. */
export function disposeRipple(ripple) {
  ripple.mesh.geometry.dispose();
  ripple.mesh.material.dispose();
}
