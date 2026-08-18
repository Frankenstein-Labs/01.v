import * as THREE from 'three';
import GraphInteraction from './three_interaction';
import { createArcCurve } from './three_edges';

export default class GraphInteraction3D extends GraphInteraction {
  isNodeVisible(node) {
    if (!node.position) return false;

    const worldPos = new THREE.Vector3(node.position.x, node.position.y, node.position.z);
    this.globeGroup.localToWorld(worldPos);

    const globeCenter = new THREE.Vector3();
    this.globeGroup.getWorldPosition(globeCenter);
    const nodeDir = worldPos.clone().sub(globeCenter).normalize();
    const cameraDir = this.camera.position.clone().sub(globeCenter).normalize();

    return nodeDir.dot(cameraDir) > 0;
  }

  // eslint-disable-next-line class-methods-use-this
  getCurveForDrag(startPos, endPos) {
    return createArcCurve(startPos, endPos);
  }
}
