<script>
import { isEmpty } from 'lodash-es';
import { s__ } from '~/locale';
import { joinPaths } from '~/lib/utils/url_utility';
import {
  LICENSE_COMPLIANCE_ROUTE,
  CLICK_VIEW_REPORT_ON_MERGE_REQUEST_WIDGET,
  TRACKING_LABEL_BY_ROUTE,
} from '~/merge_requests/reports/constants';
import { InternalEvents } from '~/tracking';
import axios from '~/lib/utils/axios_utils';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import MrWidget from '~/vue_merge_request_widget/components/widget/widget.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import {
  getSummaryTextWithReportItems,
  groupLicensesByStatus,
  createLicenseSections,
  transformLicense,
} from './utils';

export default {
  name: 'WidgetLicenseCompliance',
  i18n: {
    loading: s__('ciReport|License Compliance test metrics results are being parsed'),
    error: s__('ciReport|License Compliance failed loading results'),
  },
  components: {
    MrWidget,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  emits: ['loaded'],
  data() {
    return {
      licenseComplianceData: {
        collapsed: null,
        expanded: null,
      },
    };
  },
  computed: {
    newLicenses() {
      return this.licenseComplianceData.collapsed?.new_licenses || 0;
    },
    existingLicenses() {
      return this.licenseComplianceData.collapsed?.existing_licenses || 0;
    },
    licenseReportCount() {
      return this.newLicenses;
    },
    hasReportItems() {
      return this.licenseReportCount > 0;
    },
    hasBaseReportLicenses() {
      return this.existingLicenses > 0;
    },
    hasDeniedLicense() {
      return this.licenseComplianceData.collapsed?.has_denied_licenses;
    },
    actionButtons() {
      return [
        {
          text: s__('MrReports|View report'),
          href: joinPaths(this.mr.reportsTabPath, LICENSE_COMPLIANCE_ROUTE),
          onClick: (action, e) => {
            e.preventDefault();
            this.trackEvent(CLICK_VIEW_REPORT_ON_MERGE_REQUEST_WIDGET, {
              label: TRACKING_LABEL_BY_ROUTE[LICENSE_COMPLIANCE_ROUTE],
            });
            window.history.pushState(null, null, action.href);
            window.dispatchEvent(new PopStateEvent('popstate'));
          },
        },
      ];
    },
    hasApprovalRequired() {
      return Boolean(this.licenseComplianceData.collapsed?.approval_required);
    },
    summaryText() {
      if (this.hasReportItems) {
        return getSummaryTextWithReportItems({
          hasBaseReportLicenses: this.hasBaseReportLicenses,
          hasDeniedLicense: this.hasDeniedLicense,
          hasApprovalRequired: this.hasApprovalRequired,
          licenseReportCount: this.licenseReportCount,
        });
      }

      if (this.hasBaseReportLicenses) {
        return s__('LicenseCompliance|License compliance detected no new licenses');
      }
      return s__(
        'LicenseCompliance|License compliance detected no licenses for the source branch only',
      );
    },
    summary() {
      return {
        title: this.summaryText,
      };
    },
    statusIcon() {
      if (this.newLicenses === 0) {
        return EXTENSION_ICONS.success;
      }
      return EXTENSION_ICONS.warning;
    },
    licenseComplianceCollapsedPath() {
      return this.mr.licenseCompliance?.license_scanning_comparison_collapsed_path;
    },
    licenseComplianceExpandedPath() {
      return this.mr.licenseCompliance?.license_scanning_comparison_path;
    },
  },
  methods: {
    fetchCollapsedData() {
      return axios.get(this.licenseComplianceCollapsedPath).then((res) => {
        this.licenseComplianceData.collapsed = res.data;

        this.$emit('loaded', this.newLicenses);

        return {
          ...res,
          data: res.data,
        };
      });
    },
    fetchExpandedData() {
      return axios(this.licenseComplianceExpandedPath).then((res) => {
        const { data = {} } = res;

        if (isEmpty(data)) {
          return { ...res, data };
        }

        const fullReportPath = this.mr.licenseCompliance?.license_scanning?.full_report_path;
        const transformedLicenses = data.new_licenses.map((license) =>
          transformLicense(license, fullReportPath),
        );
        const groupedLicenses = groupLicensesByStatus(transformedLicenses);
        const licenseSections = createLicenseSections(groupedLicenses);

        this.licenseComplianceData.expanded = licenseSections;

        return { ...res, data: licenseSections };
      });
    },
  },
  widgetHelpPopover: {
    options: { title: s__('ciReport|License scan results') },
    content: {
      text: s__('ciReport|Detects known vulnerabilities in your software dependencies.'),
      learnMorePath: helpPagePath('user/compliance/license_approval_policies', {
        anchor:
          'criteria-to-compare-licenses-detected-in-the-merge-request-branch-to-licenses-in-the-default-branch',
      }),
    },
  },
};
</script>

<template>
  <mr-widget
    :action-buttons="actionButtons"
    :error-text="$options.i18n.error"
    :loading-text="$options.i18n.loading"
    :fetch-collapsed-data="fetchCollapsedData"
    :fetch-expanded-data="fetchExpandedData"
    :status-icon-name="statusIcon"
    :widget-name="$options.name"
    :summary="summary"
    :is-collapsible="false"
    :expand-button-label="s__('LicenseCompliance|Expand license compliance details')"
    :collapse-button-label="s__('LicenseCompliance|Collapse license compliance details')"
    :content="licenseComplianceData.expanded"
    :help-popover="$options.widgetHelpPopover"
  />
</template>
