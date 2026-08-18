<script>
// eslint-disable-next-line no-restricted-imports
import { mapState, mapGetters, mapActions } from 'vuex';
import { GlLink, GlButton } from '@gitlab/ui';
import api from '~/api';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import { componentNames, iconComponentNames } from 'ee/ci/reports/components/issue_body';
import { LICENSE_MANAGEMENT } from 'ee/vue_shared/license_compliance/store/constants';
import reportsMixin from 'ee/vue_shared/security_reports/mixins/reports_mixin';
import SbomReportsErrorsAlert from 'ee/dependencies/components/sbom_reports_errors_alert.vue';
import ReportItem from '~/ci/reports/components/report_item.vue';
import ReportSection from '~/ci/reports/components/report_section.vue';
import SmartVirtualList from '~/vue_shared/components/smart_virtual_list.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { setupStore } from './store';

export default {
  name: 'MrWidgetLicenses',
  componentNames,
  iconComponentNames,
  components: {
    GlButton,
    GlLink,
    ReportItem,
    ReportSection,
    SmartVirtualList,
    HelpIcon,
    SbomReportsErrorsAlert,
  },
  mixins: [reportsMixin, InternalEvents.mixin()],
  props: {
    fullReportPath: {
      type: String,
      required: false,
      default: null,
    },
    apiUrl: {
      type: String,
      required: true,
    },
    licensesApiPath: {
      type: String,
      required: false,
      default: '',
    },
    approvalsApiPath: {
      type: String,
      required: false,
      default: '',
    },
    canManageLicenses: {
      type: Boolean,
      required: true,
    },
    reportSectionClass: {
      type: String,
      required: false,
      default: '',
    },
    alwaysOpen: {
      type: Boolean,
      required: false,
      default: false,
    },
    licenseComplianceDocsPath: {
      type: String,
      required: false,
      default: '',
    },
    securityPoliciesPath: {
      type: String,
      required: false,
      default: '',
    },
    sbomReportsErrors: {
      type: Array,
      required: true,
    },
  },
  emits: ['update-badge-count'],
  maxShownReportItems: 20,
  computed: {
    ...mapState(LICENSE_MANAGEMENT, ['loadLicenseReportError']),
    ...mapGetters(LICENSE_MANAGEMENT, [
      'licenseReport',
      'isLoading',
      'licenseSummaryText',
      'reportContainsDeniedLicense',
      'licenseReportGroups',
    ]),
    hasLicenseReportIssues() {
      const { licenseReport } = this;
      return licenseReport && licenseReport.length > 0;
    },
    licenseReportStatus() {
      return this.checkReportStatus(this.isLoading, this.loadLicenseReportError);
    },
    showActionButtons() {
      return this.securityPoliciesPath !== null || this.fullReportPath !== null;
    },
    showSbomErrors() {
      return this.sbomReportsErrors.length > 0;
    },
  },
  i18n: {
    sbomReportsErrorsDescription: s__(
      'LicenseScanningReport|The following SBOM reports could not be parsed. Therefore the list of components and their licenses may be incomplete.',
    ),
  },
  watch: {
    licenseReport() {
      this.$emit('update-badge-count', this.licenseReport.length);
    },
  },
  beforeCreate() {
    setupStore(this.$store);
  },
  mounted() {
    const { apiUrl, canManageLicenses, licensesApiPath, approvalsApiPath } = this;

    this.setAPISettings({
      apiUrlManageLicenses: apiUrl,
      canManageLicenses,
      licensesApiPath,
      approvalsApiPath,
    });

    this.fetchParsedLicenseReport();
  },
  methods: {
    trackFullReportClick() {
      api.trackRedisHllUserEvent('users_visiting_testing_license_compliance_full_report');
      this.trackEvent('click_full_report_license_compliance');
    },
    ...mapActions(LICENSE_MANAGEMENT, ['setAPISettings', 'fetchParsedLicenseReport']),
  },
};
</script>
<template>
  <div>
    <sbom-reports-errors-alert
      v-if="showSbomErrors"
      :errors="sbomReportsErrors"
      :error-description="$options.i18n.sbomReportsErrorsDescription"
      class="gl-mt-5"
    />

    <report-section
      :status="licenseReportStatus"
      :loading-text="licenseSummaryText"
      :error-text="licenseSummaryText"
      :neutral-issues="licenseReport"
      :has-issues="hasLicenseReportIssues"
      :component="$options.componentNames.LicenseIssueBody"
      :class="reportSectionClass"
      track-action="users_expanding_testing_license_compliance_report"
      :always-open="alwaysOpen"
      class="license-report-widget mr-report"
    >
      <template #body>
        <smart-virtual-list
          ref="reportSectionBody"
          :length="licenseReport.length"
          :remain="$options.maxShownReportItems"
          class="report-block-container"
          wtag="ul"
          wclass="report-block-list !gl-my-2"
        >
          <template v-for="(licenseReportGroup, index) in licenseReportGroups">
            <li
              :key="licenseReportGroup.name"
              :class="['!gl-mx-2', '!gl-mb-2', index > 0 ? '!gl-mt-5' : '']"
              data-testid="report-heading"
            >
              <h2 class="h5 !gl-m-0">{{ licenseReportGroup.name }}</h2>
              <p class="!gl-m-0">{{ licenseReportGroup.description }}</p>
            </li>
            <report-item
              v-for="license in licenseReportGroup.licenses"
              :key="license.name"
              :issue="license"
              :status-icon-size="12"
              :status="license.status"
              :component="$options.componentNames.LicenseIssueBody"
              :icon-component="$options.iconComponentNames.LicenseStatusIcon"
              :show-report-section-status-icon="true"
              class="gl-m-2"
            />
          </template>
        </smart-virtual-list>
      </template>
      <template #success>
        <div class="!gl-pr-5">
          {{ licenseSummaryText }}
          <gl-link
            v-if="reportContainsDeniedLicense && licenseComplianceDocsPath"
            :href="licenseComplianceDocsPath"
            data-testid="security-approval-help-link"
            target="_blank"
          >
            <help-icon />
          </gl-link>
        </div>
      </template>
      <template v-if="showActionButtons" #action-buttons="{ isCollapsible }">
        <gl-button
          v-if="fullReportPath"
          :href="fullReportPath"
          class="gl-mr-3"
          icon="external-link"
          target="_blank"
          data-testid="full-report-button"
          @click="trackFullReportClick"
        >
          {{ s__('ciReport|View full report') }}
        </gl-button>
        <gl-button
          v-if="securityPoliciesPath"
          data-testid="manage-licenses-button"
          :class="{ 'gl-mr-3': isCollapsible }"
          :href="securityPoliciesPath"
        >
          {{ s__('ciReport|Manage licenses') }}
        </gl-button>
      </template>
    </report-section>
  </div>
</template>
