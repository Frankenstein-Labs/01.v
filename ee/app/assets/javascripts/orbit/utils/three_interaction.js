// Handles mouse and keyboard interaction with the 3D graph: hover highlighting,
// click selection, drag-to-move, and double-click expansion.
import * as THREE from 'three';
import { GRAPH_DEFAULTS } from '../constants';
import { createStraightLine } from './three_edges';
import { NODE_LABEL_OFFSET } from './three_nodes';

const { NODE_BASE_SIZE, NODE_HOVER_EXTRA, EDGE_CURVE_SEGMENTS, HOVER_THRESHOLD } = GRAPH_DEFAULTS;

const ARROW_OFFSET = 0.18;

/**
 * Handles mouse/keyboard interaction with the graph: hover highlighting,
 * click selection, drag-to-move nodes, and double-click expansion.
 */
export default class GraphInteraction {
  constructor({ renderer, camera, controls, globeGroup }) {
    this.renderer = renderer;
    this.camera = camera;
    this.controls = controls;
    this.globeGroup = globeGroup;

    this.mouseX = 0;
    this.mouseY = 0;
    this.hoveredNode = null;

    this.dragNode = null;
    this.dragPlane = new THREE.Plane();
    this.dragRaycaster = new THREE.Raycaster();
    this.dragOffset = new THREE.Vector3();
    this.didDrag = false;

    this.onNodeHoverCallback = null;
    this.onNodeSelectCallback = null;
    this.onNodeExpandCallback = null;

    this.lastInteractionTime = Date.now();

    this.boundMouseMove = this.handleMouseMove.bind(this);
    this.boundMouseDown = this.handleMouseDown.bind(this);
    this.boundMouseUp = this.handleMouseUp.bind(this);
    this.boundClick = this.handleClick.bind(this);
    this.boundDblClick = this.handleDblClick.bind(this);
    this.boundKeyDown = this.handleKeyDown.bind(this);
  }

  setContext({
    nodes,
    nodeGeometry,
    originalNodeSizes,
    nodeLabelsGroup,
    connections,
    selectNode,
    deselectNode,
  }) {
    this.nodes = nodes;
    this.nodeGeometry = nodeGeometry;
    this.originalNodeSizes = originalNodeSizes;
    this.nodeLabelsGroup = nodeLabelsGroup;
    this.connections = connections;
    this.selectNode = selectNode;
    this.deselectNode = deselectNode;
  }

  onNodeHover(callback) {
    this.onNodeHoverCallback = callback;
  }

  onNodeSelect(callback) {
    this.onNodeSelectCallback = callback;
  }

  onNodeExpand(callback) {
    this.onNodeExpandCallback = callback;
  }

  attach() {
    this.renderer.domElement.addEventListener('mousemove', this.boundMouseMove);
    this.renderer.domElement.addEventListener('mousedown', this.boundMouseDown);
    this.renderer.domElement.addEventListener('mouseup', this.boundMouseUp);
    this.renderer.domElement.addEventListener('click', this.boundClick);
    this.renderer.domElement.addEventListener('dblclick', this.boundDblClick);
    document.addEventListener('keydown', this.boundKeyDown);
  }

  detach() {
    this.renderer.domElement.removeEventListener('mousemove', this.boundMouseMove);
    this.renderer.domElement.removeEventListener('mousedown', this.boundMouseDown);
    this.renderer.domElement.removeEventListener('mouseup', this.boundMouseUp);
    this.renderer.domElement.removeEventListener('click', this.boundClick);
    this.renderer.domElement.removeEventListener('dblclick', this.boundDblClick);
    document.removeEventListener('keydown', this.boundKeyDown);
  }

  /** Projects each visible node to screen space and returns the closest to the cursor. */
  findNearestNode(mx, my, nodes) {
    let nearest = null;
    let nearestDist = Infinity;

    nodes.forEach((node) => {
      if (!this.isNodeVisible(node)) return;

      const worldPos = new THREE.Vector3(node.position.x, node.position.y, node.position.z);
      this.globeGroup.localToWorld(worldPos);
      const screenPos = worldPos.clone().project(this.camera);

      if (screenPos.z >= 1) return;

      const dx = screenPos.x - mx;
      const dy = screenPos.y - my;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = { node, screenPos, dist };
      }
    });

    return nearest && nearestDist < HOVER_THRESHOLD ? nearest : null;
  }

  /** Returns true if the node should be considered for hover/click. Override in subclasses. */
  // eslint-disable-next-line class-methods-use-this
  isNodeVisible(node) {
    return Boolean(node.position);
  }

  /** Returns the curve to use when rebuilding edges during drag. Override in subclasses. */
  // eslint-disable-next-line class-methods-use-this
  getCurveForDrag(startPos, endPos) {
    return createStraightLine(startPos, endPos);
  }

  /** Projects a node's world position to pixel coordinates in the viewport. */
  getScreenPosition(node) {
    if (!node.position) return null;
    const worldPos = new THREE.Vector3(node.position.x, node.position.y, node.position.z);
    this.globeGroup.localToWorld(worldPos);
    const screenPos = worldPos.clone().project(this.camera);

    const rect = this.renderer.domElement.getBoundingClientRect();
    return {
      x: ((screenPos.x + 1) / 2) * rect.width,
      y: ((-screenPos.y + 1) / 2) * rect.height,
    };
  }

  /** Repositions a dragged node and rebuilds its connected edge curves. */
  moveNode(node, newPos, { nodeGeometry, nodeLabelsGroup, connections }) {
    // eslint-disable-next-line no-param-reassign -- mutates in-place by design
    node.position = { x: newPos.x, y: newPos.y, z: newPos.z };

    if (nodeGeometry) {
      const posAttr = nodeGeometry.getAttribute('position');
      posAttr.setXYZ(node.index, newPos.x, newPos.y, newPos.z);
      posAttr.needsUpdate = true;
    }

    const label = node.labelIndex >= 0 ? nodeLabelsGroup.children[node.labelIndex] : null;
    if (label) {
      label.position.set(newPos.x, newPos.y - NODE_LABEL_OFFSET, newPos.z);
      // Update userData for 2D counter-scaling
      if (label.userData.nodeY !== undefined) {
        label.userData.nodeY = newPos.y;
        label.userData.baseY = newPos.y - NODE_LABEL_OFFSET;
      }
    }

    connections.forEach((conn) => {
      if (conn.source !== node.index && conn.target !== node.index) return;

      const a = this.nodes[conn.source];
      const b = this.nodes[conn.target];
      const startPos = new THREE.Vector3(a.position.x, a.position.y, a.position.z);
      const endPos = new THREE.Vector3(b.position.x, b.position.y, b.position.z);
      const curve = this.getCurveForDrag(startPos, endPos);
      conn.curve = curve; // eslint-disable-line no-param-reassign -- mutates in-place by design

      const points = curve.getPoints(EDGE_CURVE_SEGMENTS);
      conn.line.geometry.dispose();
      conn.line.geometry = new THREE.BufferGeometry().setFromPoints(points); // eslint-disable-line no-param-reassign -- mutates in-place by design

      if (conn.label) {
        conn.label.position.copy(curve.getPoint(0.5));
      }

      if (conn.arrow) {
        const dir = endPos.clone().sub(startPos).normalize();
        conn.arrow.position.copy(endPos.clone().sub(dir.clone().multiplyScalar(ARROW_OFFSET)));
        conn.arrow.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
      }
    });
  }

  handleMouseMove(event) {
    this.lastInteractionTime = Date.now();
    const rect = this.renderer.domElement.getBoundingClientRect();
    this.mouseX = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    this.mouseY = -((event.clientY - rect.top) / rect.height) * 2 + 1;

    if (this.dragNode) {
      this.didDrag = true;
      this.renderer.domElement.style.cursor = 'grabbing';
      this.dragRaycaster.setFromCamera({ x: this.mouseX, y: this.mouseY }, this.camera);
      const target = new THREE.Vector3();
      this.dragRaycaster.ray.intersectPlane(this.dragPlane, target);
      if (target) {
        this.globeGroup.worldToLocal(target);
        this.moveNode(this.dragNode, target, {
          nodeGeometry: this.nodeGeometry,
          nodeLabelsGroup: this.nodeLabelsGroup,
          connections: this.connections,
        });
      }
      return;
    }

    const result = this.findNearestNode(this.mouseX, this.mouseY, this.nodes);

    if (result) {
      if (this.hoveredNode !== result.node) {
        if (this.hoveredNode && this.nodeGeometry) {
          const sizeAttr = this.nodeGeometry.getAttribute('size');
          sizeAttr.setX(this.hoveredNode.index, this.originalNodeSizes[this.hoveredNode.index]);
          sizeAttr.needsUpdate = true;
        }

        this.hoveredNode = result.node;

        if (this.nodeGeometry) {
          const sizeAttr = this.nodeGeometry.getAttribute('size');
          sizeAttr.setX(
            this.hoveredNode.index,
            (this.hoveredNode.baseSize || NODE_BASE_SIZE) + NODE_HOVER_EXTRA,
          );
          sizeAttr.needsUpdate = true;
        }

        if (this.onNodeHoverCallback) {
          const pos = this.getScreenPosition(this.hoveredNode);
          this.onNodeHoverCallback(this.hoveredNode, pos);
        }
      }
      this.renderer.domElement.style.cursor = 'pointer';
    } else {
      if (this.hoveredNode && this.nodeGeometry) {
        const sizeAttr = this.nodeGeometry.getAttribute('size');
        sizeAttr.setX(this.hoveredNode.index, this.originalNodeSizes[this.hoveredNode.index]);
        sizeAttr.needsUpdate = true;
      }
      this.hoveredNode = null;
      this.renderer.domElement.style.cursor = 'grab';
      if (this.onNodeHoverCallback) {
        this.onNodeHoverCallback(null, null);
      }
    }
  }

  handleMouseDown() {
    if (!this.hoveredNode) return;
    this.dragNode = this.hoveredNode;
    this.didDrag = false;
    this.controls.enabled = false;

    const nodeWorldPos = new THREE.Vector3(
      this.dragNode.position.x,
      this.dragNode.position.y,
      this.dragNode.position.z,
    );
    this.globeGroup.localToWorld(nodeWorldPos);

    const cameraDir = this.camera.position.clone().sub(nodeWorldPos).normalize();
    this.dragPlane.setFromNormalAndCoplanarPoint(cameraDir, nodeWorldPos);
  }

  handleMouseUp() {
    if (!this.dragNode) return;
    this.dragNode = null;
    this.controls.enabled = true;
    this.renderer.domElement.style.cursor = this.hoveredNode ? 'pointer' : 'grab';
  }

  handleClick() {
    this.lastInteractionTime = Date.now();
    if (this.didDrag) return;
    if (this.hoveredNode) {
      this.selectNode(this.hoveredNode.index);
    } else {
      this.deselectNode();
    }
  }

  handleDblClick() {
    this.lastInteractionTime = Date.now();
    if (this.hoveredNode && this.onNodeExpandCallback) {
      this.onNodeExpandCallback(this.hoveredNode);
    }
  }

  handleKeyDown(event) {
    if (event.key === 'Escape') {
      this.deselectNode();
    }
  }
}
