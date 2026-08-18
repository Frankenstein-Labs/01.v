import { s__ } from '~/locale';
import CEAutoMergeMixin from '~/vue_merge_request_widget/mixins/auto_merge';
import {
  MT_MERGE_STRATEGY,
  MTWCP_MERGE_STRATEGY,
  MWCP_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';

export default {
  computed: {
    statusText() {
      const { mergeTrains, mergeRequest } = this.state;

      const mergeTrainsCount = mergeTrains?.nodes[0]?.cars?.count || 0;
      const { autoMergeStrategy } = mergeRequest;

      if (autoMergeStrategy === MT_MERGE_STRATEGY) {
        return s__('mrWidget|Added to the merge train by %{merge_author}');
      }
      if (autoMergeStrategy === MTWCP_MERGE_STRATEGY && mergeTrainsCount === 0) {
        return s__(
          'mrWidget|Set by %{merge_author} to start a merge train when all merge checks pass',
        );
      }
      if (autoMergeStrategy === MTWCP_MERGE_STRATEGY && mergeTrainsCount !== 0) {
        return s__(
          'mrWidget|Set by %{merge_author} to be added to the merge train when all merge checks pass',
        );
      }
      if (autoMergeStrategy === MWCP_MERGE_STRATEGY) {
        return s__(
          'mrWidget|Set by %{merge_author} to be merged automatically when all merge checks pass',
        );
      }

      return CEAutoMergeMixin.computed.statusText.call(this);
    },
    cancelButtonText() {
      if (this.state?.mergeRequest?.autoMergeStrategy === MT_MERGE_STRATEGY) {
        return s__('mrWidget|Remove from merge train');
      }

      return s__('mrWidget|Cancel auto-merge');
    },
  },
};
