// Shared edge primitives used by three_edges_2d.js, three_edges_3d.js, and interaction classes.
import * as THREE from 'three';
import { GRAPH_DEFAULTS } from '../constants';

const { GLOBE_RADIUS, NODE_HEIGHT, ARC_MIN_HEIGHT, CONNECTION_ARC_HEIGHT } = GRAPH_DEFAULTS;

const ARC_ANGLE_THRESHOLD = 0.01;
const ARC_LONG_THRESHOLD_SEGMENTS = 4;
const ARC_SHORT_THRESHOLD_SEGMENTS = 2;

/** Creates a straight LineCurve3 edge for 2D mode. */
export function createStraightLine(start, end) {
  return new THREE.LineCurve3(start, end);
}

/** Angle in radians between two direction vectors. */
function angleBetween(start, end) {
  const dot = start.clone().normalize().dot(end.clone().normalize());
  return Math.acos(Math.max(-1, Math.min(1, dot)));
}

/** Short-arc fallback: midpoint-elevated quadratic bezier for near-coincident points. */
function createShortArc(start, end) {
  const mid = start.clone().add(end).multiplyScalar(0.5);
  mid.normalize().multiplyScalar(GLOBE_RADIUS * ARC_MIN_HEIGHT);
  return new THREE.QuadraticBezierCurve3(start, mid, end);
}

/** Builds SLERP-interpolated control points for a CatmullRom spline arc. */
function buildSplineControlPoints(angle, start, end) {
  const startDir = start.clone().normalize();
  const endDir = end.clone().normalize();
  const sinAngle = Math.sin(angle);
  const arcHeight = Math.max(
    ARC_MIN_HEIGHT,
    NODE_HEIGHT + CONNECTION_ARC_HEIGHT * (angle / Math.PI),
  );
  const numSegments =
    angle > Math.PI / 2 ? ARC_LONG_THRESHOLD_SEGMENTS : ARC_SHORT_THRESHOLD_SEGMENTS;
  const controlPoints = [start.clone()];

  for (let i = 1; i < numSegments; i += 1) {
    const t = i / numSegments;
    const ctrlDir = startDir
      .clone()
      .multiplyScalar(Math.sin((1 - t) * angle) / sinAngle)
      .add(endDir.clone().multiplyScalar(Math.sin(t * angle) / sinAngle));

    const heightFactor = Math.sin(t * Math.PI);
    const pointHeight = NODE_HEIGHT + (arcHeight - NODE_HEIGHT) * heightFactor;
    controlPoints.push(ctrlDir.clone().multiplyScalar(GLOBE_RADIUS * pointHeight));
  }

  controlPoints.push(end.clone());
  return controlPoints;
}

/**
 * Creates a curved arc between two points on the globe surface.
 * Short arcs use a quadratic bezier; longer arcs use a CatmullRom spline
 * with height proportional to angular distance.
 */
export function createArcCurve(start, end) {
  const angle = angleBetween(start, end);
  if (angle < ARC_ANGLE_THRESHOLD) return createShortArc(start, end);

  const controlPoints = buildSplineControlPoints(angle, start, end);
  return new THREE.CatmullRomCurve3(controlPoints, false, 'catmullrom', 0.5);
}
