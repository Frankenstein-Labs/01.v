<script>
import { GlLink } from '@gitlab/ui';
import { humanizeTimeInterval } from '~/lib/utils/datetime/date_format_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { SCAN_PROFILE_SOURCE_LABELS } from '~/security_configuration/constants';
import ScannerStatusIcon from './scanner_status_icon.vue';

export default {
  name: 'TroubleshootJobData',
  components: {
    GlLink,
    ScannerStatusIcon,
  },
  mixins: [timeagoMixin],
  props: {
    name: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      required: true,
    },
    duration: {
      type: Number,
      required: false,
      default: null,
    },
    source: {
      type: String,
      required: false,
      default: null,
    },
    finishedAt: {
      type: String,
      required: false,
      default: null,
    },
    webPath: {
      type: String,
      required: false,
      default: null,
    },
    pipeline: {
      type: Object,
      required: true,
    },
    isDrawer: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    formattedDuration() {
      if (this.duration == null) return '';
      return humanizeTimeInterval(this.duration);
    },
    jobId() {
      const parts = (this.webPath || '').split('/');
      return parts.pop();
    },
    finishedTime() {
      return this.timeFormatted(this.finishedAt);
    },
    formattedSource() {
      return SCAN_PROFILE_SOURCE_LABELS[this.source] || this.source;
    },
    pipelineId() {
      return getIdFromGraphQLId(this.pipeline?.id);
    },
  },
};
</script>

<template>
  <div class="gl-mt-0 !gl-pb-0">
    <div class="gl-my-2" :class="{ 'gl-my-3': isDrawer }">
      <span class="gl-font-bold">{{ __('Name') }}:</span>
      <span>{{ name }}</span>
    </div>
    <div class="gl-my-2 gl-flex" :class="{ 'gl-my-3': isDrawer }">
      <span class="gl-font-bold">{{ __('Status') }}:</span>
      <scanner-status-icon
        data-testid="status-icon"
        class="gl-self-start gl-pl-2"
        :status="status"
      />
    </div>
    <div class="gl-my-2" :class="{ 'gl-my-3': isDrawer }">
      <span class="gl-font-bold">{{ __('Duration') }}:</span>
      <span>{{ formattedDuration }}</span>
    </div>
    <div v-if="source" class="gl-my-2" :class="{ 'gl-my-3': isDrawer }">
      <span class="gl-font-bold">{{ __('Source') }}:</span>
      <span>{{ formattedSource }}</span>
    </div>
    <div v-if="isDrawer" class="gl-my-3">
      <span class="gl-font-bold">{{ __('Finished') }}:</span>
      <time :datetime="finishedAt">{{ finishedTime }}</time>
    </div>
    <div v-if="pipeline" class="gl-my-2" :class="{ 'gl-my-3': isDrawer }">
      <span class="gl-font-bold">{{ __('Pipeline') }}:</span>
      <gl-link :href="pipeline?.path" data-testid="pipeline-path">#{{ pipelineId }}</gl-link>
    </div>
    <div v-if="isDrawer" class="gl-my-3">
      <span class="gl-font-bold">{{ __('Job') }}:</span>
      <gl-link :href="webPath" data-testid="job-path"> #{{ jobId }}</gl-link>
    </div>
  </div>
</template>
