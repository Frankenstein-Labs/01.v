import * as THREE from 'three';
import { GRAPH_DEFAULTS } from '../constants';
import { createEdgeLabelSprite } from './three_labels';
import { disposeGroupChildren } from './three_nodes';

const {
  EDGE_OPACITY,
  EDGE_CURVE_SEGMENTS,
  CONNECTION_COLOR_DARK,
  CONNECTION_COLOR_LIGHT,
  LIGHT_MODE_EDGE_OPACITY,
  ARROW_OFFSET,
  ARROW_RADIUS,
  ARROW_HEIGHT,
  ARROW_RADIAL_SEGMENTS,
  ARROW_OPACITY_BOOST,
} = GRAPH_DEFAULTS;

function buildDirectionalArrow(startPos, endPos, connectionColor) {
  const dir = endPos.clone().sub(startPos).normalize();
  const arrowPos = endPos.clone().sub(dir.clone().multiplyScalar(ARROW_OFFSET));
  const arrow = new THREE.Mesh(
    new THREE.ConeGeometry(ARROW_RADIUS, ARROW_HEIGHT, ARROW_RADIAL_SEGMENTS),
    new THREE.MeshBasicMaterial({
      color: connectionColor,
      transparent: true,
      opacity: EDGE_OPACITY + ARROW_OPACITY_BOOST,
      depthTest: false,
    }),
  );
  arrow.position.copy(arrowPos);
  arrow.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
  return arrow;
}

/**
 * Build curved/flat edges shared by 2D and 3D graphs.
 *
 * @param curveFactory  (start, end) => THREE.Curve
 * @param includeArrow  whether to add a cone arrowhead (2D only)
 */
export function buildConnections({
  edges,
  nodes,
  darkMode,
  connectionsGroup,
  labelsGroup,
  curveFactory,
  includeArrow = false,
}) {
  disposeGroupChildren(connectionsGroup);
  disposeGroupChildren(labelsGroup);
  connectionsGroup.clear();
  labelsGroup.clear();

  const connections = [];
  const usedPairs = new Set();

  edges.forEach((edge) => {
    const nodeA = nodes[edge.source];
    const nodeB = nodes[edge.target];
    if (!nodeA?.position || !nodeB?.position || edge.source === edge.target) return;

    const key = `${Math.min(edge.source, edge.target)}-${Math.max(edge.source, edge.target)}`;
    if (usedPairs.has(key)) return;
    usedPairs.add(key);

    const startPos = new THREE.Vector3(nodeA.position.x, nodeA.position.y, nodeA.position.z);
    const endPos = new THREE.Vector3(nodeB.position.x, nodeB.position.y, nodeB.position.z);

    const connectionColor = darkMode ? CONNECTION_COLOR_DARK : CONNECTION_COLOR_LIGHT;
    const curve = curveFactory(startPos, endPos);
    const curvePoints = curve.getPoints(EDGE_CURVE_SEGMENTS);
    const geometry = new THREE.BufferGeometry().setFromPoints(curvePoints);
    const material = new THREE.LineBasicMaterial({
      color: connectionColor,
      transparent: true,
      opacity: darkMode ? EDGE_OPACITY : LIGHT_MODE_EDGE_OPACITY,
      depthTest: true,
      depthWrite: false,
    });
    const line = new THREE.Line(geometry, material);

    const connection = { line, curve, source: edge.source, target: edge.target, arrow: null };
    connections.push(connection);
    connectionsGroup.add(line);

    if (includeArrow) {
      connection.arrow = buildDirectionalArrow(startPos, endPos, connectionColor);
      connectionsGroup.add(connection.arrow);
    }

    if (edge.type) {
      const label = createEdgeLabelSprite(edge.type, darkMode);
      const midpoint = curve.getPoint(0.5);
      label.position.copy(midpoint);
      label.visible = false;
      connection.label = label;
      labelsGroup.add(label);
    }
  });

  return { connections };
}
