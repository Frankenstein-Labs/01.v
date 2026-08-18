<script>
import { GlButton, GlIcon, GlLink } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import {
  PROJECT_PIPELINE_JOB_PATH,
  PROJECT_SECURITY_CONFIGURATION_PATH,
  SCANNER_POPOVER_LABELS,
  TOOL_STATUS_CONFIG,
  TOOL_NOT_ENABLED,
} from 'ee/security_inventory/constants';
import { securityScannerOfProjectValidator } from 'ee/security_inventory/utils';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export default {
  name: 'ProjectToolCoverageDetails',
  components: {
    GlButton,
    GlIcon,
    GlLink,
  },
  mixins: [timeagoMixin],
  props: {
    securityScanner: {
      type: Array,
      required: false,
      default: () => [],
      validator: (value) => securityScannerOfProjectValidator(value),
    },
    webUrl: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    scannerItems() {
      return this.securityScanner.map((scanner) => ({
        title: SCANNER_POPOVER_LABELS[scanner.analyzerType] || __('Status'),
        ...scanner,
      }));
    },
    manageConfigurationPath() {
      return this.webUrl ? `${this.webUrl}${PROJECT_SECURITY_CONFIGURATION_PATH}` : '#';
    },
  },
  methods: {
    getStatusConfig(status) {
      return TOOL_STATUS_CONFIG[status] ?? TOOL_STATUS_CONFIG[TOOL_NOT_ENABLED];
    },
    getBuildId(buildIdPath) {
      return getIdFromGraphQLId(buildIdPath);
    },
    pipelineJobPath(currentBuildIdPath) {
      if (!currentBuildIdPath) return '#';
      const buildId = this.getBuildId(currentBuildIdPath);
      return this.webUrl ? `${this.webUrl}${PROJECT_PIPELINE_JOB_PATH}/${buildId}` : '#';
    },
    getLastScan(lastCall) {
      return this.timeFormatted(lastCall);
    },
  },
  i18n: {
    vulnerabilityReportButton: s__('ProjectToolCoverageDetails|Manage configuration'),
  },
};
</script>

<template>
  <div>
    <div class="gl-m-2">
      <div
        v-for="(item, index) in scannerItems"
        :key="index"
        class="gl-my-2"
        :class="{ 'gl-mt-4': index > 0 }"
      >
        <span class="gl-font-bold" :data-testid="`scanner-title-${index}`">{{ item.title }}:</span>
        <gl-icon
          :name="getStatusConfig(item.status).name"
          :variant="getStatusConfig(item.status).variant"
          :size="12"
        />
        <span :data-testid="`scanner-status-${index}`">
          {{ getStatusConfig(item.status).text }}
        </span>

        <div class="gl-my-2" :data-testid="`last-scan-${index}`">
          <span class="gl-font-bold">{{ __('Last scan') }}:</span>
          <time v-if="item.lastCall" :datetime="item.lastCall">{{
            getLastScan(item.lastCall)
          }}</time>
          <gl-icon v-else name="dash" variant="default" :size="12" />
        </div>

        <div class="gl-my-2" :data-testid="`pipeline-job-${index}`">
          <span class="gl-font-bold" :data-testid="`pipeline-job-title-${index}`"
            >{{ __('Pipeline job') }}:</span
          >
          <gl-link v-if="item.buildId" :href="pipelineJobPath(item.buildId)"
            >#{{ getBuildId(item.buildId) }}</gl-link
          >
          <gl-icon v-else name="dash" variant="default" :size="12" />
        </div>
      </div>
    </div>

    <gl-button
      category="secondary"
      variant="confirm"
      class="gl-my-3 gl-w-full"
      size="small"
      :href="manageConfigurationPath"
      >{{ $options.i18n.vulnerabilityReportButton }}</gl-button
    >

    <div
      v-if="scannerItems.length > 0 && scannerItems[0].updatedAt"
      class="gl-my-2"
      data-testid="date-updated"
    >
      {{ __('Data updated') }}
      <time :datetime="scannerItems[0].updatedAt">{{
        timeFormatted(scannerItems[0].updatedAt)
      }}</time>
    </div>
  </div>
</template>
