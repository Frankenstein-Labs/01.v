import { createArcCurve } from './three_edges';
import { buildConnections } from './three_edge_builder';

export function buildGlobeConnections(params) {
  return buildConnections({
    ...params,
    curveFactory: createArcCurve,
    includeArrow: false,
  });
}
