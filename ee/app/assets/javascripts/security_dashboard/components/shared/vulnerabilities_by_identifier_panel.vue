<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { s__ } from '~/locale';
import { readFromUrl, writeToUrl } from 'ee/security_dashboard/utils/panel_state_url_sync';
import groupVulnerabilitiesByIdentifier from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_by_identifier.query.graphql';
import projectVulnerabilitiesByIdentifier from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_by_identifier.query.graphql';
import organizationVulnerabilitiesByIdentifier from 'ee/security_dashboard/graphql/queries/organization_vulnerabilities_by_identifier.query.graphql';
import PanelSeverityFilter from './panel_severity_filter.vue';
import VulnerabilitiesByIdentifierChart from './charts/vulnerabilities_by_identifier_chart.vue';

const PANEL_ID = 'vulnerabilitiesByIdentifier';

const NAMESPACE_CONFIG = {
  project: {
    query: projectVulnerabilitiesByIdentifier,
    pageLevelFilters: ['reportType', 'trackedRefIds'],
  },
  group: {
    query: groupVulnerabilitiesByIdentifier,
    pageLevelFilters: ['reportType', 'projectId', 'securityAttributesFilters'],
  },
  organization: {
    query: organizationVulnerabilitiesByIdentifier,
    pageLevelFilters: ['reportType', 'projectId'],
  },
};

export default {
  name: 'VulnerabilitiesByIdentifierPanel',
  components: {
    ExtendedDashboardPanel,
    PanelSeverityFilter,
    VulnerabilitiesByIdentifierChart,
  },
  inject: { fullPath: { default: null } },
  props: {
    namespace: {
      type: String,
      required: true,
      validator: (value) => Object.keys(NAMESPACE_CONFIG).includes(value),
    },
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      hasFetchError: false,
      vulnerabilitiesByIdentifier: [],
      severity: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'severity',
        defaultValue: [],
      }),
    };
  },
  apollo: {
    vulnerabilitiesByIdentifier: {
      query() {
        return this.config.query;
      },
      variables() {
        const baseVariables = {
          fullPath: this.fullPath,
          severity: this.severity,
        };

        this.config.pageLevelFilters
          .filter((filterKey) => this.filters[filterKey] !== undefined)
          .forEach((filterKey) => {
            baseVariables[filterKey] = this.filters[filterKey];
          });

        return baseVariables;
      },
      update(data) {
        return data?.namespace?.securityMetrics?.vulnerabilitiesByIdentifier || [];
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
  computed: {
    config() {
      return NAMESPACE_CONFIG[this.namespace];
    },
    hasChartData() {
      return this.vulnerabilitiesByIdentifier.length > 0;
    },
  },
  watch: {
    severity(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'severity',
        value,
        defaultValue: [],
      });
    },
  },
  tooltip: {
    description: s__(
      'SecurityReports|Open vulnerabilities by their top ten most common CWE identifiers.',
    ),
  },
};
</script>

<template>
  <extended-dashboard-panel
    :title="s__('SecurityReports|Top 10 CWEs')"
    :loading="$apollo.queries.vulnerabilitiesByIdentifier.loading"
    :show-alert-state="hasFetchError"
    :tooltip="$options.tooltip"
  >
    <template #filters>
      <panel-severity-filter v-model="severity" />
    </template>
    <template #body>
      <vulnerabilities-by-identifier-chart
        v-if="!hasFetchError && hasChartData"
        :vulnerabilities-by-identifier="vulnerabilitiesByIdentifier"
        :filters="filters"
        class="gl-isolate"
      />
      <p
        v-else
        class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0 gl-text-center"
        data-testid="vulnerabilities-by-identifier-empty-state"
      >
        <template v-if="hasFetchError">{{
          __('Something went wrong. Please try again.')
        }}</template>
        <template v-else>{{ __('No results found') }}</template>
      </p>
    </template>
  </extended-dashboard-panel>
</template>
