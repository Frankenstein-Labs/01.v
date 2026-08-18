import { createStraightLine } from './three_edges';
import { buildConnections } from './three_edge_builder';

export function buildFlatConnections(params) {
  return buildConnections({
    ...params,
    curveFactory: createStraightLine,
    includeArrow: true,
  });
}
