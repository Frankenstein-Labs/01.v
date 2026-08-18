import { isNumber, isString } from 'lodash-es';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import { __, s__ } from '~/locale';
import {
  MT_MERGE_STRATEGY,
  PIPELINE_FAILED_STATE,
  MTWCP_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';
import CEReadyToMergeMixin from '~/vue_merge_request_widget/mixins/ready_to_merge';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

export const MERGE_DISABLED_TEXT_UNAPPROVED = s__(
  'mrWidget|Merge blocked: all required approvals must be given.',
);
export const PIPELINE_MUST_SUCCEED_CONFLICT_TEXT = __(
  'A CI/CD pipeline must run and be successful before merge.',
);
export const MERGE_DISABLED_DEPENDENCIES_TEXT = __(
  'Merge blocked: Merge all open dependent merge requests, and remove all closed dependencies.',
);
const MERGE_TRAINS_HELP = helpPagePath('ci/pipelines/merge_trains.html');

export default {
  mixins: [glFeatureFlagsMixin()],
  computed: {
    isMergeButtonDisabled() {
      const { commitMessage } = this;
      return Boolean(
        !commitMessage.length ||
        !this.shouldShowMergeControls ||
        this.isMakingRequest ||
        this.mr.preventMerge,
      );
    },
    pipelineMustSucceedConflictText() {
      return PIPELINE_MUST_SUCCEED_CONFLICT_TEXT;
    },
    autoMergeText() {
      return __('Set to auto-merge');
    },
    showReAddToMergeTrain() {
      const mergeTrainRefRegex = /^refs\/merge-requests\/.*\/train$/;
      return Boolean(
        this.preferredAutoMergeStrategy === MT_MERGE_STRATEGY &&
        this.pipeline?.ref?.match(mergeTrainRefRegex),
      );
    },
    autoMergeHelperText() {
      if (this.preferredAutoMergeStrategy === MTWCP_MERGE_STRATEGY) {
        return __('Add to merge train when all merge checks pass');
      }
      if (this.showReAddToMergeTrain) {
        return __('Re-add to merge train');
      }
      if (this.preferredAutoMergeStrategy === MT_MERGE_STRATEGY) {
        return __('Add to merge train');
      }

      return CEReadyToMergeMixin.computed.autoMergeHelperText.call(this);
    },
    autoMergePopoverSettings() {
      if (
        this.preferredAutoMergeStrategy === MT_MERGE_STRATEGY ||
        this.preferredAutoMergeStrategy === MTWCP_MERGE_STRATEGY
      ) {
        return {
          helpLink: MERGE_TRAINS_HELP,
          bodyText: __(
            'A %{linkStart}merge train%{linkEnd} is a queued list of merge requests, each waiting to be merged into the target branch.',
          ),
          title: __('Merge trains'),
        };
      }

      return CEReadyToMergeMixin.computed.autoMergePopoverSettings.call(this);
    },
    pipelineId() {
      return getIdFromGraphQLId(this.pipeline.id);
    },
    shouldRenderMergeTrainHelperIcon() {
      return (
        this.pipeline &&
        isNumber(getIdFromGraphQLId(this.pipeline.id)) &&
        isString(this.pipeline.path) &&
        this.preferredAutoMergeStrategy === MTWCP_MERGE_STRATEGY &&
        !this.state.autoMergeEnabled
      );
    },
    shouldShowMergeImmediatelyDropdown() {
      if (this.mr.mergeTrainEnforced) {
        return false;
      }

      if (!this.isAutoMergeAvailable || !this.mr.isMergeAllowed) {
        return false;
      }

      if (
        this.preferredAutoMergeStrategy === MT_MERGE_STRATEGY ||
        this.preferredAutoMergeStrategy === MTWCP_MERGE_STRATEGY
      ) {
        return !this.mr.ffOnlyEnabled || this.mr.ffMergePossible;
      }

      return true;
    },
    shouldDisplayMergeImmediatelyDropdownOptions() {
      return [MT_MERGE_STRATEGY, MTWCP_MERGE_STRATEGY].includes(this.preferredAutoMergeStrategy);
    },
    isMergeImmediatelyDangerous() {
      return [MT_MERGE_STRATEGY, MTWCP_MERGE_STRATEGY].includes(this.preferredAutoMergeStrategy);
    },
    showFailedPipelineModalMergeTrain() {
      const pipelineFailed = this.status === PIPELINE_FAILED_STATE || this.isPipelineFailed;
      const mergeStrateyMergeTrain = this.preferredAutoMergeStrategy === MT_MERGE_STRATEGY;

      return pipelineFailed && mergeStrateyMergeTrain;
    },
  },
  methods: {
    onStartMergeTrainConfirmation() {
      this.handleMergeButtonClick(this.isAutoMergeAvailable, false, true);
    },
  },
};
