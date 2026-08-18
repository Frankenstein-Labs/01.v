<script>
import projectVulnerabilitiesPerSeverityCount from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_per_severity.query.graphql';
import groupVulnerabilitiesPerSeverityCount from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_per_severity.query.graphql';
import organizationVulnerabilitiesPerSeverityCount from 'ee/security_dashboard/graphql/queries/organization_vulnerabilities_per_severity.query.graphql';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';
import { getSeverityColors } from 'ee/security_dashboard/utils/chart_utils';
import VulnerabilitiesForSeverityPanel from './charts/vulnerabilities_for_severity_panel.vue';

const NAMESPACE_CONFIG = {
  project: {
    query: projectVulnerabilitiesPerSeverityCount,
    pageLevelFilters: ['reportType', 'trackedRefIds'],
  },
  group: {
    query: groupVulnerabilitiesPerSeverityCount,
    pageLevelFilters: ['reportType', 'projectId', 'securityAttributesFilters'],
  },
  organization: {
    query: organizationVulnerabilitiesPerSeverityCount,
    pageLevelFilters: ['reportType', 'projectId'],
  },
};

export default {
  name: 'VulnerabilitiesForSeverityWrapper',
  components: {
    VulnerabilitiesForSeverityPanel,
  },
  inject: { fullPath: { default: null } },
  props: {
    namespace: {
      type: String,
      required: true,
      validator: (value) => Object.keys(NAMESPACE_CONFIG).includes(value),
    },
    severity: {
      type: String,
      required: true,
    },
    filters: {
      type: Object,
      required: true,
    },
  },
  apollo: {
    vulnerabilitySeverity: {
      query() {
        return this.config.query;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          ...this.queryVariables,
        };
      },
      update(data) {
        return data.namespace?.securityMetrics?.vulnerabilitiesPerSeverity?.[this.severity] || {};
      },
      error() {
        this.hasFetchError = true;
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.hasFetchError = false;
        }
      },
    },
  },
  data() {
    return {
      hasFetchError: false,
      vulnerabilitySeverity: {},
    };
  },
  computed: {
    config() {
      return NAMESPACE_CONFIG[this.namespace];
    },
    queryVariables() {
      return this.config.pageLevelFilters.reduce((acc, key) => {
        if (this.filters[key] !== undefined) {
          acc[key] = this.filters[key];
        }
        return acc;
      }, {});
    },
    loading() {
      return this.$apollo.queries.vulnerabilitySeverity.loading;
    },
  },
  mounted() {
    this.chartExportStore = useChartExportStore();
    this.chartExportStore.registerNested(
      'vulnerabilities_by_severity_count',
      this.severity,
      this.getSeverityExportData,
    );
  },
  destroyed() {
    this.chartExportStore?.unregisterNested('vulnerabilities_by_severity_count', this.severity);
  },
  methods: {
    getSeverityExportData() {
      const colors = getSeverityColors();
      return {
        count: this.vulnerabilitySeverity.count,
        medianAge: this.vulnerabilitySeverity.medianAge,
        color: colors[this.severity],
      };
    },
  },
};
</script>

<template>
  <vulnerabilities-for-severity-panel
    :severity="severity"
    :count="vulnerabilitySeverity.count"
    :median-age="vulnerabilitySeverity.medianAge"
    :filters="filters"
    :loading="loading"
    :error="hasFetchError"
  />
</template>
