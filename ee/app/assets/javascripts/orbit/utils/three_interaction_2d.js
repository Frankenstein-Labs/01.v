import GraphInteraction from './three_interaction';
import { createStraightLine } from './three_edges';

export default class GraphInteraction2D extends GraphInteraction {
  // eslint-disable-next-line class-methods-use-this
  isNodeVisible(node) {
    return Boolean(node.position);
  }

  // eslint-disable-next-line class-methods-use-this
  getCurveForDrag(startPos, endPos) {
    return createStraightLine(startPos, endPos);
  }
}
