<script>
import { markRaw } from 'vue';
import { GlDashboardLayout } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { setUrlParams, updateHistory } from '~/lib/utils/url_utility';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { generateVulnerabilitiesForSeverityPanels } from 'ee/security_dashboard/utils/chart_generators';
import {
  REPORT_TYPES_WITH_MANUALLY_ADDED,
  REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY,
  REPORT_TYPES_WITH_CLUSTER_IMAGE,
} from 'ee/security_dashboard/constants';
import getSecurityCategoriesAndAttributes from 'ee/security_configuration/graphql/group_security_categories_and_attributes.query.graphql';
import { getAttributeCategoryTokens } from 'ee/security_dashboard/utils/attribute_utils';
import FilteredSearch from './filtered_search/filtered_search.vue';
import ProjectToken from './filtered_search/tokens/project_token.vue';
import ReportTypeToken from './filtered_search/tokens/report_type_token.vue';
import VulnerabilitiesOverTimePanel from './vulnerabilities_over_time_panel.vue';
import RiskScorePanel from './risk_score_panel.vue';
import VulnerabilitiesByAgePanel from './vulnerabilities_by_age_panel.vue';
import VulnerabilitiesByIdentifierPanel from './vulnerabilities_by_identifier_panel.vue';
import AgenticAdoptionFunnelPanel from './agentic_adoption_funnel_panel.vue';
import SecurityDashboardDescription from './security_dashboard_description.vue';
import PdfExportButton from './pdf_export_button_new.vue';

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
  name: 'GroupSecurityDashboardNew',
  components: {
    GlDashboardLayout,
    SecurityDashboardDescription,
    FilteredSearch,
    PdfExportButton,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['groupFullPath'],
  data() {
    return {
      filters: {},
      securityCategories: [],
    };
  },
  apollo: {
    securityCategories: {
      query: getSecurityCategoriesAndAttributes,
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
      update: (data) => data?.group?.securityCategories,
      error() {
        createAlert({ message: s__('SecurityReports|Failed to load Security attributes.') });
      },
    },
  },
  computed: {
    showAdoptionFunnel() {
      return Boolean(this.glFeatures?.securityDashboardAgenticAdoption);
    },
    // The adoption funnel (height 2) sits between the severity row and the panels below it. When it
    // is hidden, the panels below shift up to close the gap.
    funnelRowOffset() {
      return this.showAdoptionFunnel ? 2 : 0;
    },
    dashboard() {
      return {
        panels: [
          ...generateVulnerabilitiesForSeverityPanels({
            namespace: 'group',
            filters: this.filters,
          }),
          ...(this.showAdoptionFunnel
            ? [
                {
                  id: 'agentic-adoption-funnel',
                  component: markRaw(AgenticAdoptionFunnelPanel),
                  componentProps: {
                    namespace: 'group',
                    filters: this.filters,
                  },
                  gridAttributes: {
                    width: 12,
                    height: 2,
                    yPos: 1,
                    xPos: 0,
                  },
                },
              ]
            : []),
          {
            id: 'risk-score',
            component: markRaw(RiskScorePanel),
            componentProps: {
              namespace: 'group',
              filters: this.filters,
            },
            gridAttributes: {
              width: 5,
              height: 4,
              yPos: 1 + this.funnelRowOffset,
              xPos: 0,
            },
          },
          {
            id: 'vulnerabilities-over-time',
            component: markRaw(VulnerabilitiesOverTimePanel),
            componentProps: {
              namespace: 'group',
              filters: this.filters,
            },
            gridAttributes: {
              width: 7,
              height: 4,
              yPos: 1 + this.funnelRowOffset,
              xPos: 5,
            },
          },
          {
            id: 'vulnerabilities-by-age',
            component: markRaw(VulnerabilitiesByAgePanel),
            componentProps: {
              namespace: 'group',
              filters: this.filters,
            },
            gridAttributes: {
              width: 6,
              height: 4,
              yPos: 5 + this.funnelRowOffset,
              xPos: 0,
            },
          },
          {
            id: 'vulnerabilities-by-identifier',
            component: markRaw(VulnerabilitiesByIdentifierPanel),
            componentProps: {
              namespace: 'group',
              filters: this.filters,
            },
            gridAttributes: {
              width: 6,
              height: 4,
              yPos: 5 + this.funnelRowOffset,
              xPos: 6,
            },
          },
        ],
      };
    },
    tokens() {
      return [
        ...this.$options.staticTokens,
        ...getAttributeCategoryTokens(this.securityCategories),
      ];
    },
    isLoading() {
      return this.$apollo.queries.securityCategories?.loading;
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
  <gl-dashboard-layout :config="dashboard" data-testid="group-security-dashboard-new">
    <template #title>
      <div class="gl-flex gl-w-full gl-items-center gl-justify-between">
        <h1 class="gl-heading-1 gl-my-0">{{ s__('SecurityReports|Security dashboard') }}</h1>
        <pdf-export-button />
      </div>
    </template>
    <template #description>
      <security-dashboard-description />
    </template>
    <template #filters>
      <filtered-search
        v-if="!isLoading"
        :tokens="tokens"
        @filters-changed="updateFilters"
        @url-params-changed="updateUrlParams"
      />
    </template>
    <template #panel="{ panel }">
      <component :is="panel.component" v-if="!isLoading" v-bind="panel.componentProps" />
    </template>
  </gl-dashboard-layout>
</template>
