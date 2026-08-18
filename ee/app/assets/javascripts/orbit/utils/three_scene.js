// Manages the Three.js scene, perspective camera, WebGL renderer, and orbit controls.
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls';
import { GRAPH_DEFAULTS } from '../constants';

const {
  CAMERA_FOV,
  CAMERA_NEAR,
  CAMERA_FAR,
  CAMERA_DEFAULT_Z,
  CAMERA_MIN_ZOOM,
  CAMERA_MAX_ZOOM,
  CAMERA_2D_MIN_ZOOM,
  CAMERA_2D_MAX_ZOOM,
} = GRAPH_DEFAULTS;

export { CAMERA_DEFAULT_Z };

const FALLBACK_CONTAINER_HEIGHT = 500;
const MAX_PIXEL_RATIO = 2;
const DAMPING_FACTOR = 0.05;
const ZOOM_SPEED_2D = 2.5;

/** Manages the Three.js WebGL renderer, perspective camera, and orbit controls. */
export default class GraphScene {
  constructor(container) {
    this.container = container;
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.controls = null;
  }

  /** Creates the WebGL renderer, camera, and orbit controls, and appends the canvas. */
  init() {
    const width = this.container.offsetWidth;
    const height = this.container.offsetHeight || FALLBACK_CONTAINER_HEIGHT;

    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(CAMERA_FOV, width / height, CAMERA_NEAR, CAMERA_FAR);
    this.camera.position.z = CAMERA_DEFAULT_Z;

    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    this.renderer.setSize(width, height);
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, MAX_PIXEL_RATIO));
    this.container.appendChild(this.renderer.domElement);

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.minDistance = CAMERA_MIN_ZOOM;
    this.controls.maxDistance = CAMERA_MAX_ZOOM;
    this.controls.enableKeys = false;
    this.controls.enableDamping = true;
    this.controls.dampingFactor = DAMPING_FACTOR;
  }

  /** Disposes the renderer, removes the canvas from the DOM, and releases controls. */
  dispose() {
    this.scene.traverse((obj) => {
      if (obj.geometry) obj.geometry.dispose();
      if (obj.material) {
        if (Array.isArray(obj.material)) {
          obj.material.forEach((m) => {
            m.map?.dispose();
            m.dispose();
          });
        } else {
          obj.material.map?.dispose();
          obj.material.dispose();
        }
      }
    });

    this.renderer.dispose();
    if (this.renderer.domElement.parentNode) {
      this.renderer.domElement.parentNode.removeChild(this.renderer.domElement);
    }

    this.controls.dispose();
  }

  /** Configures controls for 2D panning (rotation disabled). */
  setMode2D() {
    this.controls.enableRotate = false;
    this.controls.screenSpacePanning = true;
    this.controls.mouseButtons = {
      LEFT: THREE.MOUSE.PAN,
      MIDDLE: THREE.MOUSE.DOLLY,
      RIGHT: THREE.MOUSE.PAN,
    };
    this.controls.minDistance = CAMERA_2D_MIN_ZOOM;
    this.controls.maxDistance = CAMERA_2D_MAX_ZOOM;
    this.controls.zoomSpeed = ZOOM_SPEED_2D;
    this.controls.target.set(0, 0, 0);
    this.camera.up.set(0, 1, 0);
    this.camera.lookAt(0, 0, 0);
    this.controls.update();
  }

  /** Configures controls for 3D orbit rotation. */
  setMode3D() {
    this.controls.enableRotate = true;
    this.controls.screenSpacePanning = false;
    this.controls.mouseButtons = {
      LEFT: THREE.MOUSE.ROTATE,
      MIDDLE: THREE.MOUSE.DOLLY,
      RIGHT: THREE.MOUSE.PAN,
    };
    this.controls.minDistance = CAMERA_MIN_ZOOM;
    this.controls.maxDistance = CAMERA_MAX_ZOOM;
    this.controls.target.set(0, 0, 0);
    this.controls.update();
  }

  /** Updates the camera aspect ratio and renderer size to match the viewport. */
  resize(width, height) {
    if (!this.renderer) return;
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height);
    if (this.controls) {
      this.controls.update();
      this.render();
    }
  }

  render() {
    this.renderer.render(this.scene, this.camera);
  }
}
