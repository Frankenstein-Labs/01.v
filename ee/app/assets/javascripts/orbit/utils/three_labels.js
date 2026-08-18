// Creates cached canvas-based text sprites for node and edge labels.
import * as THREE from 'three';

const EDGE_LABEL_HEIGHT = 28;
const EDGE_LABEL_FONT_SIZE = 13;
const EDGE_LABEL_SCALE = 0.004;
const NODE_LABEL_HEIGHT = 44;
const NODE_LABEL_FONT_SIZE = 18;
const NODE_LABEL_SCALE = 0.006;
const NODE_LABEL_MAX_CHARS = 20;

const CANVAS_TEXT_PADDING = 6;
const LABEL_RENDER_ORDER = 4;

const FONT_WEIGHT_BOLD = 'bold ';
const labelTextureCache = new Map();

/** Disposes all cached label textures and clears the cache. */
export function clearLabelCache() {
  for (const { texture } of labelTextureCache.values()) {
    texture.dispose();
  }
  labelTextureCache.clear();
}

/** Creates a canvas-rendered text sprite, using a texture cache for repeat labels. */
export function createTextSprite(text, { fontSize, height, scale, color, bold }) {
  const cacheKey = `${text}:${fontSize}:${color}`;
  if (labelTextureCache.has(cacheKey)) {
    const cached = labelTextureCache.get(cacheKey);
    const mat = new THREE.SpriteMaterial({
      map: cached.texture,
      transparent: true,
      depthTest: false,
    });
    const sprite = new THREE.Sprite(mat);
    sprite.scale.set(cached.width * scale, height * scale, 1);
    sprite.renderOrder = LABEL_RENDER_ORDER;
    return sprite;
  }

  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  const weight = bold ? FONT_WEIGHT_BOLD : '';
  const font = `${weight}${fontSize}px sans-serif`;
  ctx.font = font;
  const metrics = ctx.measureText(text);
  const padding = CANVAS_TEXT_PADDING;
  const w = Math.ceil(metrics.width) + padding * 2;
  canvas.width = w;
  canvas.height = height;

  ctx.font = font;
  ctx.fillStyle = color;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(text, w / 2, height / 2);

  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;
  labelTextureCache.set(cacheKey, { texture, width: w });

  const material = new THREE.SpriteMaterial({ map: texture, transparent: true, depthTest: false });
  const sprite = new THREE.Sprite(material);
  sprite.scale.set(w * scale, height * scale, 1);
  sprite.renderOrder = 4;
  return sprite;
}

/** Creates a semi-transparent text sprite for edge relationship labels. */
export function createEdgeLabelSprite(text, darkMode = true) {
  return createTextSprite(text, {
    fontSize: EDGE_LABEL_FONT_SIZE,
    height: EDGE_LABEL_HEIGHT,
    scale: EDGE_LABEL_SCALE,
    color: darkMode ? 'rgba(255, 255, 255, 0.5)' : 'rgba(0, 0, 0, 0.6)',
    bold: false,
  });
}

/** Creates a bold text sprite for node name labels. */
export function createNodeLabelSprite(text, darkMode = true, sizeMultiplier = 1) {
  const label =
    text.length > NODE_LABEL_MAX_CHARS ? `${text.slice(0, NODE_LABEL_MAX_CHARS)}...` : text;
  return createTextSprite(label, {
    fontSize: NODE_LABEL_FONT_SIZE,
    height: NODE_LABEL_HEIGHT,
    scale: NODE_LABEL_SCALE * sizeMultiplier,
    color: darkMode ? 'rgba(255, 255, 255, 0.75)' : 'rgba(60, 60, 80, 0.8)',
    bold: false,
  });
}

const ICON_CANVAS_SIZE = 64;
const ICON_SPRITE_SCALE = 0.0045;

/* eslint-disable @gitlab/require-i18n-strings */
const ICON_PATHS = {
  group:
    'M6 4a1.5 1.5 0 11-3 0 1.5 1.5 0 013 0zm1.5 0a3 3 0 11-6 0 3 3 0 016 0zm4 5.5a1.5 1.5 0 100-3 1.5 1.5 0 000 3zm0 1.5a3 3 0 100-6 3 3 0 000 6zm-7 2.5a1.5 1.5 0 100-3 1.5 1.5 0 000 3zm0 1.5a3 3 0 100-6 3 3 0 000 6z',
  project:
    'M9.5 14.5l-6-2.5V4l6-2.5v13zm-6.885-1.244A1 1 0 012 12.333V3.667a1 1 0 01.615-.923L8.923.115A1.5 1.5 0 0111 1.5V2h1.25c.966 0 1.75.783 1.75 1.75v8.5A1.75 1.75 0 0112.25 14H11v.5a1.5 1.5 0 01-2.077 1.385l-6.308-2.629zM11 12.5h1.25a.25.25 0 00.25-.25v-8.5a.25.25 0 00-.25-.25H11v9z',
  user: 'M8 9a3.5 3.5 0 100-7 3.5 3.5 0 000 7zm0-1.5a2 2 0 110-4 2 2 0 010 4zm5.5 7a.75.75 0 01-1.5 0C12 12.02 10.21 10.5 8 10.5S4 12.02 4 14.5a.75.75 0 01-1.5 0C2.5 11.16 4.97 9 8 9s5.5 2.16 5.5 5.5z',
  comment:
    'M2.75 2A1.75 1.75 0 001 3.75v6.5c0 .966.784 1.75 1.75 1.75H4v2.25a.75.75 0 001.19.61L8.07 12h4.18A1.75 1.75 0 0014 10.25v-6.5A1.75 1.75 0 0012.25 2H2.75zM2.5 3.75a.25.25 0 01.25-.25h9.5a.25.25 0 01.25.25v6.5a.25.25 0 01-.25.25H7.75a.75.75 0 00-.47.166L5.5 12.19V11.25a.75.75 0 00-.75-.75H2.75a.25.25 0 01-.25-.25v-6.5z',
  'merge-request':
    'M5 4.25a1.25 1.25 0 11-2.5 0 1.25 1.25 0 012.5 0zM3.75 7A2.75 2.75 0 103 4.393V11.5a.75.75 0 001.5 0V4.393A2.751 2.751 0 003.75 7zm9.5 4.75a1.25 1.25 0 11-2.5 0 1.25 1.25 0 012.5 0zm-.75 2.75a2.75 2.75 0 10-1.5-5.035V4.25a.75.75 0 00-.75-.75H8.5V2.06l1.22 1.22a.75.75 0 101.06-1.06l-2.5-2.5a.75.75 0 00-1.06 0l-2.5 2.5a.75.75 0 001.06 1.06L7 2.06V3.5a.75.75 0 00.75.75h1.75v5.215a2.751 2.751 0 002 5.035z',
  pipeline:
    'M5.75 4.5a.75.75 0 100-1.5.75.75 0 000 1.5zM5.75 6a2.25 2.25 0 10-.001-4.501A2.25 2.25 0 005.75 6zm4.5 5.5a.75.75 0 100-1.5.75.75 0 000 1.5zm0 1.5a2.25 2.25 0 10-.001-4.501A2.25 2.25 0 0010.25 13zM7.5 4.25a.75.75 0 01.75-.75h4a.75.75 0 010 1.5h-4a.75.75 0 01-.75-.75zm-4 7.5a.75.75 0 01.75-.75h4a.75.75 0 010 1.5h-4a.75.75 0 01-.75-.75z',
  shield:
    'M8.048 1.164a.75.75 0 00-.096 0l-5.25.55A.75.75 0 002 2.457v5.14c0 3.481 2.22 6.023 5.853 7.337a.75.75 0 00.494 0C11.98 13.62 14 11.078 14 7.597v-5.14a.75.75 0 00-.702-.743l-5.25-.55zM3.5 3.147l4.5-.472 4.5.472v4.45c0 2.786-1.74 4.856-4.5 5.94-2.76-1.084-4.5-3.154-4.5-5.94v-4.45z',
  branch:
    'M4.75 3.5a.75.75 0 100-1.5.75.75 0 000 1.5zM4.75 5a2.25 2.25 0 10-1.5-3.932v7.864a2.25 2.25 0 101.5 0V7.803A3.987 3.987 0 007 9h2.197a2.25 2.25 0 100-1.5H7A2.5 2.5 0 014.75 5zm0 7.5a.75.75 0 100 1.5.75.75 0 000-1.5zm6.5-3.5a.75.75 0 100-1.5.75.75 0 000 1.5z',
  label:
    'M3.75 2A1.75 1.75 0 002 3.75v2.42c0 .464.184.909.513 1.237l5.97 5.97a1.75 1.75 0 002.474 0l3.42-3.42a1.75 1.75 0 000-2.474l-5.97-5.97A1.75 1.75 0 007.17 1.25H3.75zM3.5 3.75a.25.25 0 01.25-.25h3.42a.25.25 0 01.177.073l5.97 5.97a.25.25 0 010 .354l-3.42 3.42a.25.25 0 01-.354 0l-5.97-5.97A.25.25 0 013.5 7.17V3.75zM6 5.5a.5.5 0 11-1 0 .5.5 0 011 0z',
  folder:
    'M1.75 3A1.75 1.75 0 000 4.75v7.5C0 13.216.784 14 1.75 14h12.5A1.75 1.75 0 0016 12.25v-6.5A1.75 1.75 0 0014.25 4H8.42L7.218 2.371A1.75 1.75 0 005.801 1.75H1.75zM1.5 4.75a.25.25 0 01.25-.25h4.051a.25.25 0 01.199.099L7.399 6.3a.75.75 0 00.601.2h6.25a.25.25 0 01.25.25v5.5a.25.25 0 01-.25.25H1.75a.25.25 0 01-.25-.25v-7.5z',
};
/* eslint-enable @gitlab/require-i18n-strings */

export function createIconSprite(iconName, color = '#ffffff', sizeMultiplier = 1) {
  const pathData = ICON_PATHS[iconName];
  const size = ICON_CANVAS_SIZE;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;

  if (pathData) {
    const ctx = canvas.getContext('2d');
    const pad = size * 0.15;
    const drawSize = size - pad * 2;
    const drawScale = drawSize / 16;
    ctx.translate(pad, pad);
    ctx.scale(drawScale, drawScale);
    const path = new Path2D(pathData);
    ctx.fillStyle = color;
    ctx.fill(path, 'evenodd');
  }

  const texture = new THREE.CanvasTexture(canvas);
  texture.minFilter = THREE.LinearFilter;

  const material = new THREE.SpriteMaterial({
    map: texture,
    transparent: true,
    depthTest: false,
    alphaTest: 0.05,
  });
  const sprite = new THREE.Sprite(material);
  const s = size * ICON_SPRITE_SCALE * sizeMultiplier;
  sprite.scale.set(s, s, 1);
  sprite.renderOrder = LABEL_RENDER_ORDER;
  return sprite;
}
