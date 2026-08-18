<script>
import { GlButton, GlSprintf, GlModalDirective } from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { getFormattedSummary } from 'ee/security_dashboard/helpers';
import Modal from 'ee/vue_shared/security_reports/components/dast_modal.vue';
import { convertToSnakeCase } from '~/lib/utils/text_utility';
import { s__, n__ } from '~/locale';
import SecurityReportDownloadDropdown from '~/vue_shared/security_reports/components/security_report_download_dropdown.vue';
import { extractSecurityReportArtifacts } from '~/vue_shared/security_reports/utils';
import {
  SECURITY_REPORT_TYPE_ENUM_DAST,
  REPORT_TYPE_DAST,
} from 'ee/vue_shared/security_reports/constants';

export default {
  name: 'SecurityReportsSummary',
  components: {
    GlButton,
    CrudComponent,
    GlSprintf,
    Modal,
    SecurityReportDownloadDropdown,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  props: {
    summary: {
      type: Object,
      required: true,
    },
    jobs: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  i18n: {
    scannedResources: s__('SecurityReports|scanned resources'),
    scanDetails: s__('SecurityReports|Scan details'),
    downloadUrls: s__('SecurityReports|Download scanned URLs'),
    downloadResults: s__('SecurityReports|Download results'),
    vulnerabilities: (count) => n__('%d vulnerability', '%d vulnerabilities', count),
    scannedUrls: (count) => n__('%d URL scanned', '%d URLs scanned', count),
  },
  computed: {
    formattedSummary() {
      return getFormattedSummary(this.summary);
    },
  },
  methods: {
    hasScannedResources(scanSummary) {
      return scanSummary.scannedResources?.nodes?.length > 0;
    },
    hasDastArtifacts() {
      return this.findArtifacts(SECURITY_REPORT_TYPE_ENUM_DAST).length > 0;
    },
    hasDastArtifactDownload(scanType, scanSummary) {
      return (
        scanType === SECURITY_REPORT_TYPE_ENUM_DAST &&
        (Boolean(this.downloadLink(scanSummary)) || this.hasDastArtifacts)
      );
    },
    downloadLink(scanSummary) {
      return scanSummary.scannedResourcesCsvPath || '';
    },
    normalizeScanType(scanType) {
      return convertToSnakeCase(scanType.toLowerCase());
    },
    findArtifacts(scanType) {
      return extractSecurityReportArtifacts([this.normalizeScanType(scanType)], this.jobs);
    },
    buildDastArtifacts(scanSummary) {
      const csvArtifact = {
        name: this.$options.i18n.scannedResources,
        path: this.downloadLink(scanSummary),
        reportType: REPORT_TYPE_DAST,
      };

      return [...this.findArtifacts(SECURITY_REPORT_TYPE_ENUM_DAST), csvArtifact];
    },
  },
  anchorId: 'hide_pipelines_security_reports_summary_details',
};
</script>

<template>
  <crud-component
    is-collapsible
    :title="$options.i18n.scanDetails"
    :count="formattedSummary.length"
    icon="documents"
    body-class="gl-py-0"
    persist-collapsed-state
    :anchor-id="$options.anchorId"
  >
    <div class="scan-reports-summary-grid gl-my-3 gl-grid gl-items-center gl-gap-y-2">
      <template v-for="[scanType, scanSummary] in formattedSummary">
        <div :key="scanType" class="gl-leading-24">
          {{ scanType }}
        </div>
        <div :key="`${scanType}-count`" class="gl-leading-24">
          <gl-sprintf :message="$options.i18n.vulnerabilities(scanSummary.vulnerabilitiesCount)" />
        </div>
        <div
          :key="`${scanType}-download`"
          class="gl-text-right"
          :data-testid="`artifact-download-${normalizeScanType(scanType)}`"
        >
          <template v-if="scanSummary.scannedResourcesCount !== undefined">
            <gl-button
              v-if="hasScannedResources(scanSummary)"
              v-gl-modal.dastUrl
              icon="download"
              size="small"
              data-testid="modal-button"
            >
              {{ $options.i18n.downloadUrls }}
            </gl-button>

            <template v-else>
              (<gl-sprintf
                :message="$options.i18n.scannedUrls(scanSummary.scannedResourcesCount)"
              />)
            </template>

            <modal
              v-if="hasScannedResources(scanSummary)"
              :scanned-urls="scanSummary.scannedResources.nodes"
              :scanned-resources-count="scanSummary.scannedResourcesCount"
              :download-link="downloadLink(scanSummary)"
            />
          </template>

          <template v-else-if="hasDastArtifactDownload(scanType, scanSummary)">
            <security-report-download-dropdown
              :text="$options.i18n.downloadResults"
              :artifacts="buildDastArtifacts(scanSummary)"
              data-testid="download-link"
            />
          </template>

          <security-report-download-dropdown
            v-else
            :text="$options.i18n.downloadResults"
            :artifacts="findArtifacts(scanType)"
          />
        </div>
      </template>
    </div>
  </crud-component>
</template>
