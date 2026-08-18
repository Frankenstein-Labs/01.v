import CEGetStateKey from '~/vue_merge_request_widget/stores/get_state_key';
import {
  MWCP_MERGE_STRATEGY,
  MTWCP_MERGE_STRATEGY,
  MT_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';
import { stateKey as CEStateKey } from '~/vue_merge_request_widget/stores/state_maps';

export default function getStateKey() {
  if (this.isGeoSecondaryNode) {
    return 'geoSecondaryNode';
  }

  const strategies = [MWCP_MERGE_STRATEGY, MTWCP_MERGE_STRATEGY, MT_MERGE_STRATEGY];

  if (!this.autoMergeEnabled && strategies.includes(this.preferredAutoMergeStrategy)) {
    return CEStateKey.readyToMerge;
  }

  return CEGetStateKey.call(this);
}
