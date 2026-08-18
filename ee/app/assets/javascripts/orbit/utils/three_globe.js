// Creates the globe mesh, atmospheric glow, and decorative particles.
import * as THREE from 'three';
import { GRAPH_DEFAULTS } from '../constants';
import {
  ATMOSPHERE_VERTEX_SHADER,
  ATMOSPHERE_FRAGMENT_SHADER,
  ATMOSPHERE_LIGHT_FRAGMENT_SHADER,
  CITY_LIGHT_VERTEX_SHADER,
  CITY_LIGHT_FRAGMENT_SHADER,
  GLOBE_SURFACE_VERTEX_SHADER,
  GLOBE_SURFACE_FRAGMENT_SHADER,
} from './graph_shaders';

const { GLOBE_RADIUS, CITY_LIGHT_COUNT } = GRAPH_DEFAULTS;

const SPHERE_SEGMENTS = 64;
const ATMOSPHERE_SCALE = 1.02;
const CITY_LIGHT_OFFSET = 1.001;
const CITY_LIGHT_MIN_SIZE = 0.015;
const CITY_LIGHT_MAX_SIZE = 0.04;

const GLOBE_DARK_BASE = 0x090d13;
const GLOBE_DARK_RIM = 0x1e3440;
const GLOBE_DARK_RIM_STRENGTH = 0.85;
const GLOBE_LIGHT_BASE = 0xe8e0ec;
const GLOBE_LIGHT_RIM = 0x7a6e8e;
const GLOBE_LIGHT_RIM_STRENGTH = 0.55;

const WARMTH_BASE = 0.8;
const WARMTH_VARIANCE = 0.2;
const WARMTH_GREEN_FACTOR = 0.85;
const WARMTH_BLUE_FACTOR = 0.5;

// Light mode globe gradient
const LIGHT_DOT_COUNT = 800;
const LIGHT_DOT_OFFSET = 1.002;
const LIGHT_DOT_MIN_SIZE = 0.008;
const LIGHT_DOT_MAX_SIZE = 0.02;

function randomSpherePoint(radius) {
  const u = Math.random();
  const v = Math.random();
  const theta = 2 * Math.PI * u;
  const phi = Math.acos(2 * v - 1);
  return new THREE.Vector3(
    radius * Math.sin(phi) * Math.cos(theta),
    radius * Math.sin(phi) * Math.sin(theta),
    radius * Math.cos(phi),
  );
}

/** Creates the globe sphere mesh and atmospheric glow shell. */
export function createGlobe(globeGroup, darkMode) {
  const earthGeometry = new THREE.SphereGeometry(GLOBE_RADIUS, SPHERE_SEGMENTS, SPHERE_SEGMENTS);

  const earthMaterial = new THREE.ShaderMaterial({
    uniforms: darkMode
      ? {
          uBase: { value: new THREE.Color(GLOBE_DARK_BASE) },
          uRim: { value: new THREE.Color(GLOBE_DARK_RIM) },
          uRimStrength: { value: GLOBE_DARK_RIM_STRENGTH },
        }
      : {
          uBase: { value: new THREE.Color(GLOBE_LIGHT_BASE) },
          uRim: { value: new THREE.Color(GLOBE_LIGHT_RIM) },
          uRimStrength: { value: GLOBE_LIGHT_RIM_STRENGTH },
        },
    vertexShader: GLOBE_SURFACE_VERTEX_SHADER,
    fragmentShader: GLOBE_SURFACE_FRAGMENT_SHADER,
  });
  const earth = new THREE.Mesh(earthGeometry, earthMaterial);
  earth.renderOrder = 0;
  globeGroup.add(earth);

  const atmosphereGeometry = new THREE.SphereGeometry(
    GLOBE_RADIUS * ATMOSPHERE_SCALE,
    SPHERE_SEGMENTS,
    SPHERE_SEGMENTS,
  );
  const atmosphereMaterial = new THREE.ShaderMaterial({
    vertexShader: ATMOSPHERE_VERTEX_SHADER,
    fragmentShader: darkMode ? ATMOSPHERE_FRAGMENT_SHADER : ATMOSPHERE_LIGHT_FRAGMENT_SHADER,
    blending: darkMode ? THREE.AdditiveBlending : THREE.NormalBlending,
    side: THREE.BackSide,
    transparent: true,
  });
  const atmosphere = new THREE.Mesh(atmosphereGeometry, atmosphereMaterial);
  globeGroup.add(atmosphere);
}

/** Creates decorative point particles scattered across the globe surface. */
export function createCityLights(globeGroup, renderer, darkMode) {
  if (darkMode) {
    // Warm city lights for dark mode
    const positions = [];
    const colors = [];
    const sizes = [];

    for (let i = 0; i < CITY_LIGHT_COUNT; i += 1) {
      const pos = randomSpherePoint(GLOBE_RADIUS * CITY_LIGHT_OFFSET);
      positions.push(pos.x, pos.y, pos.z);
      const warmth = WARMTH_BASE + Math.random() * WARMTH_VARIANCE;
      colors.push(warmth, warmth * WARMTH_GREEN_FACTOR, warmth * WARMTH_BLUE_FACTOR);
      sizes.push(CITY_LIGHT_MIN_SIZE + Math.random() * (CITY_LIGHT_MAX_SIZE - CITY_LIGHT_MIN_SIZE));
    }

    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geometry.setAttribute('size', new THREE.Float32BufferAttribute(sizes, 1));

    const material = new THREE.ShaderMaterial({
      uniforms: { pixelRatio: { value: renderer.getPixelRatio() } },
      vertexShader: CITY_LIGHT_VERTEX_SHADER,
      fragmentShader: CITY_LIGHT_FRAGMENT_SHADER,
      transparent: true,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    });

    globeGroup.add(new THREE.Points(geometry, material));
  } else {
    // Subtle dots for light mode
    const positions = [];
    const colors = [];
    const sizes = [];

    for (let i = 0; i < LIGHT_DOT_COUNT; i += 1) {
      const pos = randomSpherePoint(GLOBE_RADIUS * LIGHT_DOT_OFFSET);
      positions.push(pos.x, pos.y, pos.z);
      // Soft purple/blue/teal dots
      const hue = 0.55 + Math.random() * 0.15;
      const c = new THREE.Color().setHSL(hue, 0.3, 0.75);
      colors.push(c.r, c.g, c.b);
      sizes.push(LIGHT_DOT_MIN_SIZE + Math.random() * (LIGHT_DOT_MAX_SIZE - LIGHT_DOT_MIN_SIZE));
    }

    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geometry.setAttribute('size', new THREE.Float32BufferAttribute(sizes, 1));

    const material = new THREE.ShaderMaterial({
      uniforms: { pixelRatio: { value: renderer.getPixelRatio() } },
      vertexShader: CITY_LIGHT_VERTEX_SHADER,
      fragmentShader: CITY_LIGHT_FRAGMENT_SHADER,
      transparent: true,
      blending: THREE.NormalBlending,
      depthWrite: false,
    });

    globeGroup.add(new THREE.Points(geometry, material));
  }
}
