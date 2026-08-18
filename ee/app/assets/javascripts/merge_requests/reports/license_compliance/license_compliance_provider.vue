<script>
import { computed } from 'vue';
import { s__ } from '~/locale';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import axios from '~/lib/utils/axios_utils';
import { normalizeHeaders } from '~/lib/utils/common_utils';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import Poll from '~/lib/utils/poll';
import {
  transformLicense,
  groupLicensesByStatus,
  createLicenseSections,
} from 'ee/vue_merge_request_widget/widgets/license_compliance/utils';

export default normalizeRender({
  name: 'LicenseComplianceProvider',
  provide() {
    return {
      newLicensesCount: computed(() => this.newLicensesCount),
      isLicenseComplianceLoading: computed(() => Boolean(this.loadingMessage)),
      existingLicensesCount: computed(() => this.existingLicensesCount),
      hasDeniedLicense: computed(() => this.hasDeniedLicense),
      hasApprovalRequired: computed(() => this.hasApprovalRequired),
      statusIconName: computed(() => this.statusIconName),
      statusMessage: computed(() => this.statusMessage),
      errorMessage: computed(() => this.errorMessage),
      sections: computed(() => this.sections),
      loadingMessage: computed(() => this.loadingMessage),
    };
  },
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isFetching: true,
      statusMessage: '',
      errorMessage: '',
      responseData: null,
      activePolls: [],
    };
  },
  computed: {
    loadingMessage() {
      if (this.isFetching) {
        return s__('ciReport|License Compliance test metrics results are being parsed');
      }
      return '';
    },
    licenseComplianceEndpoint() {
      return this.mr.licenseCompliance?.license_scanning_comparison_path;
    },
    newLicensesCount() {
      return this.responseData?.new_licenses?.length || 0;
    },
    statusIconName() {
      if (this.errorMessage) {
        return EXTENSION_ICONS.error;
      }
      if (this.statusMessage || this.newLicensesCount > 0) {
        return EXTENSION_ICONS.warning;
      }
      return EXTENSION_ICONS.success;
    },
    existingLicensesCount() {
      return this.responseData?.existing_licenses?.length || 0;
    },
    hasDeniedLicense() {
      return this.responseData?.has_denied_licenses || false;
    },
    hasApprovalRequired() {
      return this.responseData?.approval_required || false;
    },
    fullReportPath() {
      return this.mr.licenseCompliance?.license_scanning?.full_report_path;
    },
    sections() {
      const licenses = this.responseData?.new_licenses;
      if (!licenses?.length) {
        return [];
      }
      const transformed = licenses.map((license) => transformLicense(license, this.fullReportPath));
      const grouped = groupLicensesByStatus(transformed);
      return createLicenseSections(grouped);
    },
  },
  mounted() {
    this.fetchData();
  },
  beforeDestroy() {
    this.stopAllPolls();
  },
  methods: {
    async fetchData() {
      this.stopAllPolls();
      this.isFetching = true;

      if (!this.licenseComplianceEndpoint) {
        this.statusMessage = s__('ciReport|No license compliance enabled.');
        this.isFetching = false;
        return;
      }

      try {
        const data = await this.fetchWithPolling(this.licenseComplianceEndpoint);
        if (data) {
          this.responseData = data;
        }
      } catch (error) {
        const statusReason = error.response?.data?.status_reason;
        if (statusReason) {
          this.statusMessage = statusReason;
        } else {
          this.errorMessage = s__('ciReport|License Compliance failed loading results');
        }
      }

      this.isFetching = false;
    },
    fetchWithPolling(endpoint) {
      return new Promise((resolve, reject) => {
        const poll = new Poll({
          resource: {
            fetchData: () => axios.get(endpoint),
          },
          method: 'fetchData',
          successCallback: (response) => {
            const headers = normalizeHeaders(response.headers);

            if (headers['POLL-INTERVAL']) {
              return;
            }

            poll.stop();
            resolve(response.data);
          },
          errorCallback: (error) => {
            reject(error);
          },
        });

        poll.makeRequest();
        this.activePolls.push(poll);
      });
    },
    stopAllPolls() {
      this.activePolls.forEach((poll) => poll.stop());
      this.activePolls = [];
    },
  },
  render() {
    return getSlotFunction(this)?.();
  },
});
</script>
