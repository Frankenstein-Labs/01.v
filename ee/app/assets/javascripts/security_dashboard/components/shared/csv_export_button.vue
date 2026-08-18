<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { createAlert, VARIANT_DANGER } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import { s__ } from '~/locale';
import { filters } from './vulnerability_report/store';

export default {
  name: 'CsvExportButton',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['vulnerabilitiesExportEndpoint'],
  data() {
    return {
      isPreparingCsvExport: false,
    };
  },
  computed: {
    filterParameters() {
      return convertObjectPropsToSnakeCase(filters.value);
    },
  },
  methods: {
    async initiateCsvExport() {
      this.isPreparingCsvExport = true;

      try {
        await axios.post(this.vulnerabilitiesExportEndpoint, {
          send_email: true,
          filters: this.filterParameters,
        });
        this.notifyUserReportWillBeEmailed();
      } catch (error) {
        this.notifyUserOfExportError(error);
      } finally {
        this.isPreparingCsvExport = false;
      }
    },

    notifyUserReportWillBeEmailed() {
      createAlert({
        message: s__(
          'SecurityReports|Report export in progress. After the report is generated, an email will be sent with the download link.',
        ),
        variant: 'info',
        dismissible: true,
      });
    },

    notifyUserOfExportError(error) {
      const message = error.response?.data?.message;

      createAlert({
        message: message || s__('SecurityReports|There was an error while generating the report.'),
        variant: VARIANT_DANGER,
        dismissible: true,
      });
    },
  },
};
</script>
<template>
  <gl-button
    v-gl-tooltip.hover
    :title="s__('SecurityReports|Send as CSV to email')"
    :loading="isPreparingCsvExport"
    :icon="isPreparingCsvExport ? '' : 'export'"
    :disabled="!vulnerabilitiesExportEndpoint"
    @click="initiateCsvExport"
  >
    {{ s__('SecurityReports|Export') }}
  </gl-button>
</template>
