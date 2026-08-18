<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert, VARIANT_INFO, VARIANT_DANGER } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { PdfExportError } from 'ee/security_dashboard/helpers';

export default {
  name: 'PdfExportButton',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['vulnerabilitiesPdfExportEndpoint', 'dashboardType'],
  props: {
    getReportData: {
      type: Function,
      required: true,
    },
  },
  data() {
    return {
      isExporting: false,
    };
  },
  methods: {
    notifyUserReportWillBeEmailed() {
      createAlert({
        message: s__(
          'SecurityReports|Report export in progress. After the report is generated, an email will be sent with the download link.',
        ),
        variant: VARIANT_INFO,
        dismissible: true,
      });
    },
    notifyUserOfExportError(error) {
      const message =
        error instanceof PdfExportError ? error.message : error.response?.data?.message;

      createAlert({
        message: message || s__('SecurityReports|There was an error while generating the report.'),
        variant: VARIANT_DANGER,
        dismissible: true,
      });
    },
    async onClickExport() {
      this.isExporting = true;

      try {
        const reportData = this.getReportData();
        await axios.post(this.vulnerabilitiesPdfExportEndpoint, {
          report_data: { ...reportData, dashboard_type: this.dashboardType },
          export_format: 'pdf',
        });
        this.notifyUserReportWillBeEmailed();
      } catch (error) {
        this.notifyUserOfExportError(error);
      } finally {
        this.isExporting = false;
      }
    },
  },
};
</script>

<template>
  <gl-button
    v-gl-tooltip
    :title="s__('SecurityReports|Export as PDF')"
    category="secondary"
    class="gl-ml-2"
    :loading="isExporting"
    :icon="isExporting ? '' : 'export'"
    @click="onClickExport"
  >
    {{ s__('SecurityReports|Export') }}
  </gl-button>
</template>
