<script>
import { isNumber } from 'lodash-es';
import { GlLink, GlToastMixin } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { STATUS_OPEN } from '~/issues/constants';

export default {
  name: 'MergeTrainPositionIndicator',
  components: {
    GlLink,
  },
  mixins: [GlToastMixin],
  props: {
    mergeRequestState: {
      type: String,
      required: false,
      default: null,
    },
    mergeTrainsCount: {
      type: Number,
      required: false,
      default: null,
    },
    mergeTrainsPath: {
      type: String,
      required: false,
      default: null,
    },
    mergeTrainCar: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    isMergeRequestOpen() {
      return this.mergeRequestState === STATUS_OPEN;
    },
    mergeTrainIndex() {
      return this.mergeTrainCar?.index;
    },
    message() {
      if (this.mergeTrainIndex === 0) {
        return s__(
          'mrWidget|A new merge train has started and this merge request is first in the queue.',
        );
      }

      if (isNumber(this.mergeTrainIndex) && isNumber(this.mergeTrainsCount)) {
        return sprintf(
          s__('mrWidget|This merge request is #%{mergeTrainPosition} of %{total} in queue.'),
          {
            mergeTrainPosition: this.mergeTrainIndex + 1,
            total: this.mergeTrainsCount,
          },
        );
      }

      return null;
    },
  },
  watch: {
    mergeTrainCar(currentCar, oldCar) {
      if (!this.isMergeRequestOpen) {
        return;
      }

      // if an old merge train car existed and the current
      // merge train car is null then the MR was removed
      // from the merge train.
      if (oldCar && !currentCar) {
        this.$toast?.show(s__('mrWidget|This merge request was removed from the merge train.'));
      }
    },
  },
};
</script>

<template>
  <div v-if="message" class="plr-3 merge-train-position-indicator !gl-pb-3 !gl-pl-5 !gl-pt-3">
    <div class="media-body gl-text-subtle">
      {{ message }}
      <gl-link v-if="mergeTrainsPath" :href="mergeTrainsPath">
        {{ s__('mrWidget|View merge train.') }}
      </gl-link>
    </div>
  </div>
</template>
