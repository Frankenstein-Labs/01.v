<script>
import { markRaw } from 'vue';
import { GlDashboardLayout } from '@gitlab/ui';
import { s__ } from '~/locale';
import { setUrlParams, updateHistory } from '~/lib/utils/url_utility';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { generateVulnerabilitiesForSeverityPanels } from 'ee/security_dashboard/utils/chart_generators';
import {
  REPORT_TYPES_WITH_MANUALLY_ADDED,
  REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  REPORT_TYPES_WITH_CLUSTER_IMAGE,
} from 'ee/security_dashboard/constants';
import FilteredSearch from './filtered_search/filtered_search.vue';
import ProjectToken from './filtered_search/tokens/project_token.vue';
import ReportTypeToken from './filtered_search/tokens/report_type_token.vue';
import VulnerabilitiesOverTimePanel from './vulnerabilities_over_time_panel.vue';
import RiskScorePanel from './risk_score_panel.vue';
import VulnerabilitiesByAgePanel from './vulnerabilities_by_age_panel.vue';
import VulnerabilitiesByIdentifierPanel from './vulnerabilities_by_identifier_panel.vue';
import SecurityDashboardDescription from './security_dashboard_description.vue';

const NAMESPACE = 'organization';

const PROJECT_TOKEN_DEFINITION = {
  type: 'projectId',
  title: ProjectToken.i18n.label,
  multiSelect: true,
  unique: true,
  token: markRaw(ProjectToken),
  operators: OPERATORS_OR,
};

const REPORT_TYPE_TOKEN_DEFINITION = {
  type: 'reportType',
  title: s__('SecurityReports|Report type'),
  multiSelect: true,
  unique: true,
  token: markRaw(ReportTypeToken),
  operators: OPERATORS_OR,
  reportTypes: {
    ...REPORT_TYPES_WITH_MANUALLY_ADDED,
    ...REPORT_TYPES_WITH_CLUSTER_IMAGE,
    ...REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  },
};

export default {
  name: 'OrganizationSecurityDashboardNew',
  components: {
    GlDashboardLayout,
    SecurityDashboardDescription,
    FilteredSearch,
  },
  data() {
    return {
      filters: {},
    };
  },
  computed: {
    dashboard() {
      return {
        panels: [
          ...generateVulnerabilitiesForSeverityPanels({
            namespace: NAMESPACE,
            filters: this.filters,
          }),
          {
            id: 'risk-score',
            component: markRaw(RiskScorePanel),
            componentProps: {
              namespace: NAMESPACE,
              filters: this.filters,
            },
            gridAttributes: {
              width: 5,
              height: 4,
              yPos: 1,
              xPos: 0,
            },
          },
          {
            id: 'vulnerabilities-over-time',
            component: markRaw(VulnerabilitiesOverTimePanel),
            componentProps: {
              namespace: NAMESPACE,
              filters: this.filters,
            },
            gridAttributes: {
              width: 7,
              height: 4,
              yPos: 1,
              xPos: 5,
            },
          },
          {
            id: 'vulnerabilities-by-age',
            component: markRaw(VulnerabilitiesByAgePanel),
            componentProps: {
              namespace: NAMESPACE,
              filters: this.filters,
            },
            gridAttributes: {
              width: 6,
              height: 4,
              yPos: 5,
              xPos: 0,
            },
          },
          {
            id: 'vulnerabilities-by-identifier',
            component: markRaw(VulnerabilitiesByIdentifierPanel),
            componentProps: {
              namespace: NAMESPACE,
              filters: this.filters,
            },
            gridAttributes: {
              width: 6,
              height: 4,
              yPos: 5,
              xPos: 6,
            },
          },
        ],
      };
    },
  },
  methods: {
    updateFilters(newFilters) {
      this.filters = newFilters;
    },
    updateUrlParams(params) {
      const url = setUrlParams(params, { url: window.location.href, decodeParams: true });
      if (url !== window.location.href) {
        updateHistory({ url, replace: true });
      }
    },
  },
  staticTokens: [PROJECT_TOKEN_DEFINITION, REPORT_TYPE_TOKEN_DEFINITION],
};
</script>

<template>
  <gl-dashboard-layout :config="dashboard" data-testid="organization-security-dashboard-new">
    <template #title>
      <h1 class="gl-heading-1 gl-my-0">{{ s__('SecurityReports|Security dashboard') }}</h1>
    </template>
    <template #description>
      <security-dashboard-description />
    </template>
    <template #filters>
      <filtered-search
        :tokens="$options.staticTokens"
        @filters-changed="updateFilters"
        @url-params-changed="updateUrlParams"
      />
    </template>
    <template #panel="{ panel }">
      <component :is="panel.component" v-bind="panel.componentProps" />
    </template>
  </gl-dashboard-layout>
</template>
