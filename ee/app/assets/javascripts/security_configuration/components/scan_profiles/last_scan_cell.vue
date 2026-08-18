<script>
import { GlLink } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  SCAN_PROFILE_SCANNER_HEALTH_ACTIVE,
  SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  SCAN_PROFILE_SCANNER_HEALTH_STALE,
  SCAN_PROFILE_SCANNER_HEALTH_WARNING,
} from '~/security_configuration/constants';
import JobDetailsPopover from './job_details_popover.vue';

const LINK_VARIANT_VIEW_JOB = 'view-job';
const LINK_VARIANT_PIPELINE_JOB = 'pipeline-job';

export default {
  name: 'LastScanCell',
  components: {
    GlLink,
    JobDetailsPopover,
  },
  mixins: [timeagoMixin],
  props: {
    targetId: {
      type: String,
      required: true,
    },
    lastScanAt: {
      type: String,
      required: false,
      default: null,
    },
    buildId: {
      type: String,
      required: false,
      default: null,
    },
    status: {
      type: String,
      required: false,
      default: '',
    },
    projectFullPath: {
      type: String,
      required: true,
    },
    linkVariant: {
      type: String,
      required: false,
      default: LINK_VARIANT_VIEW_JOB,
      validator: (value) => [LINK_VARIANT_VIEW_JOB, LINK_VARIANT_PIPELINE_JOB].includes(value),
    },
  },
  emits: ['open-drawer'],
  data() {
    return {
      isPopoverOpen: false,
      popoverCloseTimeout: null,
    };
  },
  computed: {
    hasInteractiveDetails() {
      return Boolean(this.lastScanAt && this.buildId);
    },
    formattedLastScan() {
      return this.timeFormatted(this.lastScanAt);
    },
    isFailedOrWarningStatus() {
      return [SCAN_PROFILE_SCANNER_HEALTH_WARNING, SCAN_PROFILE_SCANNER_HEALTH_FAILED].includes(
        this.status,
      );
    },
    linkText() {
      const jobId = getIdFromGraphQLId(this.buildId);
      if (this.linkVariant === LINK_VARIANT_PIPELINE_JOB) {
        return sprintf(s__('SecurityProfiles|Pipeline job: #%{jobId}'), { jobId });
      }
      return this.isFailedOrWarningStatus
        ? sprintf(s__('SecurityProfiles|View failed job #%{jobId}'), { jobId })
        : sprintf(s__('SecurityProfiles|View job #%{jobId}'), { jobId });
    },
    popoverTitle() {
      const titles = {
        [SCAN_PROFILE_SCANNER_HEALTH_ACTIVE]: s__('SecurityProfiles|Scan successful'),
        [SCAN_PROFILE_SCANNER_HEALTH_WARNING]: s__('SecurityProfiles|Scan warning'),
        [SCAN_PROFILE_SCANNER_HEALTH_FAILED]: s__('SecurityProfiles|Scan failed'),
        [SCAN_PROFILE_SCANNER_HEALTH_STALE]: s__('SecurityProfiles|Scan outdated'),
      };
      return titles[this.status] || '';
    },
  },
  beforeDestroy() {
    clearTimeout(this.popoverCloseTimeout);
  },
  methods: {
    openPopover() {
      clearTimeout(this.popoverCloseTimeout);
      this.isPopoverOpen = true;
    },
    closePopover() {
      this.popoverCloseTimeout = setTimeout(this.handleBlur, 500);
    },
    handleBlur() {
      this.isPopoverOpen = false;
    },
    handleOpenDrawer(jobData) {
      clearTimeout(this.popoverCloseTimeout);
      this.handleBlur();
      this.$emit('open-drawer', jobData);
    },
  },
};
</script>

<template>
  <div v-if="hasInteractiveDetails" data-testid="last-scan" class="gl-flex gl-flex-col">
    <time :datetime="lastScanAt">{{ formattedLastScan }}</time>
    <gl-link
      :id="targetId"
      :data-testid="targetId"
      class="gl-mt-1"
      @mouseenter="openPopover"
      @mouseleave="closePopover"
      @focus="openPopover"
      @blur="handleBlur"
    >
      {{ linkText }}
    </gl-link>
    <job-details-popover
      :target="targetId"
      :title="popoverTitle"
      :show="isPopoverOpen"
      :build-id="buildId"
      :project-full-path="projectFullPath"
      :status="status"
      @mouseenter="openPopover"
      @mouseleave="closePopover"
      @open-drawer="handleOpenDrawer"
    />
  </div>
  <span v-else-if="lastScanAt"
    ><time :datetime="lastScanAt">{{ formattedLastScan }}</time></span
  >
  <span v-else class="gl-text-subtle">{{ __('—') }}</span>
</template>
