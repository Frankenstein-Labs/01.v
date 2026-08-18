import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import ComplianceDashboardBreadcrumbs from './components/compliance_dashboard_breadcrumbs.vue';
import { createRouter } from './router';
import {
  ROUTE_DASHBOARD,
  ROUTE_FRAMEWORKS,
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_PROJECTS,
} from './constants';

export default () => {
  const el = document.getElementById('js-compliance-report');

  const {
    basePath,
    canAdminComplianceFrameworks,
    frameworkImportUrl,
    mergeCommitsCsvExportPath,
    violationsCsvExportPath,
    complianceViolationsCsvExportPath,
    projectFrameworksCsvExportPath,
    complianceStatusReportExportPath,
    adherencesCsvExportPath,
    frameworksCsvExportPath,
    groupPath,
    groupComplianceCenterPath,
    groupName,
    namespaceId,
    projectPath,
    projectName,
    projectId,
    rootAncestorPath,
    rootAncestorName,
    canAccessRootAncestorComplianceCenter,
    rootAncestorComplianceCenterPath,
    pipelineConfigurationFullPathEnabled,
    pipelineConfigurationEnabled,
    pipelineExecutionPolicyPath,
    migratePipelineToPolicyPath,
    groupSecurityPoliciesPath,
    disableScanPolicyUpdate,
    featureAdherenceReportEnabled,
    adherenceReportUpgradePath,
    featureViolationsReportEnabled,
    featureProjectsReportEnabled,
    featureSecurityPoliciesEnabled,
    violationsV2Enabled,
    policyDisplayLimit,
    activeComplianceFrameworks,
    designatedAsCsp,
  } = el.dataset;

  Vue.use(VueApollo);
  Vue.use(VueRouter);

  const routes = Object.entries({
    [ROUTE_DASHBOARD]: !projectId,
    [ROUTE_STANDARDS_ADHERENCE]: !projectId || parseBoolean(featureAdherenceReportEnabled),
    [ROUTE_VIOLATIONS]: parseBoolean(featureViolationsReportEnabled),
    [ROUTE_FRAMEWORKS]: true,
    [ROUTE_PROJECTS]: parseBoolean(featureProjectsReportEnabled),
  })
    .filter(([, status]) => status)
    .map(([route]) => route);

  const router = createRouter(basePath, {
    projectPath,
    projectId,
    groupPath,
    groupName,
    groupComplianceCenterPath,
    projectName,
    rootAncestorPath,
    rootAncestorName,
    rootAncestorComplianceCenterPath,
    routes,
    adherenceReportEnabled: parseBoolean(featureAdherenceReportEnabled),
    adherenceReportUpgradePath,
  });

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  injectVueAppBreadcrumbs(router, ComplianceDashboardBreadcrumbs);

  return new Vue({
    el,
    apolloProvider,
    name: 'ComplianceReportsApp',
    router,
    provide: {
      namespaceType: projectPath ? 'project' : 'group',
      canAdminComplianceFrameworks: parseBoolean(canAdminComplianceFrameworks),
      canAccessRootAncestorComplianceCenter: parseBoolean(canAccessRootAncestorComplianceCenter),
      namespaceId,
      groupPath,
      rootAncestorPath,
      pipelineConfigurationFullPathEnabled: parseBoolean(pipelineConfigurationFullPathEnabled),
      pipelineConfigurationEnabled: parseBoolean(pipelineConfigurationEnabled),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      mergeCommitsCsvExportPath,
      violationsCsvExportPath,
      complianceViolationsCsvExportPath,
      projectFrameworksCsvExportPath,
      complianceStatusReportExportPath,
      adherencesCsvExportPath,
      frameworksCsvExportPath,
      pipelineExecutionPolicyPath,
      migratePipelineToPolicyPath,
      groupSecurityPoliciesPath,
      frameworkImportUrl,
      featureSecurityPoliciesEnabled: parseBoolean(featureSecurityPoliciesEnabled),
      violationsV2Enabled: parseBoolean(violationsV2Enabled),
      policyDisplayLimit: Number(policyDisplayLimit),
      activeComplianceFrameworks: parseBoolean(activeComplianceFrameworks),
      designatedAsCsp: parseBoolean(designatedAsCsp),
    },

    render: (createElement) => createElement('router-view'),
  });
};
