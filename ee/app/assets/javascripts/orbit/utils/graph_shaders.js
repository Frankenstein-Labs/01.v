// GLSL vertex and fragment shaders for graph node markers, globe atmosphere,
// and city lights.

// Renders graph nodes as circular point sprites with soft glow edge.
export const NODE_VERTEX_SHADER = `
  attribute vec3 color;
  attribute float size;
  varying vec3 vColor;
  uniform float pixelRatio;
  void main() {
    vColor = color;
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_PointSize = size * pixelRatio;
    gl_Position = projectionMatrix * mvPosition;
  }
`;

export const NODE_FRAGMENT_SHADER = `
  varying vec3 vColor;
  uniform float darkMode;
  void main() {
    float dist = length(gl_PointCoord - vec2(0.5));
    if (dist > 0.5) discard;
    float body = 1.0 - smoothstep(0.36, 0.39, dist);
    // Dark mode: subtle bright glow. Light mode: thin dark border.
    float ring = smoothstep(0.33, 0.36, dist) * (1.0 - smoothstep(0.39, 0.42, dist));
    vec3 ringColor = darkMode > 0.5 ? vColor * 1.3 : vColor * 0.4;
    float ringAlpha = darkMode > 0.5 ? 0.15 : 0.5;
    vec3 col = mix(ringColor, vColor, body);
    float alpha = max(body, ring * ringAlpha);
    gl_FragColor = vec4(col, alpha);
  }
`;

// Renders a soft filled disc that grows and fades, used as a loading
// indicator overlaid on the source node during expand.
export const RIPPLE_VERTEX_SHADER = `
  uniform float pixelRatio;
  uniform float size;
  void main() {
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_PointSize = size * pixelRatio;
    gl_Position = projectionMatrix * mvPosition;
  }
`;

export const RIPPLE_FRAGMENT_SHADER = `
  uniform vec3 color;
  uniform float opacity;
  void main() {
    float dist = length(gl_PointCoord - vec2(0.5));
    if (dist > 0.5) discard;
    float body = 1.0 - smoothstep(0.36, 0.39, dist);
    gl_FragColor = vec4(color, opacity * body);
  }
`;

// Renders the globe's atmospheric glow on the back face (dark mode).
export const ATMOSPHERE_VERTEX_SHADER = `
  varying vec3 vNormal;
  void main() {
    vNormal = normalize(normalMatrix * normal);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

export const ATMOSPHERE_FRAGMENT_SHADER = `
  varying vec3 vNormal;
  void main() {
    float rim = pow(0.7 - dot(vNormal, vec3(0.0, 0.0, 1.0)), 2.5);
    vec3 color = vec3(0.45, 0.60, 0.65);
    gl_FragColor = vec4(color, 1.0) * rim * 0.10;
  }
`;

// Light mode atmosphere: soft purple/blue rim glow
export const ATMOSPHERE_LIGHT_FRAGMENT_SHADER = `
  varying vec3 vNormal;
  void main() {
    float rim = pow(0.7 - dot(vNormal, vec3(0.0, 0.0, 1.0)), 2.5);
    vec3 color = mix(vec3(0.6, 0.4, 0.9), vec3(0.9, 0.55, 0.4), rim);
    gl_FragColor = vec4(color, rim * 0.35);
  }
`;

// Unified globe surface shader for both modes.
// uBase: centre colour. uRim: edge colour. uRimStrength: blend amount at silhouette.
// Dark mode: rim is slightly lighter/teal → edges brighten.
// Light mode: rim is slightly darker/lavender → edges darken.
export const GLOBE_SURFACE_VERTEX_SHADER = `
  varying vec3 vNormal;
  void main() {
    vNormal = normalize(normalMatrix * normal);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

export const GLOBE_SURFACE_FRAGMENT_SHADER = `
  uniform vec3 uBase;
  uniform vec3 uRim;
  uniform float uRimStrength;
  varying vec3 vNormal;
  void main() {
    float facing = max(0.0, dot(vNormal, vec3(0.0, 0.0, 1.0)));
    float t = pow(1.0 - facing, 3.0) * uRimStrength;
    gl_FragColor = vec4(mix(uBase, uRim, t), 1.0);
  }
`;

// Renders scattered city-light particles on the globe surface.
export const CITY_LIGHT_VERTEX_SHADER = `
  attribute float size;
  attribute vec3 color;
  varying vec3 vColor;
  uniform float pixelRatio;
  void main() {
    vColor = color;
    vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
    gl_PointSize = size * pixelRatio * (300.0 / -mvPosition.z);
    gl_Position = projectionMatrix * mvPosition;
  }
`;

export const CITY_LIGHT_FRAGMENT_SHADER = `
  varying vec3 vColor;
  void main() {
    float dist = length(gl_PointCoord - vec2(0.5));
    if (dist > 0.5) discard;
    float alpha = 1.0 - smoothstep(0.0, 0.5, dist);
    gl_FragColor = vec4(vColor, alpha * 0.8);
  }
`;
